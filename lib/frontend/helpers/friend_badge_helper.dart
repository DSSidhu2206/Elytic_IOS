// lib/frontend/helpers/friend_badge_helper.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class FriendBadgeHelper {
  /// Returns a stream of pending friend requests count in real-time.
  static Stream<int> pendingFriendRequestsCountStream(String userId) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('friends')
        .where('status', isEqualTo: 'pending')
        .where('requestType', isEqualTo: 'received')
        .snapshots()
        .map((snapshot) {
      final count = snapshot.docs.length;
      return count;
    });
  }
}
