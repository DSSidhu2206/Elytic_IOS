// lib/frontend/screens/shop/admin_mystery_box_rotation_tab.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elytic/frontend/utils/rarity_color.dart';

class AdminMysteryBoxRotationTab extends StatefulWidget {
  const AdminMysteryBoxRotationTab({Key? key}) : super(key: key);

  @override
  State<AdminMysteryBoxRotationTab> createState() => _AdminMysteryBoxRotationTabState();
}

class _AdminMysteryBoxRotationTabState extends State<AdminMysteryBoxRotationTab> {
  List<Map<String, dynamic>> _allBoxes = [];
  Set<String> _selectedBoxIds = {};
  bool _loading = true, _saving = false;

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  Future<void> _fetchAll() async {
    setState(() => _loading = true);
    final boxesSnapshot = await FirebaseFirestore.instance.collection('mystery_box_data').get();
    final boxList = boxesSnapshot.docs.map((doc) {
      final data = doc.data();
      final id = data['box_id'] ?? doc.id;
      if (id == null) return null;
      return {
        'box_id': id.toString(),
        'name': data['name'] ?? '',
        'iconUrl': data['iconUrl'],
        'rarity': data['rarity'] ?? '',
      };
    }).whereType<Map<String, dynamic>>().toList();

    boxList.sort((a, b) {
      final order = [
        'common', 'uncommon', 'rare', 'epic', 'legendary', 'limited', 'mythical'
      ];
      final iA = order.indexOf((a['rarity'] ?? '').toLowerCase());
      final iB = order.indexOf((b['rarity'] ?? '').toLowerCase());
      return iA.compareTo(iB);
    });

    final rotationRef = FirebaseFirestore.instance.collection('shop_rotations').doc('mystery_boxes');
    final rotationDoc = await rotationRef.get();
    List<dynamic> rotationIds = [];
    if (rotationDoc.exists && rotationDoc.data() != null) {
      rotationIds = rotationDoc['currentRotation'] ?? [];
    } else {
      await rotationRef.set({'currentRotation': [], 'lastUpdated': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    }

    setState(() {
      _allBoxes = boxList;
      _selectedBoxIds = rotationIds.map((e) => e.toString()).toSet();
      _loading = false;
    });
  }

  void _toggleBox(String id) {
    setState(() {
      if (_selectedBoxIds.contains(id)) {
        _selectedBoxIds.remove(id);
      } else {
        _selectedBoxIds.add(id);
      }
    });
  }

  Future<void> _saveRotation() async {
    setState(() => _saving = true);
    await FirebaseFirestore.instance
        .collection('shop_rotations')
        .doc('mystery_boxes')
        .set({
      'currentRotation': _selectedBoxIds.toList(),
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    setState(() => _saving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Mystery box rotation updated!")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Select mystery boxes for shop:",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.separated(
            itemCount: _allBoxes.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, idx) {
              final box = _allBoxes[idx];
              final isSelected = _selectedBoxIds.contains(box['box_id']);
              return Container(
                decoration: BoxDecoration(
                  color: rarityColor(box['rarity'] ?? '').withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ListTile(
                  leading: Builder(
                    builder: (context) {
                      final iconUrl = box['iconUrl'];
                      if (iconUrl == null || iconUrl.toString().isEmpty) {
                        return const Icon(Icons.all_inbox, size: 42);
                      } else if (iconUrl.toString().startsWith('http')) {
                        return Image.network(iconUrl, width: 42, height: 42, errorBuilder: (_, __, ___) => const Icon(Icons.all_inbox, size: 42));
                      } else if (iconUrl.toString().startsWith('assets/')) {
                        return Image.asset(iconUrl, width: 42, height: 42, errorBuilder: (_, __, ___) => const Icon(Icons.all_inbox, size: 42));
                      } else {
                        return const Icon(Icons.all_inbox, size: 42);
                      }
                    },
                  ),
                  title: Text(
                    box['name'],
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: rarityColor(box['rarity'] ?? ''),
                    ),
                  ),
                  subtitle: Text(box['rarity'] ?? ''),
                  trailing: Checkbox(
                    value: isSelected,
                    onChanged: (_) => _toggleBox(box['box_id']),
                  ),
                  onTap: () => _toggleBox(box['box_id']),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          icon: const Icon(Icons.save),
          label: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text("Save Rotation"),
          onPressed: _saving ? null : _saveRotation,
        ),
      ],
    );
  }
}
