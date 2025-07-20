// lib/frontend/screens/shop/admin_pet_rotation_tab.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elytic/frontend/helpers/avatar_helper.dart';
import 'package:elytic/frontend/utils/rarity_color.dart';

class AdminPetRotationTab extends StatefulWidget {
  const AdminPetRotationTab({Key? key}) : super(key: key);

  @override
  State<AdminPetRotationTab> createState() => _AdminPetRotationTabState();
}

class _AdminPetRotationTabState extends State<AdminPetRotationTab> {
  List<Map<String, dynamic>> _allPets = [];
  Set<int> _selectedPetIds = {};
  bool _loading = true, _saving = false;

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  Future<void> _fetchAll() async {
    setState(() => _loading = true);

    final petsSnapshot = await FirebaseFirestore.instance.collection('pet_data').get();
    final petList = petsSnapshot.docs.map((doc) {
      final data = doc.data();
      final petId = data['id'] ?? doc.id;
      return {
        'id': petId is int ? petId : int.tryParse(petId.toString()),
        'name': data['name'] ?? '',
        'iconUrl': data['iconUrl'],
        'rarity': data['rarity'],
        'isLocalAsset': data['isLocalAsset'] ?? false,
      };
    }).whereType<Map<String, dynamic>>().where((pet) => pet['id'] != null).toList();

    petList.sort((a, b) {
      final order = [
        'common', 'uncommon', 'rare', 'epic', 'legendary', 'limited', 'mythical'
      ];
      final iA = order.indexOf((a['rarity'] ?? '').toLowerCase());
      final iB = order.indexOf((b['rarity'] ?? '').toLowerCase());
      return iA.compareTo(iB);
    });

    final petRotationRef = FirebaseFirestore.instance.collection('shop_rotations').doc('pets');
    final petRotationDoc = await petRotationRef.get();
    List<dynamic> petRotationIds = [];
    if (petRotationDoc.exists && petRotationDoc.data() != null) {
      petRotationIds = petRotationDoc['currentRotation'] ?? [];
    } else {
      await petRotationRef.set({'currentRotation': [], 'lastUpdated': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    }

    setState(() {
      _allPets = petList;
      _selectedPetIds = petRotationIds.map((e) {
        if (e is int) return e;
        if (e is String) return int.tryParse(e);
        return null;
      }).whereType<int>().toSet();
      _loading = false;
    });
  }

  void _togglePet(int petId) {
    setState(() {
      if (_selectedPetIds.contains(petId)) {
        _selectedPetIds.remove(petId);
      } else {
        _selectedPetIds.add(petId);
      }
    });
  }

  Future<void> _saveRotation() async {
    setState(() => _saving = true);
    await FirebaseFirestore.instance
        .collection('shop_rotations')
        .doc('pets')
        .set({
      'currentRotation': _selectedPetIds.toList(),
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    setState(() => _saving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pet rotation updated!")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Select which pets appear in the shop:",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.separated(
            itemCount: _allPets.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, idx) {
              final pet = _allPets[idx];
              final isSelected = _selectedPetIds.contains(pet['id']);
              return Container(
                decoration: BoxDecoration(
                  color: rarityColor(pet['rarity'] ?? '').withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage: getAvatarImageProvider(pet['iconUrl']),
                    backgroundColor: Colors.grey[200],
                    child: (pet['iconUrl'] == null || pet['iconUrl'].toString().isEmpty)
                        ? const Icon(Icons.pets)
                        : null,
                  ),
                  title: Text(
                    pet['name'],
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: rarityColor(pet['rarity'] ?? ''),
                    ),
                  ),
                  subtitle: Text(pet['rarity'] ?? ''),
                  trailing: Checkbox(
                    value: isSelected,
                    onChanged: (_) => _togglePet(pet['id']),
                  ),
                  onTap: () => _togglePet(pet['id']),
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
