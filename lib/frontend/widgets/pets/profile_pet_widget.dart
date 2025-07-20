// lib/frontend/widgets/pets/profile_pet_widget.dart

import 'package:flutter/material.dart';

class ProfilePetWidget extends StatelessWidget {
  final String petName;
  final String petNickname;
  final int level;
  final bool isOwner;
  final VoidCallback onPet;
  final VoidCallback onCustomize;
  final VoidCallback onSwitch;
  final VoidCallback onHide;
  final bool canPet;
  final Duration cooldownRemaining;

  const ProfilePetWidget({
    Key? key,
    required this.petName,
    required this.petNickname,
    required this.level,
    required this.isOwner,
    required this.onPet,
    required this.onCustomize,
    required this.onSwitch,
    required this.onHide,
    required this.canPet,
    required this.cooldownRemaining,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(12),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/pets/pet_1.png',
              height: 100,
              width: 100,
            ),
            const SizedBox(height: 12),
            Text(petName,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            if (petNickname.isNotEmpty)
              Text('($petNickname)',
                  style: Theme.of(context).textTheme.bodyMedium),
            Text('Level $level'),
            const SizedBox(height: 10),
            if (isOwner) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: onCustomize,
                    icon: const Icon(Icons.brush),
                    label: const Text('Customize'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: onSwitch,
                    icon: const Icon(Icons.sync_alt),
                    label: const Text('Switch'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: onHide,
                    icon: const Icon(Icons.visibility_off),
                    label: const Text('Hide'),
                  ),
                ],
              ),
            ] else ...[
              ElevatedButton.icon(
                onPressed: canPet ? onPet : null,
                icon: const Icon(Icons.pets),
                label: Text(canPet
                    ? 'Pet this pet'
                    : 'Pet again in ${cooldownRemaining.inHours}h'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
