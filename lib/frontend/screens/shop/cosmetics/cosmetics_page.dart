// lib/frontend/screens/shop/cosmetics/cosmetics_page.dart

import 'package:flutter/material.dart';
import 'profile_tab.dart';
import 'pets_tab.dart';

class CosmeticsPage extends StatelessWidget {
  const CosmeticsPage({Key? key}) : super(key: key);

  static const List<Tab> tabs = [
    Tab(icon: Icon(Icons.person_outline), text: "Profile"), // Merged tab
    Tab(icon: Icon(Icons.pets), text: "Companions"),
  ];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: tabs.length,
      child: Column(
        children: [
          const SizedBox(height: 12),
          TabBar(
            tabs: tabs,
            isScrollable: false, // Make tabs evenly spaced
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                ProfileTab(), // The merged tab now
                PetsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
