// lib/frontend/widgets/profile/user_main_pet_avatar.dart

import 'package:flutter/material.dart';
import 'package:elytic/frontend/utils/rarity_color.dart'; // <-- PATCH: import

class UserMainPetAvatar extends StatelessWidget {
  final ImageProvider? imageProvider;
  final int? level;
  final int? receivedItemsCount;
  final String? petRarity; // PATCH: pet rarity
  final VoidCallback? onPetTap;
  final VoidCallback? onReceivedItemsTap;
  final bool isOwnProfile;
  final double size; // main avatar size
  final double badgeSize; // size of the side circles

  const UserMainPetAvatar({
    Key? key,
    this.imageProvider,
    this.level,
    this.receivedItemsCount,
    this.petRarity, // PATCH
    this.onPetTap,
    this.onReceivedItemsTap,
    this.isOwnProfile = false,
    this.size = 90,
    this.badgeSize = 70,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // PATCH: Use rarity color (fallback to purple/teal if not given)
    final Color sideColor = petRarity != null
        ? rarityColor(petRarity!)
        : Colors.deepPurple.shade600;

    final Color rightColor = petRarity != null
        ? rarityColor(petRarity!)
        : Colors.teal.shade500;

    // Always show level badge
    final levelBadge = Container(
      width: badgeSize,
      height: badgeSize,
      decoration: BoxDecoration(
        color: sideColor,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 4,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        'Lv ${level ?? "?"}',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 20,
          shadows: [
            Shadow(
              blurRadius: 2,
              color: Colors.black26,
              offset: Offset(0, 1),
            ),
          ],
        ),
      ),
    );

    // PATCH: Received items badge (never clickable)
    final receivedBadge = Container(
      width: badgeSize,
      height: badgeSize,
      decoration: BoxDecoration(
        color: rightColor,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 4,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inventory_2, color: Colors.white, size: 22),
          Text(
            '${receivedItemsCount ?? 0}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ],
      ),
    );

    // The pet avatar
    final avatar = GestureDetector(
      onTap: onPetTap,
      child: CircleAvatar(
        radius: size / 2,
        backgroundImage: imageProvider,
        backgroundColor: Colors.white,
        child: imageProvider == null
            ? const Icon(Icons.pets, size: 36, color: Colors.grey)
            : null,
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size + badgeSize * 2,
          height: size,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Level badge (left)
              Positioned(
                left: 0,
                top: (size - badgeSize) / 2,
                child: levelBadge,
              ),
              // Received badge (right, never clickable)
              Positioned(
                right: 0,
                top: (size - badgeSize) / 2,
                child: receivedBadge,
              ),
              // Pet avatar (center and in front)
              Positioned(
                left: badgeSize,
                child: avatar,
              ),
            ],
          ),
        ),
        // Button below, only for own profile
        if (isOwnProfile && onReceivedItemsTap != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.inventory_2_rounded),
              label: const Text("Set active item"),
              onPressed: onReceivedItemsTap,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(180, 40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                backgroundColor: Colors.teal.shade600,
                foregroundColor: Colors.white,
              ),
            ),
          ),
      ],
    );
  }
}
