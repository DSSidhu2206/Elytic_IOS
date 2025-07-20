// lib/frontend/screens/social/dm_room_page.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../backend/services/dm_service.dart';
import '../../models/dm_message.dart';
import '../profile/user_profile_screen.dart';
import 'package:elytic/frontend/widgets/common/username_text.dart';
import 'package:elytic/frontend/helpers/avatar_helper.dart';
import 'package:intl/intl.dart'; // PATCHED: For 24-hour time formatting

class DMRoomPage extends StatefulWidget {
  final String otherUserId;
  final String otherUserName;
  final String otherUserAvatar;
  final bool readReceiptsEnabled;

  const DMRoomPage({
    super.key,
    required this.otherUserId,
    required this.otherUserName,
    required this.otherUserAvatar,
    required this.readReceiptsEnabled,
  });

  @override
  State<DMRoomPage> createState() => _DMRoomPageState();
}

class _DMRoomPageState extends State<DMRoomPage> {
  final DMService _dmService = DMService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late final String _currentUserId;
  late final String _roomId;
  int? _currentUserTier;

  bool _roomExists = false;
  bool _creatingRoom = false;

  // PATCHED: cache for last known good messages
  List<DMMessage> _lastGoodMessages = [];

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser!.uid;
    _roomId = _dmService.getRoomId(_currentUserId, widget.otherUserId);

    // Fetch current user's tier
    FirebaseFirestore.instance.collection('users').doc(_currentUserId).get().then((doc) {
      setState(() {
        _currentUserTier = doc.data()?['tier'] ?? 0;
      });
    });

    // Ensure room exists before listening for messages
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _ensureRoomExists();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _ensureRoomExists() async {
    setState(() { _creatingRoom = true; });
    final roomRef = FirebaseFirestore.instance.collection('dm_rooms').doc(_roomId);
    await roomRef.set({
      'participants': [_currentUserId, widget.otherUserId],
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessage': null,
    }, SetOptions(merge: true));
    setState(() {
      _creatingRoom = false;
      _roomExists = true;
    });
  }

  Future<void> _markDmAsRead(DMMessage? lastMsg) async {
    if (lastMsg == null) return;
    if (lastMsg.senderId == _currentUserId) return;
    var ts = lastMsg.sentAt ?? (lastMsg.toMap().containsKey('timestamp') ? lastMsg.toMap()['timestamp'] : null);
    Timestamp? markAs;
    if (ts is Timestamp) {
      markAs = ts;
    } else if (ts is DateTime) {
      markAs = Timestamp.fromDate(ts);
    } else {
      return;
    }
    await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUserId)
        .set({
      'dmLastRead': {
        _roomId: markAs,
      }
    }, SetOptions(merge: true));
  }

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();

    // Do NOT mark as read on sending
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => UserProfileScreen(
                  userId: widget.otherUserId,
                  currentUserId: _currentUserId,
                  currentUserTier: _currentUserTier ?? 0,
                ),
              ),
            );
          },
          child: Row(
            children: [
              CircleAvatar(backgroundImage: getAvatarImageProvider(widget.otherUserAvatar)),
              const SizedBox(width: 12),
              Flexible(
                child: UsernameText(
                  username: widget.otherUserName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: _creatingRoom
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Expanded(
            child: StreamBuilder<List<DMMessage>>(
              stream: _dmService.messageStream(_roomId),
              builder: (context, snapshot) {
                // PATCHED: Use last known good messages for smooth UX during errors/waiting
                if ((snapshot.connectionState == ConnectionState.waiting || snapshot.hasError) && _lastGoodMessages.isNotEmpty) {
                  return _buildMessagesList(_lastGoodMessages, isDarkMode);
                }
                final messages = snapshot.data ?? [];
                if (messages.isEmpty) {
                  return const Center(
                    child: Text(
                      "No messages yet.",
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  );
                }
                // Save for fallback
                _lastGoodMessages = messages;

                return _buildMessagesList(messages, isDarkMode);
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: "Type a message...",
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // PATCHED: Extracted for reuse & smoother UX
  Widget _buildMessagesList(List<DMMessage> messages, bool isDarkMode) {
    final lastMsg = messages.isNotEmpty ? messages.last : null;

    // Auto-scroll to bottom on new message
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });

    // Mark as read if needed whenever messages are received and last is from other user
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markDmAsRead(lastMsg);
    });

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      itemCount: messages.length,
      itemBuilder: (context, i) {
        final msg = messages[i];
        final isMe = msg.senderId == _currentUserId;
        return Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isMe
                  ? (isDarkMode ? Colors.white : Colors.blue[100])
                  : Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Text(
                  msg.text,
                  style: TextStyle(
                    color: isMe
                        ? (isDarkMode ? Colors.black : Colors.black)
                        : Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTimestamp(msg.sentAt), // PATCHED: Show 24-hour timestamp for all messages
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // PATCHED: Format sentAt as 24-hour time for all messages, robust to all types and missing/null
  String _formatTimestamp(dynamic sentAt) {
    DateTime? time;
    if (sentAt is Timestamp) {
      time = sentAt.toDate();
    } else if (sentAt is DateTime) {
      time = sentAt;
    } else if (sentAt is String) {
      // Attempt to parse Firestore Timestamp string or ISO
      try {
        time = DateTime.parse(sentAt);
      } catch (_) {}
    }
    if (time == null) return "";
    // Local time, 24h format
    return DateFormat('HH:mm').format(time.toLocal());
  }
}
