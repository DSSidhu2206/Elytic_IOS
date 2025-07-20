// lib/frontend/widgets/pets/pet_notification_banner.dart

import 'package:flutter/material.dart';

class PetNotificationBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onTap;

  const PetNotificationBanner({Key? key, required this.message, this.onTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialBanner(
      content: Text(message),
      leading: const Icon(Icons.pets, color: Colors.orange),
      backgroundColor: Colors.yellow[100],
      actions: [
        if (onTap != null)
          TextButton(
            child: const Text('View'),
            onPressed: onTap,
          ),
      ],
    );
  }
}
