// lib/frontend/screens/social/dm_list_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elytic/frontend/screens/social/dm_room_page.dart';
import 'package:elytic/frontend/helpers/avatar_helper.dart';
// PATCH: Import UserService & UserDisplayInfo
import 'package:elytic/backend/services/user_service.dart';

class DmListPage extends StatefulWidget {
  final String currentUserId;

  const DmListPage({super.key, required this.currentUserId});

  @override
  State<DmListPage> createState() => _DmListPageState();
}

class _DmListPageState extends State<DmListPage> {
  // Get all DM rooms where user is a participant
  Stream<QuerySnapshot> _dmRoomsStream() {
    return FirebaseFirestore.instance
        .collection('dm_rooms')
        .where('participants', arrayContains: widget.currentUserId)
        .snapshots();
  }

  // PATCH: Cache for user info in the page, just in case
  Map<String, UserDisplayInfo> _userInfoCache = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Direct Messages"),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 1,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _dmRoomsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          var rooms = snapshot.data?.docs ?? [];
          if (rooms.isEmpty) {
            return const Center(child: Text("No conversations yet."));
          }
          // Sort rooms by lastMessage.timestamp (or createdAt fallback)
          rooms.sort((a, b) {
            var aTs = (a['lastMessage']?['timestamp'] ?? a['createdAt']) as Timestamp?;
            var bTs = (b['lastMessage']?['timestamp'] ?? b['createdAt']) as Timestamp?;
            if (aTs == null && bTs == null) return 0;
            if (aTs == null) return 1;
            if (bTs == null) return -1;
            return bTs.compareTo(aTs);
          });

          // PATCH: Extract all other user IDs, batch fetch info
          final otherUserIds = <String>[];
          final roomOtherUserMap = <String, String>{}; // roomId -> otherUserId
          for (final doc in rooms) {
            final List participants = doc['participants'] ?? [];
            final otherUserId = participants.firstWhere(
                  (id) => id != widget.currentUserId,
              orElse: () => null,
            );
            if (otherUserId != null) {
              otherUserIds.add(otherUserId);
              roomOtherUserMap[doc.id] = otherUserId;
            }
          }
          if (otherUserIds.isEmpty) {
            return const Center(child: Text("No conversations yet."));
          }

          // PATCH: Batch fetch all user info, then build ListView
          return FutureBuilder<Map<String, UserDisplayInfo>>(
            future: UserService.fetchMultipleProfileInfos(otherUserIds),
            builder: (context, userInfoSnap) {
              if (!userInfoSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final userInfoMap = userInfoSnap.data!;
              _userInfoCache = userInfoMap; // cache in page for possible rebuilds

              return ListView.separated(
                itemCount: rooms.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final room = rooms[i];
                  final lastMsg = room['lastMessage'];
                  final otherUserId = roomOtherUserMap[room.id];
                  if (otherUserId == null) return const SizedBox.shrink();

                  final userInfo = userInfoMap[otherUserId] ?? UserDisplayInfo.fromMap(otherUserId, null);

                  // Listen for user's dmLastRead in a StreamBuilder
                  return StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(widget.currentUserId)
                        .snapshots(),
                    builder: (context, userDocSnap) {
                      final userDoc = userDocSnap.data;
                      Map<String, dynamic> dmLastRead = {};
                      if (userDoc != null && userDoc.data() != null) {
                        final docData = userDoc.data() as Map<String, dynamic>;
                        if (docData['dmLastRead'] is Map<String, dynamic>) {
                          dmLastRead = docData['dmLastRead'];
                        }
                      }
                      final lastRead = dmLastRead[room.id];
                      final lastMsgTs = lastMsg?['timestamp'] ?? room['createdAt'];
                      final lastMsgSender = lastMsg?['senderId'];

                      // Unread logic
                      bool hasUnread = false;
                      if (lastMsg != null && lastMsgSender != null && lastMsgTs != null) {
                        if (lastMsgSender != widget.currentUserId) {
                          if (lastRead == null) {
                            hasUnread = true;
                          } else if (lastMsgTs is Timestamp && lastRead is Timestamp) {
                            hasUnread = lastMsgTs.toDate().isAfter(lastRead.toDate());
                          } else if (lastMsgTs is Timestamp && lastRead is! Timestamp) {
                            hasUnread = true;
                          }
                        }
                      }

                      return ListTile(
                        leading: Stack(
                          children: [
                            CircleAvatar(
                              backgroundImage: getAvatarImageProvider(userInfo.avatarUrl),
                              radius: 24,
                            ),
                            if (hasUnread)
                              Positioned(
                                right: 0,
                                top: 0,
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        title: Text(
                          userInfo.username,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: hasUnread
                            ? const Text(
                          "Unread message",
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                            : Text(
                          lastMsg?['text'] ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: hasUnread
                            ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            "NEW",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                            : null,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DMRoomPage(
                                otherUserId: otherUserId,
                                otherUserName: userInfo.username,
                                otherUserAvatar: userInfo.avatarUrl,
                                readReceiptsEnabled: userInfo.readReceiptsEnabled ?? true,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
