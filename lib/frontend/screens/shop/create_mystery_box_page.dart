// lib/frontend/screens/shop/create_mystery_box_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

class CreateMysteryBoxPage extends StatefulWidget {
  const CreateMysteryBoxPage({Key? key}) : super(key: key);

  @override
  State<CreateMysteryBoxPage> createState() => _CreateMysteryBoxPageState();
}

class _CreateMysteryBoxPageState extends State<CreateMysteryBoxPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  String _description = '';
  String _selectedRarity = 'Rare'; // Default
  int _coinPrice = 10; // <-- NEW: Coin price field

  // Selected IDs for each reward type
  final Set<String> _selectedItemIds = {};
  final Set<String> _selectedBorderIds = {};
  final Set<String> _selectedPetIds = {};
  final Set<String> _selectedBubbleIds = {};
  final Set<String> _selectedBadgeIds = {};

  static const List<String> rarities = ['Legendary', 'Epic', 'Rare'];
  static const String mysteryBoxAsset = 'assets/mystery_box.png';

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _fetchType(String collection) async {
    final snap = await FirebaseFirestore.instance.collection(collection).get();
    return snap.docs;
  }

  Future<String> _getNextMysteryBoxId() async {
    final docs = await FirebaseFirestore.instance
        .collection('mystery_box_data')
        .orderBy('mystery_box_id', descending: true)
        .limit(1)
        .get();
    if (docs.docs.isEmpty) return "MB1001";
    final lastId = docs.docs.first.data()['mystery_box_id'] as String? ?? "";
    final number = int.tryParse(lastId.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1000;
    return "MB${number + 1}";
  }

  Future<void> _createMysteryBox(String mysteryBoxId) async {
    if (!_formKey.currentState!.validate() ||
        _selectedItemIds.isEmpty && _selectedBorderIds.isEmpty &&
            _selectedPetIds.isEmpty && _selectedBubbleIds.isEmpty &&
            _selectedBadgeIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least 1 reward to include!')),
      );
      return;
    }
    _formKey.currentState!.save();

    final data = {
      'mystery_box_id': mysteryBoxId,
      'name': _name.trim(),
      'description': _description.trim(),
      'iconUrl': mysteryBoxAsset,
      'items': _selectedItemIds.isNotEmpty ? _selectedItemIds.toList() : [],
      'avatar_borders': _selectedBorderIds.isNotEmpty ? _selectedBorderIds.toList() : [],
      'pets': _selectedPetIds.isNotEmpty ? _selectedPetIds.toList() : [],
      'chat_bubbles': _selectedBubbleIds.isNotEmpty ? _selectedBubbleIds.toList() : [],
      'badges': _selectedBadgeIds.isNotEmpty ? _selectedBadgeIds.toList() : [],
      'createdAt': FieldValue.serverTimestamp(),
      'isActive': true,
      'rarity': _selectedRarity,
      'minRewards': 2,
      'maxRewards': 4,
      'coinPrice': _coinPrice, // <-- Include coinPrice in Firestore
    };

    await FirebaseFirestore.instance.collection('mystery_box_data').doc(mysteryBoxId).set(data);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mystery box created!')),
      );
      Navigator.of(context).pop();
    }
  }

  Widget _buildSelectTab({
    required String collection,
    required String title,
    required Set<String> selectedIds,
    String? iconField,
    String? labelField,
    String? rarityField,
  }) {
    return FutureBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      future: _fetchType(collection),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(24.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final docs = snapshot.data!;
        if (docs.isEmpty) {
          return const Center(child: Text('No items found.'));
        }
        return ListView(
          shrinkWrap: true,
          children: docs.map((doc) {
            final data = doc.data();
            final name = data[labelField ?? 'name'] ?? doc.id;
            final iconUrl = data[iconField ?? 'iconUrl'] ?? '';
            final rarity = data[rarityField ?? 'rarity'] ?? '';
            return CheckboxListTile(
              value: selectedIds.contains(doc.id),
              onChanged: (checked) {
                setState(() {
                  if (checked == true) {
                    selectedIds.add(doc.id);
                  } else {
                    selectedIds.remove(doc.id);
                  }
                });
              },
              title: Row(
                children: [
                  if (iconUrl.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: iconUrl,
                      height: 32,
                      width: 32,
                      fit: BoxFit.cover,
                      placeholder: (ctx, url) => const SizedBox(
                        width: 24,
                        height: 24,
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                      errorWidget: (ctx, e, s) => const Icon(Icons.broken_image, size: 28),
                    ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(name, overflow: TextOverflow.ellipsis)),
                  if (rarity.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Text(rarity, style: const TextStyle(fontSize: 10)),
                    ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Mystery Box')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<String>(
          future: _getNextMysteryBoxId(),
          builder: (context, idSnapshot) {
            if (!idSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final nextBoxId = idSnapshot.data!;
            return Form(
              key: _formKey,
              child: ListView(
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Next Mystery Box ID: $nextBoxId',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.deepPurple,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Icon
                  const Text('Mystery Box Icon', style: TextStyle(fontWeight: FontWeight.bold)),
                  Center(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.amber, width: 3),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 20, top: 8),
                      child: Image.asset(mysteryBoxAsset, height: 85, width: 85),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Rarity Dropdown
                  const Text('Mystery Box Rarity', style: TextStyle(fontWeight: FontWeight.bold)),
                  DropdownButtonFormField<String>(
                    value: _selectedRarity,
                    items: rarities.map((rarity) {
                      return DropdownMenuItem<String>(
                        value: rarity,
                        child: Text(rarity),
                      );
                    }).toList(),
                    onChanged: (v) {
                      setState(() {
                        _selectedRarity = v ?? 'Rare';
                      });
                    },
                    decoration: const InputDecoration(labelText: 'Select Rarity'),
                  ),
                  const SizedBox(height: 8),

                  // --- Coin Price Input ---
                  const Text('Mystery Box Price (coins)', style: TextStyle(fontWeight: FontWeight.bold)),
                  TextFormField(
                    initialValue: _coinPrice.toString(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Enter price in coins',
                      prefixIcon: Icon(Icons.monetization_on),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Enter a price';
                      final parsed = int.tryParse(value);
                      if (parsed == null || parsed < 0) return 'Enter a valid number';
                      return null;
                    },
                    onSaved: (value) {
                      _coinPrice = int.tryParse(value ?? '') ?? 10;
                    },
                  ),
                  const SizedBox(height: 8),

                  const Text('Step 1: Name & Description', style: TextStyle(fontWeight: FontWeight.bold)),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Mystery Box Name'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
                    onSaved: (v) => _name = v ?? '',
                  ),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Description'),
                    onSaved: (v) => _description = v ?? '',
                    maxLines: 2,
                  ),
                  const SizedBox(height: 20),

                  // Tabs for reward types
                  const Text('Step 2: Select Rewards to Include', style: TextStyle(fontWeight: FontWeight.bold)),
                  TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    labelColor: Theme.of(context).primaryColor,
                    unselectedLabelColor: Colors.grey,
                    tabs: const [
                      Tab(icon: Icon(Icons.shopping_bag), text: 'Items'),
                      Tab(icon: Icon(Icons.crop_square), text: 'Borders'),
                      Tab(icon: Icon(Icons.pets), text: 'Pets'),
                      Tab(icon: Icon(Icons.chat_bubble_outline), text: 'Bubbles'),
                      Tab(icon: Icon(Icons.verified), text: 'Badges'),
                    ],
                  ),
                  Container(
                    height: 320,
                    margin: const EdgeInsets.only(top: 8, bottom: 16),
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // Items
                        _buildSelectTab(
                          collection: 'item_data',
                          title: 'Items',
                          selectedIds: _selectedItemIds,
                        ),
                        // Borders
                        _buildSelectTab(
                          collection: 'avatar_border_data',
                          title: 'Avatar Borders',
                          selectedIds: _selectedBorderIds,
                        ),
                        // Pets
                        _buildSelectTab(
                          collection: 'pet_data',
                          title: 'Pets',
                          selectedIds: _selectedPetIds,
                        ),
                        // Chat Bubbles
                        _buildSelectTab(
                          collection: 'chat_bubble_data',
                          title: 'Chat Bubbles',
                          selectedIds: _selectedBubbleIds,
                        ),
                        // Badges
                        _buildSelectTab(
                          collection: 'badges_data',
                          title: 'Badges',
                          selectedIds: _selectedBadgeIds,
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => _createMysteryBox(nextBoxId),
                    child: const Text('Create Mystery Box'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
