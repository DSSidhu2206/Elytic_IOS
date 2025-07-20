// lib/frontend/widgets/pets/pet_customization_dialog.dart

import 'package:flutter/material.dart';

class PetCustomizationDialog extends StatelessWidget {
  final List<String> ownedCosmetics; // Just demo - a list of cosmetic names
  final void Function(String cosmetic) onEquip;
  final String equippedCosmetic;

  const PetCustomizationDialog({
    Key? key,
    required this.ownedCosmetics,
    required this.onEquip,
    required this.equippedCosmetic,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Customize Your Pet'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: ownedCosmetics.length,
          itemBuilder: (context, index) {
            final cosmetic = ownedCosmetics[index];
            return ListTile(
              leading: Icon(Icons.style, color: cosmetic == equippedCosmetic ? Colors.blue : null),
              title: Text(cosmetic),
              trailing: cosmetic == equippedCosmetic ? const Icon(Icons.check) : null,
              onTap: () => onEquip(cosmetic),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
