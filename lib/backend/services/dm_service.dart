// lib/backend/services/dm_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../frontend/models/dm_message.dart';

class DMService {
  final _db = FirebaseFirestore.instance;

  // --- PATCH: Add privacy and friendship caches ---
  static final Map<String, String> _privacyCache = {};
  static final Map<String, bool> _friendshipCache = {};

  /// Invalidate caches if user logs out/settings change, etc
  static void invalidatePrivacyCache([String? userId]) {
    if (userId != null) {
      _privacyCache.remove(userId);
    } else {
      _privacyCache.clear();
    }
  }

  static void invalidateFriendshipCache([String? key]) {
    if (key != null) {
      _friendshipCache.remove(key);
    } else {
      _friendshipCache.clear();
    }
  }

  String getRoomId(String userA, String userB) {
    final sorted = [userA, userB]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  /// Fetch the DM privacy setting for the receiver from their settings/preferences doc.
  /// Returns: "everyone", "friends", or "closed"
  Future<String> getUserDmPrivacy(String userId, {bool forceRefresh = false}) async {
    if (!forceRefresh && _privacyCache.containsKey(userId)) {
      return _privacyCache[userId]!;
    }
    final prefDoc = await _db
        .collection('users')
        .doc(userId)
        .collection('settings')
        .doc('preferences')
        .get();
    final data = prefDoc.data() ?? {};
    final pref = (data['dmPreference'] ?? "everyone").toString();
    _privacyCache[userId] = pref;
    return pref;
  }

  /// Returns true if [receiverId] is present in [senderId]'s friends subcollection
  Future<bool> isFriend(String senderId, String receiverId, {bool forceRefresh = false}) async {
    final key = '$senderId::$receiverId';
    if (!forceRefresh && _friendshipCache.containsKey(key)) {
      return _friendshipCache[key]!;
    }
    final doc = await _db
        .collection('users')
        .doc(senderId)
        .collection('friends')
        .doc(receiverId)
        .get();
    final result = doc.exists;
    _friendshipCache[key] = result;
    return result;
  }

  /// Try to send a DM after checking recipient privacy and friendship.
  /// Throws an exception string if blocked (UI should catch and show the error).
  Future<void> trySendMessage({
    required String senderId,
    required String receiverId,
    required String text,
    bool shouldNotify = true,
  }) async {
    final privacy = await getUserDmPrivacy(receiverId);

    if (privacy == "closed") {
      throw Exception("This user has closed their DMs.");
    }

    if (privacy == "friends") {
      final friend = await isFriend(senderId, receiverId);
      if (!friend) {
        throw Exception("This user only allows DMs from their friends.");
      }
    }

    // Allowed, send the message
    await _sendMessage(
      senderId: senderId,
      receiverId: receiverId,
      text: text,
      shouldNotify: shouldNotify,
    );
  }

  /// Internal method to actually write the message.
  Future<void> _sendMessage({
    required String senderId,
    required String receiverId,
    required String text,
    bool shouldNotify = true,
  }) async {
    final roomId = getRoomId(senderId, receiverId);
    final roomRef = _db.collection('dm_rooms').doc(roomId);
    final messageRef = roomRef.collection('messages').doc();

    // 1. Write the message (let Firestore assign sentAt)
    await messageRef.set({
      'text': text,
      'senderId': senderId,
      'receiverId': receiverId,
      'sentAt': FieldValue.serverTimestamp(),
      'status': 'sent',
    });

    // 2. Wait for Firestore to write sentAt (max 2 tries for optimization)
    Timestamp? sentAt;
    int tries = 0;
    while (sentAt == null && tries < 2) {
      final writtenMsg = await messageRef.get();
      sentAt = writtenMsg['sentAt'];
      if (sentAt == null) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      tries++;
    }

    // 3. Update lastMessage on the dm_room doc with the actual sentAt timestamp
    await roomRef.set({
      'participants': [senderId, receiverId],
      'createdAt': FieldValue.serverTimestamp(), // won't overwrite if already present
      'lastMessage': {
        'text': text,
        'senderId': senderId,
        'receiverId': receiverId,
        'sentAt': sentAt ?? FieldValue.serverTimestamp(),
        'status': 'sent',
      },
    }, SetOptions(merge: true));
  }

  Future<void> markMessagesAsRead({
    required String roomId,
    required String userId,
    required bool readReceiptsEnabled,
  }) async {
    if (!readReceiptsEnabled) return;
    final messagesQuery = _db
        .collection('dm_rooms')
        .doc(roomId)
        .collection('messages')
        .where('receiverId', isEqualTo: userId)
        .where('status', isEqualTo: 'sent');
    final batch = _db.batch();
    final snap = await messagesQuery.get();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'status': 'read'});
    }
    await batch.commit();
  }

  /// CACHED STREAM: No caching here—Firestore snapshots auto-handle this!
  Stream<List<DMMessage>> messageStream(String roomId) {
    return _db
        .collection('dm_rooms')
        .doc(roomId)
        .collection('messages')
        .orderBy('sentAt')
        .snapshots()
        .map((snap) => snap.docs.map((doc) => DMMessage.fromDoc(doc)).toList());
  }
}
