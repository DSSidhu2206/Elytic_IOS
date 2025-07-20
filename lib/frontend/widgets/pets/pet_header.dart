// lib/frontend/screens/pets/pet_header.dart

import 'package:flutter/material.dart';
import 'pet_tab.dart'; // Your pet model
import 'package:elytic/frontend/widgets/common/legendary_badge.dart';

class PetHeader extends StatelessWidget {
  final Pet pet;
  final int level;
  final VoidCallback onClose;

  const PetHeader({
    Key? key,
    required this.pet,
    required this.level,
    required this.onClose,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final String rarity = pet.rarity.toString().toLowerCase();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      color: Colors.black.withOpacity(0.75),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (rarity == "legendary") LegendaryBadge(size: 38),
          if (rarity != "legendary") const SizedBox(width: 38),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pet.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.yellow,
                    fontSize: 21,
                  ),
                ),
                if (pet.nickname != null && pet.nickname!.isNotEmpty)
                  Text(
                    '(${pet.nickname})',
                    style: const TextStyle(
                      color: Colors.yellowAccent,
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            'Lvl $level',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.orangeAccent,
              fontSize: 17,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onClose,
            child: const Icon(Icons.close, color: Colors.white, size: 28),
          ),
        ],
      ),
    );
  }
}
