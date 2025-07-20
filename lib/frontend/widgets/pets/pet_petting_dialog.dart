// lib/frontend/widgets/pets/pet_petting_dialog.dart

import 'package:flutter/material.dart';

class PetPettingDialog extends StatelessWidget {
  final String petName;
  final String petNickname;
  final VoidCallback onConfirm;

  const PetPettingDialog({
    Key? key,
    required this.petName,
    required this.petNickname,
    required this.onConfirm,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pet this pet?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/pets/pet_1.png', height: 64),
          const SizedBox(height: 8),
          Text('$petName ${petNickname.isNotEmpty ? "($petNickname)" : ""}'),
          const SizedBox(height: 8),
          const Text('Petting will increase affection and may grant a reward!'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: onConfirm,
          child: const Text('Pet'),
        ),
      ],
    );
  }
}
