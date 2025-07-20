// lib/frontend/screens/profile/cosmetic_settings_page.dart

import 'package:flutter/material.dart';
import '../../widgets/profile/cosmetic_section_chat_bubbles.dart';
import '../../widgets/profile/cosmetic_section_avatar_borders.dart';
import '../../widgets/profile/cosmetic_section_themes_card.dart';

class CosmeticSettingsPage extends StatelessWidget {
  const CosmeticSettingsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cosmetic Settings'),
        backgroundColor: const Color(0xFF393185),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          CosmeticSectionChatBubbles(),
          SizedBox(height: 32),
          CosmeticSectionAvatarBorders(),
          SizedBox(height: 32),
          CosmeticSectionThemesCard(),
          SizedBox(height: 32),
        ],
      ),
    );
  }
}
