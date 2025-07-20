import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'message_bubble.dart';
import 'package:elytic/backend/services/friend_service.dart';

class ChatMessage {
  final String userId;
  final String username;
  final String userAvatarUrl;
  final int userTier;
  final String text;
  final DateTime timestamp;
  final String? selectedChatBubbleId;
  final String? audioUrl;
  final String? userAvatarBorderUrl;
  final String? stickerId;
  final String? stickerUrl;      // PATCHED
  final String? stickerName;     // PATCHED
  final String? stickerPackId;   // PATCHED

  ChatMessage({
    required this.userId,
    required this.username,
    required this.userAvatarUrl,
    required this.userTier,
    required this.text,
    required this.timestamp,
    this.selectedChatBubbleId,
    this.audioUrl,
    this.userAvatarBorderUrl,
    this.stickerId,
    this.stickerUrl,
    this.stickerName,
    this.stickerPackId,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> data, String docId) {
    final rawTs = data['timestamp'];
    final ts = (rawTs is Timestamp) ? rawTs : Timestamp.now();

    final name = data['username'] as String? ?? 'Anonymous';

    final avatar = (data['userAvatarUrl'] as String?)
        ?? (data['avatarUrl'] as String?)
        ?? (data['avatarPath'] as String?)
        ?? 'assets/avatars/default.png';

    final tier = (data['userTier'] as num?)?.toInt()
        ?? (data['tier'] as num?)?.toInt()
        ?? 1;

    final borderUrl = data['userAvatarBorderUrl'] as String?
        ?? data['avatarBorderUrl'] as String?
        ?? '';

    final stickerId = data['stickerId'] as String?;
    final stickerUrl = data['stickerUrl'] as String?;        // PATCHED
    final stickerName = data['stickerName'] as String?;      // PATCHED
    final stickerPackId = data['stickerPackId'] as String?;  // PATCHED

    return ChatMessage(
      userId: data['senderId'] as String? ?? docId,
      username: name,
      userAvatarUrl: avatar,
      userTier: tier,
      text: data['text'] as String? ?? '',
      timestamp: ts.toDate(),
      selectedChatBubbleId: data['selectedChatBubbleId'] as String?,
      audioUrl: data['voiceUrl'] as String?,
      userAvatarBorderUrl: borderUrl,
      stickerId: stickerId,
      stickerUrl: stickerUrl,        // PATCHED
      stickerName: stickerName,      // PATCHED
      stickerPackId: stickerPackId,  // PATCHED
    );
  }
}

class MessageList extends StatefulWidget {
  final String roomId;
  final String currentUserId;
  final int currentUserTier;

  const MessageList({
    Key? key,
    required this.roomId,
    required this.currentUserId,
    required this.currentUserTier,
  }) : super(key: key);

  @override
  _MessageListState createState() => _MessageListState();
}

class _MessageListState extends State<MessageList> {
  final ScrollController _scrollController = ScrollController();
  Set<String> _blockedUserIds = {};

  @override
  void initState() {
    super.initState();
    _fetchBlockedUsers();
  }

  Future<void> _fetchBlockedUsers() async {
    final blocked = await FriendService.fetchBlockedUsers(widget.currentUserId);
    setState(() {
      _blockedUserIds = blocked.map((u) => u.userId).toSet();
    });
  }

  Stream<List<ChatMessage>> _messagesStream() {
    return FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) {
      return snap.docs
          .map((doc) => ChatMessage.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ChatMessage>>(
      stream: _messagesStream(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final messages = snap.data ?? [];

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });

        if (messages.isEmpty) {
          return const Center(child: Text('No messages yet'));
        }

        return ListView.separated(
          controller: _scrollController,
          reverse: true,
          padding: const EdgeInsets.all(0),
          itemCount: messages.length,
          itemBuilder: (context, i) {
            final msg = messages[i];
            if (_blockedUserIds.contains(msg.userId)) {
              return const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Blocked message",
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey,
                  ),
                ),
              );
            }
            return MessageBubble(
              message: msg,
              currentUserId: widget.currentUserId,
              currentUserTier: widget.currentUserTier,
            );
          },
          separatorBuilder: (_, __) => const SizedBox(height: 1),
        );
      },
    );
  }
}
