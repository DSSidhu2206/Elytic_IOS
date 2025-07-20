// lib/frontend/screens/chat/chat_screen.dart

import 'package:flutter/material.dart';
import 'package:elytic/frontend/widgets/chat/message_list.dart';

class ChatScreen extends StatelessWidget {
  final String roomId;
  final String currentUserId;
  final String userName;
  final String userImageUrl;
  final int currentUserTier;

  const ChatScreen({
    Key? key,
    required this.roomId,
    required this.currentUserId,
    required this.userName,
    required this.userImageUrl,
    required this.currentUserTier,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).brightness == Brightness.dark
          ? Colors.grey[900]   // lighter black in dark mode
          : Colors.grey[500],  // dark grey in light mode
      child: MessageList(
        roomId: roomId,
        currentUserId: currentUserId,
        currentUserTier: currentUserTier, // <-- PATCHED
      ),
    );
  }
}
