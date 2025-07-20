// lib/frontend/widgets/common/notification_listener.dart

import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:elytic/frontend/widgets/common/custom_notification_banner.dart'; // Import ElyticNotificationType from here
// Import your profile and DM screens:
import 'package:elytic/frontend/screens/profile/user_profile_screen.dart';
import 'package:elytic/frontend/screens/social/dm_room_page.dart';
// PATCH: Import avatar helper
import 'package:elytic/frontend/helpers/avatar_helper.dart';

class NotificationListenerWidget extends StatefulWidget {
  final Widget child;
  final String userId;

  const NotificationListenerWidget({
    super.key,
    required this.child,
    required this.userId,
  });

  @override
  State<NotificationListenerWidget> createState() => _NotificationListenerWidgetState();
}

class _NotificationListenerWidgetState extends State<NotificationListenerWidget> {
  StreamSubscription? _notifSub;
  // Removed _tierSub and _cachedTier

  final Set<String> _shownNotifIds = {};

  @override
  void initState() {
    super.initState();
    _notifSub = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      _handleNotifications(snapshot.docs);
    });

    // Removed call to _initTierListener()
  }

  // Removed _initTierListener() method

  void _showSimpleNotificationBanner({
    required ElyticNotificationType type,
    required String title,
    required String message,
    String? avatarUrl,
    String? username,
    int? tier,
    VoidCallback? onTap,
    Duration duration = const Duration(seconds: 4),
  }) {
    final overlayKey = UniqueKey();
    showSimpleNotification(
      Dismissible(
        key: overlayKey,
        direction: DismissDirection.horizontal, // Enables left/right swipe to dismiss
        onDismissed: (_) {},
        child: GestureDetector(
          onTap: onTap,
          child: CustomNotificationBanner(
            type: type,
            title: title,
            message: message,
            avatarUrl: avatarUrl,
            username: username,
            tier: tier,
            onTap: onTap,
          ),
        ),
      ),
      autoDismiss: true,
      duration: duration,
      slideDismissDirection: DismissDirection.up, // Still allows swipe up
      elevation: 6,
      background: Colors.transparent,
    );
  }

  // Removed _showTierUpNotification()

  String _tierTitle(int tier) {
    switch (tier) {
      case 1:
        return "Elytic Basic (Bronze)";
      case 2:
        return "Elytic Plus (Silver)";
      case 3:
        return "Royalty (Gold)";
      case 4:
        return "Junior Moderator";
      case 5:
        return "Senior Moderator";
      default:
        return "Tier $tier";
    }
  }

  void _handleNotifications(List<QueryDocumentSnapshot> docs) {
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null || data.isEmpty) continue;

      final docId = doc.id;
      final String notifType = (data['type'] ?? '').toString().toLowerCase();
      final String msg = (data['message'] ?? data['body'] ?? '').toString().trim();
      final String title = (data['title'] ?? data['username'] ?? '').toString().trim();
      final String username = (data['username'] ?? '').toString().trim();
      final String avatarUrl = (data['fromAvatarUrl'] ?? data['avatarUrl'] ?? '').toString().trim();
      final String? targetUserId = data['from'] ?? data['userId']; // Assumes 'from' is sender uid

      if (msg.isEmpty && title.isEmpty) continue;

      if (!_shownNotifIds.contains(docId)) {
        _shownNotifIds.add(docId);

        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;

          // PATCH: Always resolve avatar image using helper
          final avatarImageProvider = getAvatarImageProvider(avatarUrl);

          // PATCH: Gift Coins Notification
          if (notifType == 'gift_coins') {
            final senderName = data['username'] ?? 'Someone';
            final coins = data['data']?['coins'] ?? data['coins'] ?? '?';
            final fromAvatarUrl = data['avatarUrl'] ?? data['fromAvatarUrl'] ?? '';
            _showSimpleNotificationBanner(
              type: ElyticNotificationType.giftCoins, // PATCH: Add to your enum/class
              title: "You received $coins coins!",
              message: "From: $senderName",
              avatarUrl: fromAvatarUrl,
              username: senderName,
              duration: const Duration(seconds: 7),
            );
          }
          // --- DM / Message notification ---
          else if (notifType == 'dm' || notifType == 'message') {
            _showSimpleNotificationBanner(
              type: ElyticNotificationType.message,
              title: username.isNotEmpty ? username : "Message",
              message: msg.isNotEmpty ? msg : "New message received!",
              avatarUrl: avatarUrl,
              username: username,
              duration: const Duration(seconds: 4),
              onTap: (targetUserId != null)
                  ? () {
                Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
                  builder: (_) => DMRoomPage(
                    otherUserId: targetUserId,
                    otherUserName: username,
                    otherUserAvatar: avatarUrl,
                    readReceiptsEnabled: true,
                  ),
                ));
              }
                  : null,
            );
          }
          // --- Friend Request ---
          else if (notifType == 'friend_request') {
            _showSimpleNotificationBanner(
              type: ElyticNotificationType.friendRequest,
              title: 'Friend Request',
              message: '${username.isNotEmpty ? username : "Someone"} sent you a friend request!',
              avatarUrl: avatarUrl,
              username: username,
              duration: const Duration(seconds: 5),
            );
          }
          // --- Friend Accepted ---
          else if (notifType == 'friend_accepted') {
            _showSimpleNotificationBanner(
              type: ElyticNotificationType.friendAccepted,
              title: username.isNotEmpty ? username : "Friend Accepted",
              message: "$username accepted your friend request!",
              avatarUrl: avatarUrl,
              username: username,
              duration: const Duration(seconds: 4),
              onTap: (targetUserId != null)
                  ? () {
                Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
                  builder: (_) => UserProfileScreen(
                    userId: targetUserId,
                    currentUserId: widget.userId,
                    currentUserTier: 0,
                  ),
                ));
              }
                  : null,
            );
          }
          // --- Tier Up from notification docs only ---
          else if (notifType == 'tier_upgrade' || notifType == 'tier_up' || notifType == 'tierup') {
            final String? gifterUserId = data['from'];
            // Robustly extract tier: prefer top-level, else nested, else fallback 0
            int tier = 0;
            if (data['tier'] != null) {
              tier = (data['tier'] is int)
                  ? data['tier']
                  : int.tryParse(data['tier'].toString()) ?? 0;
            } else if (data['newTier'] != null) {
              tier = (data['newTier'] is int)
                  ? data['newTier']
                  : int.tryParse(data['newTier'].toString()) ?? 0;
            } else if (data['data'] != null && data['data'] is Map<String, dynamic>) {
              final dynamic newTier = (data['data'] as Map<String, dynamic>)['newTier'];
              if (newTier != null) {
                tier = (newTier is int) ? newTier : int.tryParse(newTier.toString()) ?? 0;
              }
            }

            _showSimpleNotificationBanner(
              type: ElyticNotificationType.tierUp,
              title: 'Tier Up!',
              message: 'Congratulations! You are now ${_tierTitle(tier)}.',
              tier: tier, // <-- now always correct!
              avatarUrl: avatarUrl, // PATCH: pass avatarUrl
              username: username,   // PATCH: pass username
              duration: const Duration(seconds: 5),
              onTap: (gifterUserId != null)
                  ? () {
                Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
                  builder: (_) => UserProfileScreen(
                    userId: gifterUserId,
                    currentUserId: widget.userId,
                    currentUserTier: 0,
                  ),
                ));
              }
                  : null,
            );
        }
          // --- Pet Petted ---
          else if (notifType == 'pet_petted') {
            final fromUsername = data['fromUsername'] ?? 'Someone';
            final petName = data['petName'] ?? 'your pet';
            final fromAvatarUrl = data['fromAvatarUrl'] ?? '';
            _showSimpleNotificationBanner(
              type: ElyticNotificationType.petPetted,
              title: '$fromUsername said hello to $petName',
              message: '',
              avatarUrl: fromAvatarUrl,
              username: fromUsername,
              duration: const Duration(seconds: 4),
            );
          }
          // --- Pet Item Gift ---
          else if (notifType == 'pet_item_gift') {
            final fromUsername = data['fromUsername'] ?? 'Someone';
            final fromAvatarUrl = data['fromAvatarUrl'] ?? '';
            final petName = data['petName'] ?? 'your pet';
            final itemName = data['itemName'] ?? 'an item';
            _showSimpleNotificationBanner(
              type: ElyticNotificationType.petItemGift,
              title: '$fromUsername gave $itemName to $petName',
              message: data['message'] ?? '',
              avatarUrl: fromAvatarUrl,
              username: fromUsername,
              duration: const Duration(days: 3650), // Very long duration (effectively no auto-dismiss)
            );
          }
          // --- Profile Like ---
          else if (notifType == 'profile_like') {
            final String fromAvatar = (data['fromAvatarUrl'] as String?) ?? avatarUrl;
            _showSimpleNotificationBanner(
              type: ElyticNotificationType.friendAccepted, // or define a new type ElyticNotificationType.profileLike
              title: username.isNotEmpty ? username : "Someone",
              message: "liked your profile!",
              avatarUrl: fromAvatar,
              username: username,
              duration: const Duration(seconds: 4),
            );
          }
          // --- Default ---
          else {
            _showSimpleNotificationBanner(
              type: ElyticNotificationType.message,
              title: title.isNotEmpty ? title : 'Notification',
              message: msg.isNotEmpty ? msg : (data['body'] ?? '').toString(),
              avatarUrl: avatarUrl,
              username: username,
              duration: const Duration(seconds: 4),
            );
          }

          try {
            await doc.reference.update({'read': true});
          } catch (e) {}
        });

        break;
      }
    }
  }

  @override
  void dispose() {
    _notifSub?.cancel();
    // Removed _tierSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
