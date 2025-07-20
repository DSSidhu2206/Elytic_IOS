// lib/frontend/screens/shop/admin_chat_bubble_rotation_tab.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elytic/frontend/utils/rarity_color.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AdminChatBubbleRotationTab extends StatefulWidget {
  const AdminChatBubbleRotationTab({Key? key}) : super(key: key);

  @override
  State<AdminChatBubbleRotationTab> createState() => _AdminChatBubbleRotationTabState();
}

class _AdminChatBubbleRotationTabState extends State<AdminChatBubbleRotationTab> {
  List<Map<String, dynamic>> _allBubbles = [];
  Set<String> _selectedBubbleIds = {};
  bool _loading = true, _saving = false;

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  Future<void> _fetchAll() async {
    setState(() => _loading = true);
    final bubblesSnapshot = await FirebaseFirestore.instance.collection('chat_bubble_data').get();
    final bubbleList = bubblesSnapshot.docs.map((doc) {
      final data = doc.data();
      final id = data['bubble_id'] ?? doc.id;
      if (id == null) return null;
      return {
        'bubble_id': id.toString(),
        'name': data['name'] ?? '',
        'iconUrl': data['iconUrl'],
        'rarity': data['rarity'] ?? '',
      };
    }).whereType<Map<String, dynamic>>().toList();

    bubbleList.sort((a, b) {
      final order = [
        'common', 'uncommon', 'rare', 'epic', 'legendary', 'limited', 'mythical'
      ];
      final iA = order.indexOf((a['rarity'] ?? '').toLowerCase());
      final iB = order.indexOf((b['rarity'] ?? '').toLowerCase());
      return iA.compareTo(iB);
    });

    final rotationRef = FirebaseFirestore.instance.collection('shop_rotations').doc('chat_bubbles');
    final rotationDoc = await rotationRef.get();
    List<dynamic> rotationIds = [];
    if (rotationDoc.exists && rotationDoc.data() != null) {
      rotationIds = rotationDoc['currentRotation'] ?? [];
    } else {
      await rotationRef.set({'currentRotation': [], 'lastUpdated': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    }

    setState(() {
      _allBubbles = bubbleList;
      _selectedBubbleIds = rotationIds.map((e) => e.toString()).toSet();
      _loading = false;
    });
  }

  void _toggleBubble(String id) {
    setState(() {
      if (_selectedBubbleIds.contains(id)) {
        _selectedBubbleIds.remove(id);
      } else {
        _selectedBubbleIds.add(id);
      }
    });
  }

  Future<void> _saveRotation() async {
    setState(() => _saving = true);
    await FirebaseFirestore.instance
        .collection('shop_rotations')
        .doc('chat_bubbles')
        .set({
      'currentRotation': _selectedBubbleIds.toList(),
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    setState(() => _saving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Chat bubble rotation updated!")),
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
          "Select chat bubbles for shop:",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.separated(
            itemCount: _allBubbles.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, idx) {
              final bubble = _allBubbles[idx];
              final isSelected = _selectedBubbleIds.contains(bubble['bubble_id']);
              return Container(
                decoration: BoxDecoration(
                  color: rarityColor(bubble['rarity'] ?? '').withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ListTile(
                  leading: bubble['iconUrl'] != null && bubble['iconUrl'].toString().isNotEmpty
                      ? CachedNetworkImage(
                    imageUrl: bubble['iconUrl'],
                    width: 42,
                    height: 42,
                    fit: BoxFit.cover,
                    placeholder: (ctx, url) => const SizedBox(
                      width: 28,
                      height: 28,
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                    errorWidget: (ctx, e, s) => const Icon(Icons.broken_image, size: 32),
                  )
                      : const Icon(Icons.chat_bubble_outline),
                  title: Text(
                    bubble['name'],
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: rarityColor(bubble['rarity'] ?? ''),
                    ),
                  ),
                  subtitle: Text(bubble['rarity'] ?? ''),
                  trailing: Checkbox(
                    value: isSelected,
                    onChanged: (_) => _toggleBubble(bubble['bubble_id']),
                  ),
                  onTap: () => _toggleBubble(bubble['bubble_id']),
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
