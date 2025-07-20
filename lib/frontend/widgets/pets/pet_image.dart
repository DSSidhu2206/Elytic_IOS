// lib/frontend/screens/pets/pet_image.dart

import 'package:flutter/material.dart';
import 'pet_tab.dart'; // Your pet model
import 'package:cached_network_image/cached_network_image.dart';

class PetImage extends StatelessWidget {
  final Pet pet;
  const PetImage({Key? key, required this.pet}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.black,
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(18),
        ),
        child: pet.isLocalAsset
            ? Image.asset(
          pet.cardUrl,
          fit: BoxFit.cover,
          errorBuilder: (ctx, error, stack) =>
          const Center(child: Icon(Icons.pets, size: 100, color: Colors.grey)),
        )
            : CachedNetworkImage(
          imageUrl: pet.cardUrl,
          fit: BoxFit.cover,
          errorWidget: (ctx, error, stack) =>
          const Center(child: Icon(Icons.pets, size: 100, color: Colors.grey)),
          placeholder: (ctx, url) =>
          const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}
