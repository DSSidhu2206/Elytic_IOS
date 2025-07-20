// lib/frontend/widgets/common/custom_app_bar.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elytic/frontend/widgets/common/notification_badge.dart';
import 'package:rxdart/rxdart.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String roomName;
  final VoidCallback onShopTap;
  final VoidCallback onRoomNameTap;
  final VoidCallback onSettingsTap;
  final VoidCallback onMessagesTap;
  final VoidCallback onFriendsTap;
  final String currentUserId;

  const CustomAppBar({
    Key? key,
    required this.roomName,
    required this.onShopTap,
    required this.onRoomNameTap,
    required this.onSettingsTap,
    required this.onMessagesTap,
    required this.onFriendsTap,
    required this.currentUserId,
  }) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Colors.white : Colors.black;
    final textColor = isDark ? Colors.white : Colors.black;

    return SafeArea(
      child: Material(
        color: Colors.transparent, // Use transparent so container shows
        elevation: 1,
        child: Container(
          height: 56,
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark ? Colors.black : null,
            image: !isDark
                ? DecorationImage(
              image:
              const AssetImage('assets/icons/custom_appbar_background.png'),
              fit: BoxFit.cover,
              colorFilter: ColorFilter.mode(
                Colors.black.withOpacity(0.15), // Dim the image by 15%
                BlendMode.darken,
              ),
            )
                : null,
          ),
          child: Row(
            children: [
              IconButton(
                icon: Image.asset(
                  'assets/icons/shop_icon.png',
                  width: 48,
                  height: 48,
                ),
                onPressed: onShopTap,
                tooltip: "Shop",
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Center(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      // PATCH: Only navigate, do NOT handle presence leave/join here
                      onRoomNameTap();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Text(
                        roomName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          letterSpacing: 0.2,
                          color: textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ),
              // --- Messages badge using CentralizedBadgeStream (DMs only)
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: SizedBox(
                      width: 40,
                      height: 40,
                      child: Image.asset(
                        'assets/icons/messages_icon.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                    onPressed: onMessagesTap,
                    tooltip: "Messages",
                  ),
                  Positioned(
                    right: 4,
                    top: 7,
                    child: CentralizedBadgeStream(
                      userId: currentUserId,
                      size: 15,
                      showPlus: false,
                      showDMs: true,
                      showFriendRequests: false,
                    ),
                  ),
                ],
              ),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: SizedBox(
                      width: 30,
                      height: 30,
                      child: Image.asset(
                        'assets/icons/friends_icon.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                    onPressed: onFriendsTap,
                    tooltip: "Friends",
                  ),
                  Positioned(
                    right: 4,
                    top: 7,
                    child: CentralizedBadgeStream(
                      userId: currentUserId,
                      size: 15,
                      showPlus: false,
                      showDMs: false,
                      showFriendRequests: true,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: Image.asset(
                  'assets/icons/settings_icon.png',
                  width: 33,
                  height: 33,
                ),
                onPressed: onSettingsTap,
                tooltip: "Settings",
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Modular Badge Icon Widget (friends only) ---
class FriendsIconWithBadge extends StatelessWidget {
  final String currentUserId;
  final VoidCallback onTap;
  final Color iconColor;
  const FriendsIconWithBadge({
    required this.currentUserId,
    required this.onTap,
    required this.iconColor,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: Icon(Icons.people_alt_outlined, size: 27, color: iconColor),
          onPressed: onTap,
          tooltip: "Friends",
        ),
        Positioned(
          right: 4,
          top: 7,
          child: CentralizedBadgeStream(
            userId: currentUserId,
            size: 15,
            showPlus: false,
            showDMs: false,
            showFriendRequests: true,
          ),
        ),
      ],
    );
  }
}

// --- Centralized badge stream widget replacing nested StreamBuilders ---
class CentralizedBadgeStream extends StatefulWidget {
  final String userId;
  final double size;
  final bool showPlus;
  final bool showDMs;
  final bool showFriendRequests;

  const CentralizedBadgeStream({
    Key? key,
    required this.userId,
    this.size = 18,
    this.showPlus = true,
    this.showDMs = true,
    this.showFriendRequests = false,
  }) : super(key: key);

  @override
  State<CentralizedBadgeStream> createState() => _CentralizedBadgeStreamState();
}

class _CentralizedBadgeStreamState extends State<CentralizedBadgeStream> {
  // Single user document stream shared internally
  late final Stream<DocumentSnapshot> _userDocStream;

  // Stream for DM rooms (only if needed)
  late final Stream<QuerySnapshot> _dmRoomsStream;

  // Stream for friend requests (only if needed)
  late final Stream<QuerySnapshot> _friendRequestsStream;

  // Combined stream for total count
  late final Stream<int> _totalCountStream;

  @override
  void initState() {
    super.initState();

    _userDocStream = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .snapshots();

    _dmRoomsStream = widget.showDMs
        ? FirebaseFirestore.instance
        .collection('dm_rooms')
        .where('participants', arrayContains: widget.userId)
        .snapshots()
        : const Stream.empty();

    _friendRequestsStream = widget.showFriendRequests
        ? FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('friendRequests')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        : const Stream.empty();

    // Combine latest values from all streams and compute badge count
    _totalCountStream = Rx.combineLatest3<DocumentSnapshot, QuerySnapshot,
        QuerySnapshot, int>(
      _userDocStream,
      _dmRoomsStream,
      _friendRequestsStream,
          (userSnap, dmSnap, frSnap) {
        // Calculate unreadDM count
        int unreadDM = 0;
        final userData = userSnap.data() as Map<String, dynamic>? ?? {};
        final dmLastRead = Map<String, dynamic>.from(userData['dmLastRead'] ?? {});

        if (widget.showDMs && dmSnap.docs.isNotEmpty) {
          for (final doc in dmSnap.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final lastMsg = data['lastMessage'] as Map<String, dynamic>?;

            final lastMsgTime = lastMsg?['sentAt'] ?? lastMsg?['timestamp'];
            final lastMsgSender = lastMsg?['senderId'];
            final roomId = doc.id;
            final userLastReadTs = dmLastRead[roomId];

            if (lastMsgTime != null &&
                lastMsgSender != widget.userId &&
                (userLastReadTs == null ||
                    (userLastReadTs is Timestamp &&
                        lastMsgTime is Timestamp &&
                        lastMsgTime.compareTo(userLastReadTs) > 0))) {
              unreadDM++;
            }
          }
        }

        // Calculate pending friend requests count
        int pendingFR = 0;
        if (widget.showFriendRequests && frSnap.docs.isNotEmpty) {
          pendingFR = frSnap.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final type = data.containsKey('requestType') ? data['requestType'] : null;
            final displayStatus = data['displayStatus'] ?? data['status'] ?? '';
            return (type == null || type == 'received') && displayStatus != 'sent';
          }).length;
        }

        return unreadDM + pendingFR;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _totalCountStream,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        return NotificationBadge(
          count: count,
          size: widget.size,
          showPlus: widget.showPlus,
        );
      },
    );
  }
}
