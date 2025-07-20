import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Import the new modular tab widgets:
import '../inventory/mystery_box_inventory_tab.dart';
import '../inventory/borders_inventory_tab.dart';
import '../inventory/bubbles_inventory_tab.dart';
import '../inventory/badges_inventory_tab.dart';
import '../inventory/pets_inventory_tab.dart';
import '../inventory/items_inventory_tab.dart';
import '../inventory/sticker_inventory_tab.dart'; // ✅ NEW import

class InventoryPage extends StatefulWidget {
  const InventoryPage({Key? key}) : super(key: key);

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final user = FirebaseAuth.instance.currentUser;

  String? userName;
  int? tier;
  String? roomId;
  double? x;
  double? y;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this); // ✅ Updated from 6 to 7
    _fetchUserInfo();
  }

  Future<void> _fetchUserInfo() async {
    if (user == null) {
      setState(() => _loading = false);
      return;
    }
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
    final data = userDoc.data() ?? {};
    setState(() {
      userName = data['username'] ?? '';
      tier = data['tier'] is int ? data['tier'] : int.tryParse('${data['tier'] ?? 0}') ?? 0;
      // Set dummy roomId/x/y for now; replace with actual values if needed for context
      roomId = 'general1';
      x = 0.5;
      y = 0.5;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Not signed in')),
      );
    }
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return DefaultTabController(
      length: 7, // ✅ Updated from 6 to 7
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Your Inventory"),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.all_inbox), text: "Mystery Boxes"),
              Tab(icon: Icon(Icons.panorama_fish_eye), text: "Borders"),
              Tab(icon: Icon(Icons.chat_bubble_outline), text: "Bubbles"),
              Tab(icon: Icon(Icons.verified), text: "Badges"),
              Tab(icon: Icon(Icons.pets), text: "Companions"),
              Tab(icon: Icon(Icons.inventory), text: "Items"),
              Tab(icon: Icon(Icons.sticky_note_2_outlined), text: "Stickers"), // ✅ NEW Tab
            ],
          ),
        ),
        body: TabBarView(
          children: [
            const MysteryBoxesInventoryTab(),
            BordersInventoryTab(
              roomId: roomId ?? '',
              userName: userName ?? '',
              tier: tier ?? 0,
              x: x ?? 0.5,
              y: y ?? 0.5,
            ),
            const BubblesInventoryTab(),
            const BadgesInventoryTab(),
            const PetsInventoryTab(),
            const ItemsInventoryTab(),
            const StickerInventoryTab(), // ✅ NEW Tab View
          ],
        ),
      ),
    );
  }
}
