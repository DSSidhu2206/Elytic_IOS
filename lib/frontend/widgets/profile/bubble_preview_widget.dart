// lib/frontend/widgets/profile/bubble_preview_widget.dart

import 'package:flutter/material.dart';
import '../chat/chat_bubbles/pirate_chat_bubble.dart';
import '../chat/chat_bubbles/galaxy_chat_bubble.dart';
import '../chat/chat_bubbles/cloud_chat_bubble.dart';
import '../chat/chat_bubbles/money_chat_bubble.dart';
import '../chat/chat_bubbles/neon_chat_bubble_blue.dart';
import '../chat/chat_bubbles/neon_chat_bubble_red.dart';
import '../chat/chat_bubbles/neon_chat_bubble_pink.dart';
import '../chat/chat_bubbles/neon_chat_bubble_green.dart';
import '../chat/chat_bubbles/neon_chat_bubble_yellow.dart';
import 'package:elytic/frontend/widgets/chat/chat_bubbles/neon_chat_bubble_purple.dart';
import '../chat/chat_bubbles/bookmark_chat_bubble.dart';
import '../chat/chat_bubbles/fruit_chat_bubble.dart';
import '../chat/chat_bubbles/comic_chat_bubble.dart';

Widget bubblePreviewWidget(String bubbleId) {
  switch (bubbleId) {
    case 'CB1002':
      return PirateChatBubble(
        text: "Ahoy, matey!",
      );
    case 'CB1003':
      return GalaxyChatBubble(
        text: "To the Stars!",
      );
    case 'CB1005':
      return CloudChatBubble(
        text: "Clouds!",
      );
    case 'CB1006':
      return MoneyChatBubble(
        text: "\$\$\$\$\$\$\$",
      );
    case 'CB1007':
      return NeonChatBubbleBlue(
        text: "Blue",
        textStyle: const TextStyle(
          color: Colors.cyanAccent,
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      );
    case 'CB1008':
      return NeonChatBubbleRed(
        text: "Red",
        textStyle: const TextStyle(
          color: Color(0xFFFF2B2B),
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      );
    case 'CB1009':
      return NeonChatBubblePink(
        text: "Pink",
        textStyle: const TextStyle(
          color: Color(0xFFFFB6C1),
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      );
    case 'CB1010':
      return NeonChatBubbleGreen(
        text: "Green",
        textStyle: const TextStyle(
          color: Color(0xFF00FF00),
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      );
    case 'CB1011':
      return NeonChatBubbleYellow(
        text: "Yellow",
        textStyle: const TextStyle(
          color: Color(0xFFFFFF00),
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      );
    case 'CB1012':
      return NeonChatBubblePurple(
        text: "Purple",
        textStyle: const TextStyle(
          color: Color(0xFF9B30FF),
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      );
    case 'CB1013':
      return BookmarkBubble(
        text: "Hey!",
        textStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      );
    case 'CB1014':
      return FruitChatBubble(
        text: "Yummy!!!!!",
        textStyle: const TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 15,
          color: Colors.black,
        ),
      );
    case 'CB1015':
    // PATCHED: Added SizedBox to constrain ComicChatBubble preview width
      return SizedBox(
        width: 300,
        child: ComicChatBubble(
          text: "Comic!",
          textStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: Colors.black,
          ),
        ),
      );
    default:
      return Card(
        color: Colors.brown[100],
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            "Classic bubble",
            style: TextStyle(fontSize: 15, color: Colors.brown[900]),
          ),
        ),
      );
  }
}
