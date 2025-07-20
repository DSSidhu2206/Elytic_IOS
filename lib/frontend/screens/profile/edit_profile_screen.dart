// lib/frontend/screens/profile/edit_profile_screen.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;

// --- Patch: import avatar helper ---
import 'package:elytic/frontend/helpers/avatar_helper.dart';

// --- Patch: import cached image for background ---
import 'package:cached_network_image/cached_network_image.dart';

// --- Patch: import image cropper ---
import 'package:image_cropper/image_cropper.dart';

// PATCH: Import UserService
import 'package:elytic/backend/services/user_service.dart';

// PATCH: Import Firebase Realtime Database
import 'package:firebase_database/firebase_database.dart';

class EditProfileScreen extends StatefulWidget {
  final String userId;

  // PATCH: Add currentRoomId so we can update presence per room
  final String? currentRoomId;

  const EditProfileScreen({
    Key? key,
    required this.userId,
    this.currentRoomId,
  }) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _bioController = TextEditingController();
  String? _avatarUrlOld;
  String? _avatarUrl; // the value that gets saved in Firestore
  File? _avatarFile; // local picked image, to upload
  int? _tier;
  bool _isLoading = true;
  bool _avatarChanged = false;

  // --- PATCH: For background ---
  String? _backgroundUrl;
  File? _backgroundFile; // for local preview before upload
  bool _backgroundChanged = false;
  bool _backgroundRemoved = false;
  String? _bgError;

  int get _bioMaxLength => (_tier ?? 0) <= 1 ? 200 : 300;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    // PATCH: Use UserService cached fetch
    final userInfo = await UserService.fetchProfileInfo(widget.userId);

    setState(() {
      _bioController.text = userInfo.bio;
      _avatarUrlOld = userInfo.avatarUrl;
      _avatarUrl = _avatarUrlOld;
      _tier = userInfo.tier;

      // PATCH: Load cosmetics.profileBackground
      _backgroundUrl = userInfo.profileBackground;
      _isLoading = false;
      _avatarChanged = false;
      _backgroundChanged = false;
      _backgroundRemoved = false;
      _bgError = null;
    });
  }

  Future<void> _pickAvatar({required ImageSource source}) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() {
        _avatarFile = File(picked.path);
        _avatarChanged = true;
      });
    }
  }

  // PATCH: Background picker with cropping
  Future<void> _pickBackgroundFromGallery() async {
    setState(() {
      _bgError = null;
    });
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked != null) {
      final cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        aspectRatio: const CropAspectRatio(ratioX: 3, ratioY: 2),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Background',
            toolbarColor: Colors.black,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.ratio16x9,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'Crop Background',
            aspectRatioLockEnabled: true,
          ),
        ],
      );
      if (cropped != null) {
        setState(() {
          _backgroundFile = File(cropped.path);
          _backgroundChanged = true;
          _backgroundRemoved = false;
          _bgError = null;
        });
      }
    }
  }

  // PATCH: Remove background
  void _removeBackground() {
    setState(() {
      _backgroundFile = null;
      _backgroundChanged = false;
      _backgroundRemoved = true;
      _bgError = null;
    });
  }

  // Upload to Firebase Storage and get URL
  Future<String?> _uploadBackgroundToStorage(File image) async {
    final ext = path.extension(image.path);
    final filename = "user_backgrounds/${widget.userId}/${widget.userId}$ext";
    final ref = FirebaseStorage.instance.ref().child(filename);
    // --- PATCH: Debugging lines ---
    await ref.putFile(image);
    return await ref.getDownloadURL();
  }

  // Avatar upload
  Future<String?> _uploadAvatarToStorage(File image) async {
    final filename = "user_uploads/${widget.userId}/avatars/avatar_${DateTime.now().millisecondsSinceEpoch}${path.extension(image.path)}";
    final ref = FirebaseStorage.instance.ref().child(filename);
    // --- PATCH: Debugging lines ---
    await ref.putFile(image);
    return await ref.getDownloadURL();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    // PATCH: Use cached user info for old values
    final original = await UserService.fetchProfileInfo(widget.userId);
    final oldBio = original.bio;

    String? avatarUrlNew = _avatarUrlOld;
    String? backgroundUrlNew = _backgroundUrl;
    bool bioChanged = false;
    bool avatarChanged = false;
    bool backgroundChanged = false;
    bool backgroundRemoved = false;

    // Avatar upload
    if (_avatarFile != null) {
      avatarUrlNew = await _uploadAvatarToStorage(_avatarFile!);
      avatarChanged = true;
    }

    // Background upload
    if (_backgroundFile != null) {
      backgroundUrlNew = await _uploadBackgroundToStorage(_backgroundFile!);
      backgroundChanged = true;
      backgroundRemoved = false;
    }

    // Background removal
    if (_backgroundRemoved) {
      backgroundUrlNew = null;
      backgroundRemoved = true;
    }

    final newBio = _bioController.text.trim();
    bioChanged = oldBio.trim() != newBio;

    if (!avatarChanged && !bioChanged && !backgroundChanged && !backgroundRemoved) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No changes to update.')));
      return;
    }

    final Map<String, dynamic> updateData = {};
    if (bioChanged) updateData['bio'] = newBio;
    if (avatarChanged) updateData['avatarPath'] = avatarUrlNew;
    if (backgroundChanged && backgroundUrlNew != null) {
      updateData['cosmetics'] = {'profileBackground': backgroundUrlNew};
    } else if (backgroundRemoved) {
      updateData['cosmetics'] = {'profileBackground': FieldValue.delete()};
      // Cleanup storage if desired
    }

    await FirebaseFirestore.instance.collection('users').doc(widget.userId).set(updateData, SetOptions(merge: true));

    // PATCH: Invalidate user cache so next read is fresh
    UserService.invalidateCache(widget.userId);

    // PATCH: Update presence data in RTDB for every room user is in (usually just current room)
    if (avatarChanged && avatarUrlNew != null && widget.currentRoomId != null) {
      try {
        final presenceRef = FirebaseDatabase.instance.ref('presence/${widget.currentRoomId}/${widget.userId}');
        await presenceRef.update({
          'avatarUrl': avatarUrlNew,
          'last_changed': ServerValue.timestamp,
        });
      } catch (e) {
        // Optionally handle error or log it
      }
    }

    setState(() => _isLoading = false);

    String msg = 'Profile updated';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _tier == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Profile')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Avatar preview
    ImageProvider avatarProvider = _avatarFile != null
        ? FileImage(_avatarFile!)
        : getAvatarImageProvider(_avatarUrl);

    // Background preview
    Widget backgroundPreview;
    if (_backgroundFile != null) {
      backgroundPreview = ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Image.file(
          _backgroundFile!,
          width: double.infinity,
          height: 200,
          fit: BoxFit.cover,
        ),
      );
    } else if (_backgroundUrl != null && _backgroundUrl!.isNotEmpty) {
      backgroundPreview = ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: CachedNetworkImage(
          imageUrl: _backgroundUrl!,
          width: double.infinity,
          height: 200,
          fit: BoxFit.cover,
        ),
      );
    } else {
      backgroundPreview = Container(
        width: double.infinity,
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Center(
          child: Text(
            'No background set',
            style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                backgroundPreview,
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.photo_library),
                      label: const Text("Change Background"),
                      onPressed: _isLoading ? null : _pickBackgroundFromGallery,
                    ),
                    const SizedBox(width: 16),
                    if ((_backgroundUrl != null && _backgroundUrl!.isNotEmpty) || _backgroundFile != null)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.delete_outline),
                        label: const Text("Remove"),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        onPressed: _isLoading ? null : _removeBackground,
                      ),
                  ],
                ),
                if (_bgError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(_bgError!, style: const TextStyle(color: Colors.red)),
                  ),
                const SizedBox(height: 16),
                Center(
                  child: GestureDetector(
                    onTap: () async {
                      final choice = await showModalBottomSheet<String>(
                        context: context,
                        builder: (ctx) => SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                leading: const Icon(Icons.photo_camera),
                                title: const Text('Take a Photo'),
                                onTap: () => Navigator.pop(ctx, 'camera'),
                              ),
                              ListTile(
                                leading: const Icon(Icons.photo_library),
                                title: const Text('Pick from Gallery'),
                                onTap: () => Navigator.pop(ctx, 'gallery'),
                              ),
                            ],
                          ),
                        ),
                      );
                      if (choice == 'camera') {
                        await _pickAvatar(source: ImageSource.camera);
                      } else if (choice == 'gallery') {
                        await _pickAvatar(source: ImageSource.gallery);
                      }
                    },
                    child: Stack(
                      children: [
                        CircleAvatar(radius: 60, backgroundImage: avatarProvider),
                        Positioned(
                          bottom: 0,
                          right: 4,
                          child: CircleAvatar(
                            backgroundColor: Colors.black54,
                            radius: 18,
                            child: const Icon(Icons.camera_alt, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _bioController,
                  decoration: InputDecoration(
                    labelText: 'Bio',
                    border: const OutlineInputBorder(),
                    counterText: '${_bioController.text.length}/$_bioMaxLength',
                  ),
                  maxLines: 5,
                  maxLength: _bioMaxLength,
                  onChanged: (_) => setState(() {}),
                  validator: (v) => (v ?? '').length <= _bioMaxLength ? null : 'Max $_bioMaxLength characters',
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _save,
                    child: _isLoading
                        ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                        : const Text('Save'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
