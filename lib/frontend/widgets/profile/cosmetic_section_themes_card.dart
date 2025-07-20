// lib/frontend/widgets/profile/cosmetic_section_themes_card.dart

import 'package:flutter/material.dart';

class CosmeticSectionThemesCard extends StatelessWidget {
  const CosmeticSectionThemesCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      color: Colors.grey[200],
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const Icon(Icons.palette, color: Colors.grey),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "Premium App Themes",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.grey),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                "Coming soon",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            )
          ],
        ),
      ),
    );
  }
}
