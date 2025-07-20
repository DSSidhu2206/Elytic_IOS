// lib/backend/services/auth_service.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  static final _auth = FirebaseAuth.instance;
  static final _firestore = FirebaseFirestore.instance;
  static const _usersCol = 'users';

  /// Returns true if [email] is already registered.
  static Future<bool> checkEmailInUse(String email) async {
    try {
      final methods = await _auth.fetchSignInMethodsForEmail(email);
      return methods.isNotEmpty;
    } catch (e) {
      // On error, assume email might be in use
      return true;
    }
  }

  /// Creates a new FirebaseAuth user and corresponding Firestore document.
  /// On success returns true; on failure, returns false.
  static Future<bool> signUp({
    required String username,
    required String email,
    required String password,
    required DateTime birthday,
    String? gender,
    required String avatarAsset,
  }) async {
    try {
      // 1. Create in Firebase Auth
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = cred.user!.uid;

      // 2. Write user profile to Firestore
      await _firestore.collection(_usersCol).doc(uid).set({
        'username': username,
        'email': email,
        'birthday': Timestamp.fromDate(birthday),
        'gender': gender,
        'avatarPath': avatarAsset,
        'tier': 1,
        'createdAt': Timestamp.now(),
      });

      return true;
    } on FirebaseAuthException catch (e) {
      // You could inspect e.code for more granular errors.
      return false;
    } on FirebaseException catch (e) {
      // Roll back Auth user if Firestore write fails
      try {
        await _auth.currentUser?.delete();
      } catch (_) {}
      return false;
    } catch (_) {
      return false;
    }
  }
}
