// lib/frontend/screens/shop/admin_shop_rotation_screen.dart

import 'package:flutter/material.dart';
import 'admin_pet_rotation_tab.dart';
import 'admin_chat_bubble_rotation_tab.dart';
import 'admin_avatar_border_rotation_tab.dart';
import 'admin_mystery_box_rotation_tab.dart';

class AdminShopRotationScreen extends StatelessWidget {
  const AdminShopRotationScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Shop Rotations")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: DefaultTabController(
          length: 4,
          child: Column(
            children: [
              TabBar(
                tabs: [
                  Tab(icon: const Icon(Icons.pets), text: 'Pets'),
                  Tab(icon: const Icon(Icons.chat_bubble_outline), text: 'Chat Bubbles'),
                  Tab(icon: const Icon(Icons.crop_square), text: 'Avatar Borders'),
                  Tab(icon: const Icon(Icons.all_inbox), text: 'Mystery Boxes'),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: TabBarView(
                  children: [
                    AdminPetRotationTab(),
                    AdminChatBubbleRotationTab(),
                    AdminAvatarBorderRotationTab(),
                    AdminMysteryBoxRotationTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
