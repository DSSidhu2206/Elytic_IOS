// lib/frontend/screens/shop/admin_avatar_border_rotation_tab.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elytic/frontend/utils/rarity_color.dart';

class AdminAvatarBorderRotationTab extends StatefulWidget {
  const AdminAvatarBorderRotationTab({Key? key}) : super(key: key);

  @override
  State<AdminAvatarBorderRotationTab> createState() => _AdminAvatarBorderRotationTabState();
}

class _AdminAvatarBorderRotationTabState extends State<AdminAvatarBorderRotationTab> {
  List<Map<String, dynamic>> _allBorders = [];
  Set<String> _selectedBorderIds = {};
  bool _loading = true, _saving = false;

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  Future<void> _fetchAll() async {
    setState(() => _loading = true);

    final bordersSnapshot = await FirebaseFirestore.instance.collection('avatar_border_data').get();
    final borderList = bordersSnapshot.docs.map((doc) {
      final data = doc.data();
      final id = data['border_id'] ?? doc.id;
      if (id == null) return null;
      return {
        'border_id': id.toString(),
        'name': data['name'] ?? '',
        'imageUrl': data['imageUrl'],
        'rarity': data['rarity'] ?? '',
      };
    }).whereType<Map<String, dynamic>>().toList();

    borderList.sort((a, b) {
      final order = [
        'common', 'uncommon', 'rare', 'epic', 'legendary', 'limited', 'mythical'
      ];
      final iA = order.indexOf((a['rarity'] ?? '').toLowerCase());
      final iB = order.indexOf((b['rarity'] ?? '').toLowerCase());
      return iA.compareTo(iB);
    });

    final rotationRef = FirebaseFirestore.instance.collection('shop_rotations').doc('avatar_borders');
    final rotationDoc = await rotationRef.get();
    List<dynamic> rotationIds = [];
    if (rotationDoc.exists && rotationDoc.data() != null) {
      rotationIds = rotationDoc['currentRotation'] ?? [];
    } else {
      await rotationRef.set({'currentRotation': [], 'lastUpdated': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    }

    setState(() {
      _allBorders = borderList;
      _selectedBorderIds = rotationIds.map((e) => e.toString()).toSet();
      _loading = false;
    });
  }

  void _toggleBorder(String id) {
    setState(() {
      if (_selectedBorderIds.contains(id)) {
        _selectedBorderIds.remove(id);
      } else {
        _selectedBorderIds.add(id);
      }
    });
  }

  Future<void> _saveRotation() async {
    setState(() => _saving = true);
    await FirebaseFirestore.instance
        .collection('shop_rotations')
        .doc('avatar_borders')
        .set({
      'currentRotation': _selectedBorderIds.toList(),
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    setState(() => _saving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Avatar border rotation updated!")),
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
          "Select avatar borders for shop:",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.separated(
            itemCount: _allBorders.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, idx) {
              final border = _allBorders[idx];
              final isSelected = _selectedBorderIds.contains(border['border_id']);
              return Container(
                decoration: BoxDecoration(
                  color: rarityColor(border['rarity'] ?? '').withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ListTile(
                  leading: border['imageUrl'] != null && border['imageUrl'].toString().isNotEmpty
                      ? Image.network(border['imageUrl'], width: 42, height: 42)
                      : const Icon(Icons.crop_square),
                  title: Text(
                    border['name'],
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: rarityColor(border['rarity'] ?? ''),
                    ),
                  ),
                  subtitle: Text(border['rarity'] ?? ''),
                  trailing: Checkbox(
                    value: isSelected,
                    onChanged: (_) => _toggleBorder(border['border_id']),
                  ),
                  onTap: () => _toggleBorder(border['border_id']),
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
