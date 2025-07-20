// lib/frontend/screens/pets/pet_tab.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elytic/frontend/widgets/full_screen_pet.dart';
import 'package:elytic/frontend/utils/rarity_color.dart'; // <--- import rarityColor here
import 'package:cached_network_image/cached_network_image.dart';

class Pet {
  final int id;
  final String ownerId; // PATCHED
  final String name;
  final String? nickname;
  final String iconUrl;
  final String cardUrl;
  final String rarity;
  final bool isPremium;
  final bool isLocalAsset;
  final String description;
  final int level;

  Pet({
    required this.id,
    required this.ownerId, // PATCHED
    required this.name,
    this.nickname,
    required this.iconUrl,
    required this.cardUrl,
    required this.rarity,
    required this.isPremium,
    required this.isLocalAsset,
    required this.description,
    required this.level,
  });

  // PATCHED: Added ownerId (required!)
  factory Pet.fromMap(Map<String, dynamic> petData, {
    String? nickname,
    int? level,
    String? ownerId, // PATCHED
  }) {
    return Pet(
      id: (petData['id'] is int) ? petData['id'] : int.tryParse(petData['id'].toString()) ?? 0,
      ownerId: ownerId ?? petData['ownerId'] ?? '', // PATCHED
      name: petData['name'] ?? '',
      nickname: nickname ?? petData['nickname'],
      iconUrl: petData['iconUrl'] ?? '',
      cardUrl: petData['cardUrl'] ?? '',
      rarity: petData['rarity'] ?? '',
      isPremium: petData['isPremium'] ?? false,
      isLocalAsset: petData['isLocalAsset'] ?? true,
      description: petData['description'] ?? '',
      level: level ?? 1,
    );
  }

  // PATCHED: Added copyWith method
  Pet copyWith({
    int? id,
    String? ownerId,
    String? name,
    String? nickname,
    String? iconUrl,
    String? cardUrl,
    String? rarity,
    bool? isPremium,
    bool? isLocalAsset,
    String? description,
    int? level,
  }) {
    return Pet(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      nickname: nickname ?? this.nickname,
      iconUrl: iconUrl ?? this.iconUrl,
      cardUrl: cardUrl ?? this.cardUrl,
      rarity: rarity ?? this.rarity,
      isPremium: isPremium ?? this.isPremium,
      isLocalAsset: isLocalAsset ?? this.isLocalAsset,
      description: description ?? this.description,
      level: level ?? this.level,
    );
  }
}

const List<String> rarityOrder = [
  'All', 'Mythical', 'Limited', 'Legendary', 'Epic', 'Rare', 'Uncommon', 'Common'
];

class PetTab extends StatefulWidget {
  final String userId;
  const PetTab({Key? key, required this.userId}) : super(key: key);

  @override
  State<PetTab> createState() => _PetTabState();
}

class _PetTabState extends State<PetTab> with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  String selectedRarity = 'All';

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showPetActions(BuildContext context, Pet pet) {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.star),
                title: const Text('Set as main companion'),
                onTap: () async {
                  Navigator.of(context).pop();
                  try {
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(widget.userId)
                        .update({'mainPetId': pet.id});
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${pet.name} set as main companion!')),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to set main companion: $e')),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.sell),
                title: const Text('Sell for coins'),
                onTap: () async {
                  Navigator.of(context).pop();
                  bool? confirmed = await showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Sell Pet?'),
                      content: Text('Are you sure you want to sell ${pet.name}? This cannot be undone.'),
                      actions: [
                        TextButton(child: const Text('Cancel'), onPressed: () => Navigator.pop(ctx, false)),
                        ElevatedButton(child: const Text('Sell'), onPressed: () => Navigator.pop(ctx, true)),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    // TODO: sell logic
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${pet.name} sold for coins!')),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('View Details'),
                onTap: () {
                  Navigator.of(context).pop(); // Close popup
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => FullScreenPet(
                        pet: pet,
                        level: pet.level,
                        dateAcquired: '2025-06-08', // Placeholder - update if you store this
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget buildRarityFilter() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.filter_alt, size: 26),
      tooltip: 'Filter by Rarity',
      onSelected: (val) => setState(() => selectedRarity = val),
      itemBuilder: (ctx) => rarityOrder
          .map((rarity) => PopupMenuItem(
        value: rarity,
        child: Text(
          rarity,
          style: TextStyle(
            fontWeight: rarity == selectedRarity ? FontWeight.bold : FontWeight.normal,
            color: rarity == selectedRarity ? Theme.of(ctx).colorScheme.primary : null,
          ),
        ),
      ))
          .toList(),
    );
  }

  Future<List<Pet>> _fetchOwnedPets(String userId) async {
    final invSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('inventory')
        .doc('pets')
        .collection('pet_inventory')
        .get();
    if (invSnapshot.docs.isEmpty) return [];

    List<Pet> ownedPets = [];
    for (final doc in invSnapshot.docs) {
      final invData = doc.data();
      final petId = invData['petId']?.toString();
      if (petId == null) continue;

      final petDataSnap = await FirebaseFirestore.instance
          .collection('pet_data')
          .doc(petId)
          .get();
      final petData = petDataSnap.data();
      if (petData == null) {
        continue;
      }

      ownedPets.add(Pet.fromMap(
        petData,
        nickname: invData['nickname'],
        level: (invData['level'] is int)
            ? invData['level']
            : int.tryParse(invData['level']?.toString() ?? '') ?? 1,
        ownerId: userId,
      ));
    }
    return ownedPets;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for keep alive!
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 12, 10),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search pets…',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              buildRarityFilter(),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Pet>>(
            future: _fetchOwnedPets(widget.userId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('You don\'t own any pets yet.'));
              }
              final pets = snapshot.data!
                  .where((pet) {
                final matchesRarity = selectedRarity == 'All' || pet.rarity == selectedRarity;
                final query = _searchController.text.toLowerCase().trim();
                final matchesQuery = query.isEmpty ||
                    pet.name.toLowerCase().contains(query) ||
                    (pet.nickname ?? '').toLowerCase().contains(query);
                return matchesRarity && matchesQuery;
              })
                  .toList();

              if (pets.isEmpty) {
                return const Center(child: Text('No pets found.'));
              }

              return GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 1,
                  crossAxisSpacing: 1,
                  childAspectRatio: 0.73,
                ),
                itemCount: pets.length,
                itemBuilder: (ctx, i) {
                  final pet = pets[i];
                  return GestureDetector(
                    onTap: () => _showPetActions(context, pet),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundImage: pet.isLocalAsset
                                ? AssetImage(pet.iconUrl) as ImageProvider
                                : CachedNetworkImageProvider(pet.iconUrl),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            pet.nickname != null && pet.nickname!.isNotEmpty
                                ? pet.nickname!
                                : pet.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
                          ),
                          Text(
                            pet.rarity,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 9,
                              color: rarityColor(pet.rarity),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
