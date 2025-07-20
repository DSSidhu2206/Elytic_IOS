// lib/frontend/screens/shop/shop_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'subscriptions_page.dart';
import 'cosmetics/cosmetics_page.dart';
import 'coins_page.dart';
import '../../widgets/shop/inventory_page.dart';
import 'mystery_boxes_tab.dart';
import 'daily_tab.dart';

class ShopPage extends StatelessWidget {
  final int initialIndex;

  const ShopPage({Key? key, this.initialIndex = 0}) : super(key: key);

  static const List<Tab> shopTabs = [
    Tab(icon: Icon(Icons.today), text: "Daily"),
    Tab(icon: Icon(Icons.all_inbox), text: "Mystery Boxes"),
    Tab(icon: Icon(Icons.workspace_premium), text: "Subscriptions"),
    Tab(icon: Icon(Icons.brush), text: "Cosmetics"),
    Tab(icon: Icon(Icons.monetization_on), text: "Coins"),
  ];

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    Widget coinCountBar = userId == null
        ? Container(
      height: 48,
      color: Colors.grey[100],
      alignment: Alignment.center,
      child: const Text(
        "Sign in to view coins",
        style: TextStyle(
          color: Colors.black54,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
    )
        : StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .snapshots(),
      builder: (context, snapshot) {
        String coinCount = "0";
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data()! as Map<String, dynamic>;
          if (data.containsKey('coins')) {
            coinCount = data['coins'].toString();
          }
        }
        return Container(
          height: 48,
          color: Colors.grey[100],
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.monetization_on,
                  color: Colors.amber, size: 28),
              const SizedBox(width: 8),
              Text(
                coinCount,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                "coins",
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        );
      },
    );

    return DefaultTabController(
      length: shopTabs.length,
      initialIndex: initialIndex, // <--- pass initialIndex here
      child: Builder(
        builder: (context) {
          final TabController tabController = DefaultTabController.of(context)!;
          return Scaffold(
            appBar: AppBar(
              title: const Text('Elytic Shop'),
              actions: [
                TextButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const InventoryPage()),
                  ),
                  icon: const Icon(Icons.inventory, color: Colors.black, size: 22),
                  label: const Text(
                    "Inventory",
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: TextButton.styleFrom(foregroundColor: Colors.black),
                ),
              ],
              elevation: 2,
              backgroundColor: Colors.white,
              iconTheme: const IconThemeData(color: Colors.black),
            ),
            body: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                coinCountBar,
                Material(
                  color: Colors.white,
                  elevation: 2,
                  child: TabBar(
                    controller: tabController,
                    tabs: shopTabs,
                    indicatorWeight: 3,
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const Divider(height: 0, thickness: 0),
                Expanded(
                  child: TabBarView(
                    controller: tabController,
                    children: const [
                      DailyTab(),
                      MysteryBoxesTab(),
                      SubscriptionsPage(),
                      CosmeticsPage(),
                      CoinsPage(),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
