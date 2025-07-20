// lib/frontend/screens/shop/add_badge_page.dart

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class AddBadgePage extends StatefulWidget {
  const AddBadgePage({Key? key}) : super(key: key);

  @override
  State<AddBadgePage> createState() => _AddBadgePageState();
}

class _AddBadgePageState extends State<AddBadgePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  File? _selectedImage;
  bool _isUploading = false;
  String? _error;

  String? _nextBadgeId;
  bool _loadingBadgeId = true;

  // PATCH: Badge Tier selection
  int _badgeTier = 0;

  @override
  void initState() {
    super.initState();
    _fetchNextBadgeId();
  }

  Future<void> _fetchNextBadgeId() async {
    setState(() {
      _loadingBadgeId = true;
      _nextBadgeId = null;
    });
    final badgeId = await _getNextBadgeId();
    setState(() {
      _nextBadgeId = badgeId;
      _loadingBadgeId = false;
    });
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) {
      setState(() => _selectedImage = File(picked.path));
    }
  }

  /// Fetches the next badge ID in the format B1001, B1002, etc.
  Future<String> _getNextBadgeId() async {
    final query = await FirebaseFirestore.instance
        .collection('badges')
        .orderBy(FieldPath.documentId, descending: true)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      return 'B1001';
    } else {
      final lastId = query.docs.first.id;
      final match = RegExp(r'^B(\d+)$').firstMatch(lastId);
      if (match != null) {
        final num = int.parse(match.group(1)!);
        return 'B${num + 1}';
      } else {
        // fallback if IDs are not as expected
        return 'B1001';
      }
    }
  }

  Future<String?> _uploadBadgeImage(File image, String badgeId) async {
    try {
      final ref = FirebaseStorage.instance
          .ref('badges/${DateTime.now().millisecondsSinceEpoch}_$badgeId.png');
      final uploadTask = await ref.putFile(image);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      setState(() => _error = 'Image upload failed: $e');
      return null;
    }
  }

  Future<void> _submit() async {
    setState(() {
      _isUploading = true;
      _error = null;
    });

    if (!_formKey.currentState!.validate() || _selectedImage == null) {
      setState(() {
        _isUploading = false;
        _error = "Please complete all fields and select an image.";
      });
      return;
    }

    final badgeName = _nameController.text.trim();
    final badgeDesc = _descController.text.trim();
    final badgeTier = _badgeTier;

    try {
      // Always fetch the next ID again at submission time in case of multiple users
      final badgeId = await _getNextBadgeId();
      final imageUrl = await _uploadBadgeImage(_selectedImage!, badgeId);
      if (imageUrl == null) {
        setState(() => _isUploading = false);
        return;
      }

      await FirebaseFirestore.instance.collection('badges').doc(badgeId).set({
        'name': badgeName,
        'description': badgeDesc,
        'iconUrl': imageUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'badgeTier': badgeTier, // PATCH: save badgeTier as a number (0,1,2)
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Badge $badgeId added!'),
              duration: const Duration(seconds: 1)),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() => _error = 'Failed to add badge: $e');
    } finally {
      setState(() => _isUploading = false);
      // Refetch the next ID for another entry (optional UX)
      _fetchNextBadgeId();
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageWidget = _selectedImage == null
        ? Container(
      height: 120,
      width: 120,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[400]!),
      ),
      child: const Center(
        child: Icon(Icons.image, size: 48, color: Colors.grey),
      ),
    )
        : ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.file(_selectedImage!, height: 120, width: 120, fit: BoxFit.cover),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Badge'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Badge ID display
              Align(
                alignment: Alignment.centerLeft,
                child: _loadingBadgeId
                    ? const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 10),
                      Text("Fetching next badge ID...")
                    ],
                  ),
                )
                    : Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    'Next Badge ID: ${_nextBadgeId ?? ""}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              imageWidget,
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _isUploading ? null : _pickImage,
                icon: const Icon(Icons.upload_file),
                label: const Text('Select Icon'),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Badge Name',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                enabled: !_isUploading,
              ),
              const SizedBox(height: 18),

              // PATCH: Badge Tier Dropdown (now 0-5)
              DropdownButtonFormField<int>(
                value: _badgeTier,
                decoration: const InputDecoration(
                  labelText: 'Badge Tier (visibility)',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('Tier 0 (Everyone)')),
                  DropdownMenuItem(value: 1, child: Text('Tier 1+ only')),
                  DropdownMenuItem(value: 2, child: Text('Tier 2+ only')),
                  DropdownMenuItem(value: 3, child: Text('Tier 3+ only')),
                  DropdownMenuItem(value: 4, child: Text('Tier 4+ only')),
                  DropdownMenuItem(value: 5, child: Text('Tier 5+ only')),
                ],
                onChanged: _isUploading ? null : (val) => setState(() => _badgeTier = val ?? 0),
              ),

              const SizedBox(height: 18),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
                enabled: !_isUploading,
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  icon: _isUploading
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                      : const Icon(Icons.save),
                  label: Text(_isUploading ? 'Adding...' : 'Add Badge'),
                  onPressed: _isUploading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
