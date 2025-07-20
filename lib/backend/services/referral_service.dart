import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class ReferralService {
  static final ReferralService _instance = ReferralService._internal();
  factory ReferralService() => _instance;
  ReferralService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseDatabase _rtdb = FirebaseDatabase.instance;

  // In-memory cache for current session
  String? _cachedReferralCode;
  String? _cachedReferredBy;
  int? _cachedSuccessCount;
  final bool _isLoading = false;

  // Public read-only accessors (getters)
  String? get cachedReferralCode => _cachedReferralCode;
  String? get cachedReferredBy => _cachedReferredBy;
  int? get cachedSuccessCount => _cachedSuccessCount;
  bool get isLoading => _isLoading;

  /// Helper to get or create device ID
  Future<String> getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var deviceId = prefs.getString('device_id');
    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await prefs.setString('device_id', deviceId);
    }
    return deviceId;
  }

  /// Generates a new unique 8-char referral code and stores in both Firestore and RTDB.
  /// Fails if the user already has a code.
  Future<String> generateReferralCode() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception("Not authenticated");

    // Check if already exists (cached or fetch)
    if (_cachedReferralCode != null) return _cachedReferralCode!;

    // 1. Generate unique code using RTDB as source of truth
    String code = '';
    int attempts = 0;
    bool unique = false;
    final codeRef = _rtdb.ref("referral_code_check");
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';

    while (!unique && attempts < 20) {
      code = List.generate(8, (i) => chars[Random.secure().nextInt(chars.length)]).join();
      final DataSnapshot snap = await codeRef.child(code).get();
      if (!snap.exists) unique = true;
      attempts++;
    }
    if (!unique) throw Exception("Could not generate a unique code. Try again.");

    // 2. Batch write: Firestore and RTDB (fail both if either fails)
    final userDoc = _firestore.collection("users").doc(uid);

    try {
      // Firestore write
      await userDoc.set({'referral_code': code}, SetOptions(merge: true));
      // RTDB write
      await codeRef.child(code).set(uid);

      // Update cache
      _cachedReferralCode = code;
      return code;
    } catch (e) {
      // Rollback (attempt)
      await userDoc.set({'referral_code': FieldValue.delete()}, SetOptions(merge: true));
      await codeRef.child(code).remove();
      throw Exception("Failed to save referral code. Please try again.");
    }
  }

  /// Fetches the referral code for the current user (cached for session)
  Future<String?> getReferralCode() async {
    if (_cachedReferralCode != null) return _cachedReferralCode;
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    final doc = await _firestore.collection("users").doc(uid).get();
    final code = doc.data()?['referral_code'] as String?;
    _cachedReferralCode = code;
    return code;
  }

  /// Fetches the referredBy code for the current user (cached for session)
  Future<String?> getReferredBy() async {
    if (_cachedReferredBy != null) return _cachedReferredBy;
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    final doc = await _firestore.collection("users").doc(uid).get();
    final referredBy = doc.data()?['referred_by'] as String?;
    _cachedReferredBy = referredBy;
    return referredBy;
  }

  /// Allows the current user to enter a referral code.
  /// Checks all edge cases, then writes in batch (Firestore, and also adds to successful_referrals of inviter for future use).
  Future<void> enterReferralCode(String inputCode) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception("Not authenticated");

    // --- ABUSE PREVENTION: Check device ID ---
    final deviceId = await getOrCreateDeviceId();
    final deviceDoc = await _firestore.collection('referral_device_ids').doc(deviceId).get();
    if (deviceDoc.exists) {
      throw Exception("A referral code has already been used on this device.");
    }

    // Standardize code
    final code = inputCode.trim().toUpperCase();

    // Check: already entered?
    await getReferredBy();
    if (_cachedReferredBy != null) throw Exception("Referral code already entered.");

    // Check: is it user's own code?
    final myCode = await getReferralCode();
    if (myCode != null && myCode == code) throw Exception("You cannot enter your own referral code.");

    // Check: is code valid (RTDB)?
    final codeSnap = await _rtdb.ref("referral_code_check/$code").get();
    if (!codeSnap.exists) throw Exception("Invalid referral code.");
    final inviterUid = codeSnap.value as String?;

    if (inviterUid == null || inviterUid == uid) throw Exception("Invalid referral code.");

    // Check: has this inviter already referred this user?
    final inviterRef = _firestore
        .collection("users")
        .doc(inviterUid)
        .collection("successful_referrals")
        .doc(uid);

    final alreadyReferredSnap = await inviterRef.get();
    if (alreadyReferredSnap.exists) throw Exception("This user has already been referred by this code.");

    // Batch writes
    final userDoc = _firestore.collection("users").doc(uid);
    final batch = _firestore.batch();
    batch.set(userDoc, {'referred_by': code, 'referral_status': 'pending'}, SetOptions(merge: true));
    batch.set(inviterRef, {'status': 'pending', 'joinedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    await batch.commit();

    // --- Record this device as used for referral entry ---
    await _firestore.collection('referral_device_ids').doc(deviceId).set({
      'userId': uid,
      'enteredAt': FieldValue.serverTimestamp(),
      'referredBy': code,
    });

    // Update cache
    _cachedReferredBy = code;
  }

  /// Returns the count of successful referrals for this user (where invitee's status is 'completed')
  Future<int> getSuccessfulReferralCount() async {
    if (_cachedSuccessCount != null) return _cachedSuccessCount!;
    final uid = _auth.currentUser?.uid;
    if (uid == null) return 0;
    final snap = await _firestore
        .collection("users")
        .doc(uid)
        .collection("successful_referrals")
        .where('status', isEqualTo: 'completed')
        .get();
    _cachedSuccessCount = snap.size;
    return snap.size;
  }

  /// To be called from your message send logic: Marks referral as completed when the user sends a first message
  Future<void> markReferralCompletedIfNeeded() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    // Fetch user doc
    final doc = await _firestore.collection("users").doc(uid).get();
    final referredBy = doc.data()?['referred_by'] as String?;
    final status = doc.data()?['referral_status'] as String?;
    if (referredBy == null || status != "pending") return;

    // Find inviter's UID via RTDB
    final codeSnap = await _rtdb.ref("referral_code_check/$referredBy").get();
    if (!codeSnap.exists) return;
    final inviterUid = codeSnap.value as String?;
    if (inviterUid == null) return;

    // Batch update: user + inviter's successful_referrals/{inviteeUid}
    final batch = _firestore.batch();
    batch.set(_firestore.collection("users").doc(uid), {'referral_status': 'completed'}, SetOptions(merge: true));
    batch.set(
      _firestore
          .collection("users")
          .doc(inviterUid)
          .collection("successful_referrals")
          .doc(uid),
      {'status': 'completed', 'completedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
    await batch.commit();
    _cachedSuccessCount = null; // Invalidate cache
  }

  /// Shares the invite message with both links and user's code
  Future<void> shareInviteMessage(String username, String code) async {
    const playStoreLink = 'https://play.google.com/store/apps/details?id=com.gummi.elytic';
    const appStoreLink = 'https://apps.apple.com/app/idYOUR_APP_ID';
    final msg = '''
Hey! I am inviting you to join Elytic.

Download the app:
Play Store: $playStoreLink
App Store: $appStoreLink

Enter their referral code $code after signing up to receive rewards!
''';
    await Share.share(msg);
  }

  /// Copies referral code to clipboard
  Future<void> copyToClipboard(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
  }

  /// Clear all caches (for logout etc)
  void clearCache() {
    _cachedReferralCode = null;
    _cachedReferredBy = null;
    _cachedSuccessCount = null;
  }
}
