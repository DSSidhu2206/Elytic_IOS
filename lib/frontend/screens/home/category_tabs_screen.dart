// lib/frontend/screens/home/category_tabs_screen.dart

import 'package:flutter/material.dart';
import '/frontend/widgets/layout/category_list_screen.dart';
import 'vip_room_tab.dart'; // You’ll need to create this

class CategoryTabsScreen extends StatefulWidget {
  const CategoryTabsScreen({Key? key}) : super(key: key);

  @override
  State<CategoryTabsScreen> createState() => _CategoryTabsScreenState();
}

class _CategoryTabsScreenState extends State<CategoryTabsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rooms'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            const Tab(text: 'Basic'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/icons/crown.png',
                    width: 30,
                    height: 30,
                  ),
                  const SizedBox(width: 6),
                  const Text('VIP'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const CategoryListScreen(),
          VIPRoomTab(),
        ],
      ),
    );
  }
}
