// lib/frontend/widgets/shop/shop_grid_card.dart

import 'package:flutter/material.dart';
import 'package:elytic/frontend/utils/rarity_color.dart';
import 'package:elytic/frontend/helpers/avatar_helper.dart'; // <-- Use the helper

class ShopGridCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback? onTap;
  final Widget? footer;

  const ShopGridCard({
    Key? key,
    required this.data,
    this.onTap,
    this.footer,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final String name = data['name'] ?? "Unknown";
    final String rarity = data['rarity'] ?? "Common";
    final String iconUrl = data['iconUrl'] ?? "";

    final Color rarityBg = rarityColor(rarity);
    final bool isDefaultRarity = rarityBg == Colors.grey;
    final Color cardColor = isDefaultRarity ? Colors.white : rarityBg;

    Widget imageWidget = Image(
      image: getAvatarImageProvider(iconUrl),
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (context, error, stack) => Container(
        color: Colors.grey[300],
        child: const Icon(Icons.pets, size: 48),
      ),
    );

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Card(
        elevation: 2,
        color: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min, // let content shrink
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
              child: AspectRatio(
                aspectRatio: 1,
                child: imageWidget,
              ),
            ),
            const SizedBox(height: 6), // Reduced for less overflow
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Center(
                child: Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            // --- PATCH: Remove Rarity from the card! ---
            // (Do NOT show the rarity text here anymore)
            if (footer != null) ...[
              const SizedBox(height: 4),
              Flexible(child: footer!), // Will shrink if needed
            ],
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}
