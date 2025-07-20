// lib/frontend/widgets/inventory/pets_inventory_tab.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';

class PetsInventoryTab extends StatefulWidget {
  const PetsInventoryTab({Key? key}) : super(key: key);

  @override
  State<PetsInventoryTab> createState() => _PetsInventoryTabState();
}

class _PetsInventoryTabState extends State<PetsInventoryTab> {
  String? _mainPetId;
  bool _isSettingMain = false;

  @override
  void initState() {
    super.initState();
    _fetchMainPetId();
  }

  Future<void> _fetchMainPetId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final snap = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    setState(() {
      _mainPetId = snap.data()?['mainPetId']?.toString();
    });
  }

  Future<void> _setMainPet(String petId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _isSettingMain = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({'mainPetId': petId});
      setState(() => _mainPetId = petId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Main pet updated!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to set main pet: $e')),
        );
      }
    }
    setState(() => _isSettingMain = false);
  }

  Future<List<Map<String, dynamic>>> _fetchPetData(List<String> petIds) async {
    final firestore = FirebaseFirestore.instance;
    final futures = petIds.map((petId) async {
      final doc = await firestore.collection('pet_data').doc(petId).get();
      if (!doc.exists) return null;
      final data = doc.data()!..['petId'] = petId;
      return data;
    }).toList();
    final results = await Future.wait(futures);
    return results.whereType<Map<String, dynamic>>().toList();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text('Not signed in.'));

    final userPetsRef = FirebaseFirestore.instance.collection('users').doc(user.uid).collection('pets');

    return StreamBuilder<QuerySnapshot>(
      stream: userPetsRef.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No pets owned.'));
        }
        final docs = snapshot.data!.docs;
        final petIds = docs.map((doc) => doc.id).toList();

        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _fetchPetData(petIds),
          builder: (context, petSnapshot) {
            if (petSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final petDataList = petSnapshot.data ?? [];
            if (petDataList.isEmpty) {
              return const Center(child: Text('No matching pets found.'));
            }
            return GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 160,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.85,
              ),
              itemCount: petDataList.length,
              itemBuilder: (context, i) {
                final petData = petDataList[i];
                final thisPetId = petData['petId']?.toString() ?? '';
                final isMain = _mainPetId == thisPetId;

                Widget imageWidget;
                final iconUrl = petData['iconUrl'];
                if (iconUrl != null && iconUrl.toString().isNotEmpty) {
                  if (iconUrl.toString().startsWith('http')) {
                    imageWidget = CachedNetworkImage(
                      imageUrl: iconUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                      const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      errorWidget: (context, error, stackTrace) =>
                      const Icon(Icons.pets, size: 48),
                    );
                  } else {
                    imageWidget = Image.asset(
                      iconUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => const Icon(Icons.pets, size: 48),
                    );
                  }
                } else {
                  imageWidget = const Icon(Icons.pets, size: 48);
                }

                return GestureDetector(
                  onTap: _isSettingMain
                      ? null
                      : () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Set as Main Pet?'),
                        content: Text(
                          'Do you want to set "${petData['name'] ?? thisPetId}" as your main pet?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Set as Main'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      _setMainPet(thisPetId);
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isMain ? Colors.amber : Colors.grey.shade300,
                        width: isMain ? 3 : 1,
                      ),
                      boxShadow: isMain
                          ? [
                        BoxShadow(
                          color: Colors.amber.withOpacity(0.4),
                          blurRadius: 12,
                          spreadRadius: 2,
                        )
                      ]
                          : [],
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final size = constraints.maxWidth * 0.5;
                            return SizedBox(
                              width: size,
                              height: size,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(size * 0.25),
                                child: imageWidget,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        Flexible(
                          child: Text(
                            petData['name'] ?? petData['petId'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                          ),
                        ),
                        if (petData['level'] != null)
                          Flexible(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Text(
                                'Lv. ${petData['level']}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.deepPurple,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                softWrap: false,
                              ),
                            ),
                          ),
                        if (petData['rarity'] != null)
                          Flexible(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Text(
                                petData['rarity'],
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.blueGrey,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                softWrap: false,
                              ),
                            ),
                          ),
                        if (isMain)
                          const Padding(
                            padding: EdgeInsets.only(top: 4.0),
                            child: Text(
                              'Main',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.amber,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
