// lib/frontend/widgets/full_screen_pet.dart

import 'package:flutter/material.dart';
import 'package:elytic/frontend/widgets/pets/pet_tab.dart';
import 'package:elytic/frontend/widgets/common/legendary_badge.dart';
import 'package:cached_network_image/cached_network_image.dart';

class FullScreenPet extends StatelessWidget {
  final Pet pet;
  final int level;
  final String dateAcquired;
  final VoidCallback? onClose;

  // Accepts an optional appbarDecoration for theming (can be null, uses black)
  final BoxDecoration? appbarDecoration;

  const FullScreenPet({
    Key? key,
    required this.pet,
    required this.level,
    required this.dateAcquired,
    this.onClose,
    this.appbarDecoration,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final String rarity = pet.rarity.toString().toLowerCase();
    final Widget petImage = pet.isLocalAsset
        ? Image.asset(
      pet.cardUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (ctx, error, stack) =>
      const Center(child: Icon(Icons.pets, size: 100, color: Colors.grey)),
    )
        : CachedNetworkImage(
      imageUrl: pet.cardUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorWidget: (ctx, error, stack) =>
      const Center(child: Icon(Icons.pets, size: 100, color: Colors.grey)),
      placeholder: (ctx, url) =>
      const Center(child: CircularProgressIndicator()),
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Pet image layer (fills the space between the top bar and bottom panel)
          Positioned(
            top: 100,
            left: 0,
            right: 0,
            bottom: MediaQuery.of(context).size.height * 0.30,
            child: petImage,
          ),
          // AppBar: black by default, or themed by external config later
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: appbarDecoration ?? const BoxDecoration(color: Colors.black),
              padding: const EdgeInsets.only(
                top: 34, left: 0, right: 0, bottom: 14,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Legendary Badge or placeholder
                  SizedBox(
                    width: 64,
                    height: 54,
                    child: (rarity == "legendary")
                        ? Padding(
                      padding: const EdgeInsets.only(left: 12.0),
                      child: LegendaryBadge(size: 44),
                    )
                        : const SizedBox.shrink(),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          pet.name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 29,
                            color: Colors.yellow,
                            shadows: [
                              Shadow(color: Colors.black87, blurRadius: 8),
                            ],
                          ),
                        ),
                        Text(
                          'Lvl $level',
                          style: const TextStyle(
                            color: Colors.orangeAccent,
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                            shadows: [
                              Shadow(color: Colors.black87, blurRadius: 8),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Close button (right)
                  Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 34),
                      onPressed: onClose ?? () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Description section (bottom)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 18),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.91),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Pet Description
                  Text(
                    pet.description,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Date acquired: $dateAcquired',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
