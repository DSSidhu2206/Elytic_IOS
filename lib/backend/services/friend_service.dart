// lib/backend/services/friend_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:elytic/backend/services/user_service.dart'; // PATCH: Import UserService

class UserFriend {
  final String userId;
  final String username;
  final String? avatarUrl;
  UserFriend({required this.userId, required this.username, this.avatarUrl});
}

class FriendService {
  static final _functions = FirebaseFunctions.instance;

  // PATCH: Use UserService (with cache) for sender info in friend request
  static Future<void> sendFriendRequest(String fromUserId, String toUserId) async {
    // Fetch sender info using UserService (now cached)
    final fromUserInfo = await UserService.fetchDisplayInfo(fromUserId);

    final fromUsername = fromUserInfo.username;
    final fromAvatarPath = fromUserInfo.avatarUrl;

    final firestore = FirebaseFirestore.instance;

    // Create friend request doc under receiver's friendRequests subcollection
    final friendRequestRefReceived = firestore
        .collection('users')
        .doc(toUserId)
        .collection('friendRequests')
        .doc(fromUserId);

    // Create friend request doc under sender's friendRequests subcollection
    final friendRequestRefSent = firestore
        .collection('users')
        .doc(fromUserId)
        .collection('friendRequests')
        .doc(toUserId);

    // Write both docs atomically in a batch
    final batch = firestore.batch();

    batch.set(friendRequestRefReceived, {
      'senderId': fromUserId,
      'receiverId': toUserId,
      'status': 'pending',
      'displayStatus': 'pending',
      'sentAt': FieldValue.serverTimestamp(),
      'username': fromUsername,
      'avatarPath': fromAvatarPath,
      'requestType': 'received',
    });

    batch.set(friendRequestRefSent, {
      'senderId': fromUserId,
      'receiverId': toUserId,
      'status': 'pending',
      'displayStatus': 'sent',
      'sentAt': FieldValue.serverTimestamp(),
      'username': fromUsername,
      'avatarPath': fromAvatarPath,
      'requestType': 'sent',
    });

    await batch.commit();
  }

  static Future<void> acceptFriendRequest(String senderId) async {
    final callable = _functions.httpsCallable('acceptFriendRequest');
    await callable.call({'senderId': senderId});
  }

  static Future<void> rejectFriendRequest(String senderId) async {
    final callable = _functions.httpsCallable('rejectFriendRequest');
    await callable.call({'senderId': senderId});
  }

  /// Block user using Cloud Function (removes friendship/requests and adds to blocked)
  static Future<void> blockUser(String currentUserId, String blockedUserId) async {
    final callable = _functions.httpsCallable('blockUser');
    await callable.call({'targetId': blockedUserId});
  }

  /// Unblock user using Cloud Function
  static Future<void> unblockUser(String currentUserId, String blockedUserId) async {
    final callable = _functions.httpsCallable('unblockUser');
    await callable.call({'targetId': blockedUserId});
  }

  /// Fetches all blocked users (returns list of UserDisplayInfo)
  static Future<List<UserDisplayInfo>> fetchBlockedUsers(String userId) async {
    final blockedRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('blocked');
    final blockedSnaps = await blockedRef.get();
    final blockedIds = blockedSnaps.docs.map((d) => d.id).toList();
    if (blockedIds.isEmpty) return [];
    final infos = await UserService.fetchMultipleProfileInfos(blockedIds);
    return blockedIds.map((id) => infos[id]!).toList();
  }

  // PATCHED: Enhanced method to check full friend status including pending requests
  static Future<String?> getFriendStatus(String currentUserId, String otherUserId) async {
    final firestore = FirebaseFirestore.instance;

    // Check if already friends
    final friendsDoc = await firestore
        .collection('users')
        .doc(currentUserId)
        .collection('friends')
        .doc(otherUserId)
        .get();
    if (friendsDoc.exists) {
      return 'accepted';
    }

    // Check if current user has sent a friend request to other user (pending)
    final sentRequestDoc = await firestore
        .collection('users')
        .doc(currentUserId)   // FIXED: currentUserId here (sender)
        .collection('friendRequests')
        .doc(otherUserId)
        .get();
    if (sentRequestDoc.exists) {
      final data = sentRequestDoc.data();
      if (data != null && data['requestType'] == 'sent' && data['status'] == 'pending') {
        return 'pending';
      }
    }

    // Check if current user has received a friend request from other user (incoming)
    final receivedRequestDoc = await firestore
        .collection('users')
        .doc(currentUserId)
        .collection('friendRequests')
        .doc(otherUserId)
        .get();
    if (receivedRequestDoc.exists) {
      final data = receivedRequestDoc.data();
      if (data != null && data['requestType'] == 'received' && data['status'] == 'pending') {
        return 'incoming';
      }
    }

    // No relationship found
    return null;
  }

  // Patch unfriend to call removeFriend cloud function
  static Future<void> unfriend(String otherUserId) async {
    final callable = _functions.httpsCallable('removeFriend');
    await callable.call({'friendId': otherUserId});
  }

  // --- PATCH: Extracted method to fetch friend user IDs list for a given user
  static Future<List<String>> fetchFriendUserIds(String userId) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('friends')
          .get();
      final friendIds = snap.docs.map((doc) => doc.id).toList();
      return friendIds;
    } catch (e) {
      return [];
    }
  }

  // --- PATCH: Extracted method to fetch user IDs of sent friend requests for a given user
  static Future<List<String>> fetchSentFriendRequestUserIds(String userId) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('friendRequests')
          .where('displayStatus', isEqualTo: 'sent')
          .get();

      final sentIds = snap.docs.map((doc) => doc.id).toList();
      return sentIds;
    } catch (e) {
      return [];
    }
  }

  // --- PATCH: Efficient batch fetching of UserFriend for the current user (with avatars, cached) ---
  static Future<List<UserFriend>> getFriendsList(String userId) async {
    // 1. Get all friend userIds (single read)
    final friendIds = await fetchFriendUserIds(userId);
    if (friendIds.isEmpty) return [];

    // 2. Fetch profile infos in batch (cached inside UserService)
    final Map<String, UserDisplayInfo> infoMap =
    await UserService.fetchMultipleProfileInfos(friendIds);

    // 3. Compose UserFriend list
    return friendIds
        .where((id) => infoMap[id] != null)
        .map((id) => UserFriend(
      userId: id,
      username: infoMap[id]!.username,
      avatarUrl: infoMap[id]!.avatarUrl,
    ))
        .toList();
  }
}
