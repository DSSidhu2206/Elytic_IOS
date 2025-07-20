// lib/frontend/utils/rarity_color.dart

import 'package:flutter/material.dart';

Color rarityColor(String rarity) {
  switch (rarity.toLowerCase()) {
    case 'mythical':
      return const Color(0xFFFF5722); // Bright orange-red
    case 'legendary':
      return const Color(0xFFFFD700); // Gold
    case 'epic':
      return Colors.purple;
    case 'rare':
      return Colors.green;
    case 'uncommon':
      return const Color(0xFFC0C0C0); // Silver
    case 'common':
      return const Color(0xFFCD7F32); // Bronze
    case 'limited':
      return Colors.black;
    default:
      return Colors.grey;
  }
}
