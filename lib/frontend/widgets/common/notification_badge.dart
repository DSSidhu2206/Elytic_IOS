// lib/frontend/widgets/common/notification_badge.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationBadge extends StatelessWidget {
  final int count;
  final double size;
  final bool showPlus;
  const NotificationBadge({
    Key? key,
    required this.count,
    this.size = 18,
    this.showPlus = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    String text = count > 99 && showPlus ? "99+" : count.toString();
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: const BoxDecoration(
        color: Colors.red,
        shape: BoxShape.circle,
      ),
      constraints: BoxConstraints(
        minWidth: size,
        minHeight: size,
      ),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.6,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

/// --- UNIFIED BADGE: DM + Friend Requests (live StreamBuilder, bulletproof) ---
class UnifiedLiveBadge extends StatelessWidget {
  final String userId;
  final double size;
  final bool showPlus;
  final bool showDMs;
  final bool showFriendRequests;

  const UnifiedLiveBadge({
    Key? key,
    required this.userId,
    this.size = 18,
    this.showPlus = true,
    this.showDMs = true,
    this.showFriendRequests = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Listen to the user doc for live dmLastRead
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
      builder: (context, userSnap) {
        final userData = userSnap.data?.data() as Map<String, dynamic>? ?? {};
        final dmLastRead = Map<String, dynamic>.from(userData['dmLastRead'] ?? {});

        // Listen to all dm_rooms for this user
        return StreamBuilder<QuerySnapshot>(
          stream: showDMs
              ? FirebaseFirestore.instance
              .collection('dm_rooms')
              .where('participants', arrayContains: userId)
              .snapshots()
              : const Stream.empty(),
          builder: (context, roomSnap) {
            int unreadDM = 0;
            if (showDMs && roomSnap.hasData) {
              for (final doc in roomSnap.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                final lastMsg = data['lastMessage'] as Map<String, dynamic>?;

                if (lastMsg == null) continue;

                final lastMsgTime = lastMsg['sentAt'] ?? lastMsg['timestamp'];
                final lastMsgSender = lastMsg['senderId'];
                final roomId = doc.id;
                final userLastReadTs = dmLastRead[roomId];

                // Only show as unread if:
                // - There is a lastMsgTime
                // - Last message is NOT from this user
                // - userLastReadTs is null (never read), OR lastMsgTime > userLastReadTs
                if (lastMsgTime != null && lastMsgSender != userId) {
                  if (userLastReadTs == null) {
                    unreadDM++;
                  } else if (lastMsgTime is Timestamp && userLastReadTs is Timestamp) {
                    // Compare using .toDate() for bulletproof accuracy (Firestore guarantees monotonicity)
                    if (lastMsgTime.toDate().isAfter(userLastReadTs.toDate())) {
                      unreadDM++;
                    }
                  }
                }
              }
            }

            // Listen to friend requests subcollection for live updates
            return StreamBuilder<QuerySnapshot>(
              stream: showFriendRequests
                  ? FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .collection('friendRequests')
                  .where('status', isEqualTo: 'pending')
                  .snapshots()
                  : const Stream.empty(),
              builder: (context, frSnap) {
                int pendingFR = 0;
                if (showFriendRequests && frSnap.hasData) {
                  pendingFR = frSnap.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final type = data.containsKey('requestType') ? data['requestType'] : null;
                    return type == null || type == 'received';
                  }).length;
                }

                final totalCount = unreadDM + pendingFR;
                return NotificationBadge(count: totalCount, size: size, showPlus: showPlus);
              },
            );
          },
        );
      },
    );
  }
}
