// lib/frontend/widgets/pets/pet_gift_item_dialog.dart

import 'package:flutter/material.dart';

class PetGiftItemDialog extends StatelessWidget {
  final List<Map<String, dynamic>> ownedItems; // Each: {itemName, quantity}
  final void Function(String itemName) onGift;

  const PetGiftItemDialog({
    Key? key,
    required this.ownedItems,
    required this.onGift,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Gift an Item'),
      content: SizedBox(
        width: double.maxFinite,
        child: ownedItems.isEmpty
            ? const Text('No items available.')
            : ListView.builder(
          shrinkWrap: true,
          itemCount: ownedItems.length,
          itemBuilder: (context, index) {
            final item = ownedItems[index];
            return ListTile(
              leading: Image.asset('assets/items/item_1.png', width: 32, height: 32),
              title: Text(item['itemName']),
              subtitle: Text('x${item['quantity']}'),
              onTap: () => onGift(item['itemName']),
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
    );
  }
}
