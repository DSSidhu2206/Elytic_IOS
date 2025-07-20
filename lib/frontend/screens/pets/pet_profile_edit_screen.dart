// lib/frontend/screens/pets/pet_profile_edit_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PetProfileEditScreen extends StatefulWidget {
  final String userId;
  final String petId;
  final String petName;
  final String petAvatar;
  final String? nickname;

  const PetProfileEditScreen({
    Key? key,
    required this.userId,
    required this.petId,
    required this.petName,
    required this.petAvatar,
    this.nickname,
  }) : super(key: key);

  @override
  State<PetProfileEditScreen> createState() => _PetProfileEditScreenState();
}

class _PetProfileEditScreenState extends State<PetProfileEditScreen> {
  late TextEditingController _nicknameController;
  String? _petAvatar;
  bool _isSaving = false;

  final List<String> petAvatars = [
    'assets/pets/pet_1_icon.png',
    'assets/pets/pet_2_icon.jpg',
    'assets/pets/pet_3_icon.jpg',
    'assets/pets/pet_4_icon.jpg',
    'assets/pets/pet_5_icon.jpg',
    'assets/pets/pet_6_icon.jpg',
    'assets/pets/pet_7_icon.jpg',
    'assets/pets/pet_8_icon.jpg',
    'assets/pets/pet_9_icon.jpg',
    'assets/pets/pet_10_icon.jpg'
  ];

  @override
  void initState() {
    super.initState();
    _petAvatar = widget.petAvatar;
    _nicknameController = TextEditingController(text: widget.nickname ?? '');
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final nickname = _nicknameController.text.trim();
    setState(() => _isSaving = true);
    try {
      // Save to global pet_data collection
      await FirebaseFirestore.instance
          .collection('pet_data')
          .doc(widget.petId)
          .update({
        'nickname': nickname,
        'iconUrl': _petAvatar,
      });

      Navigator.of(context).pop({'nickname': nickname, 'petAvatar': _petAvatar});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pet updated!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update: $e')),
      );
    }
    setState(() => _isSaving = false);
  }

  Widget _buildAvatarSelector() {
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: petAvatars.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, idx) {
          final avatar = petAvatars[idx];
          return GestureDetector(
            onTap: () => setState(() => _petAvatar = avatar),
            child: CircleAvatar(
              radius: 45,
              backgroundColor: _petAvatar == avatar ? Colors.blue[200] : Colors.grey[300],
              child: CircleAvatar(
                radius: 40,
                backgroundImage: AssetImage(avatar),
                child: _petAvatar == avatar
                    ? const Icon(Icons.check_circle, color: Colors.blue, size: 34)
                    : null,
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Pet'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
            const SizedBox(height: 10),
            // Avatar selector only, NO extra edit icon near avatar
            _buildAvatarSelector(),
            const SizedBox(height: 30),
            TextField(
              controller: _nicknameController,
              maxLength: 20,
              decoration: InputDecoration(
                labelText: 'Pet Nickname',
                hintText: 'Enter a cute nickname',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: Text(_isSaving ? 'Saving...' : 'Save'),
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
