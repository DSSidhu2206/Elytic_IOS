// lib/frontend/screens/pets/pet_stats_and_actions.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class PetStatsAndActions extends StatelessWidget {
  final int level;
  final int xp;
  final int xpToNext;
  final String dateAcquired;
  final bool isOnCooldown;
  final String? cooldownMsg;
  final bool isPetting;
  final bool isGiving;
  final List<Map<String, dynamic>> inventoryItems;
  final VoidCallback onPet;
  final Function(Map<String, dynamic> item, String message) onGiveItem;

  const PetStatsAndActions({
    Key? key,
    required this.level,
    required this.xp,
    required this.xpToNext,
    required this.dateAcquired,
    required this.isOnCooldown,
    required this.cooldownMsg,
    required this.isPetting,
    required this.isGiving,
    required this.inventoryItems,
    required this.onPet,
    required this.onGiveItem,
  }) : super(key: key);

  void _showGiveItemDialog(BuildContext context) {
    if (inventoryItems.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => const AlertDialog(
          title: Text('Give Item'),
          content: Text('You have no items to give.'),
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Give Item'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: inventoryItems.length,
            itemBuilder: (context, idx) {
              final item = inventoryItems[idx];
              return ListTile(
                leading: item['itemAssetUrl'] != null && item['itemAssetUrl'].toString().isNotEmpty
                    ? CachedNetworkImage(
                  imageUrl: item['itemAssetUrl'],
                  width: 32,
                  height: 32,
                  fit: BoxFit.cover,
                  placeholder: (ctx, url) => const SizedBox(
                    width: 32, height: 32,
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  errorWidget: (ctx, e, s) => const Icon(Icons.inventory_2_outlined),
                )
                    : const Icon(Icons.inventory_2_outlined),
                title: Text(item['itemName'] ?? ''),
                subtitle: Text(item['itemRarity'] ?? ''),
                trailing: Text('x${item['count']}'),
                onTap: () {
                  Navigator.pop(context);
                  _showGiftMessageDialog(context, item);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showGiftMessageDialog(BuildContext context, Map<String, dynamic> item) {
    final TextEditingController _msgController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gift Message (optional)'),
        content: TextField(
          controller: _msgController,
          maxLength: 60,
          decoration: const InputDecoration(
            hintText: "Add a message (optional)",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: isGiving
                ? null
                : () {
              Navigator.pop(ctx);
              onGiveItem(item, _msgController.text.trim());
            },
            child: const Text('Send Gift'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 18),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.89),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(26),
          topRight: Radius.circular(26),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'XP: $xp / $xpToNext',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: (xp / xpToNext).clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: Colors.grey[800],
            valueColor: AlwaysStoppedAnimation<Color>(Colors.yellowAccent),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isOnCooldown || isPetting ? null : () => onPet(),
                  icon: const Icon(Icons.pets),
                  label: Text(isOnCooldown
                      ? (cooldownMsg ?? "Come back later!")
                      : (isPetting ? "Petting..." : "Pet! +2 XP")),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                    isOnCooldown ? Colors.grey[800] : Colors.deepPurple,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isGiving || inventoryItems.isEmpty
                      ? null
                      : () => _showGiveItemDialog(context),
                  icon: const Icon(Icons.card_giftcard),
                  label: Text(isGiving ? "Gifting..." : "Give Item"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                    inventoryItems.isEmpty ? Colors.grey[800] : Colors.teal,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Date acquired: $dateAcquired',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 15,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
