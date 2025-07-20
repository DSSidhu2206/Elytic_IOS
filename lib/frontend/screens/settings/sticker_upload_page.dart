import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

class StickerUploadPage extends StatefulWidget {
  const StickerUploadPage({Key? key}) : super(key: key);

  @override
  _StickerUploadPageState createState() => _StickerUploadPageState();
}

class _StickerUploadPageState extends State<StickerUploadPage> {
  final _packNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _coinPriceController = TextEditingController();
  String _selectedRarity = 'Common';

  final List<File> _selectedStickerFiles = [];
  final List<TextEditingController> _stickerNameControllers = [];
  File? _coverImage;

  bool _isUploading = false;

  Future<void> _pickStickers() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage();

    if (picked.isNotEmpty) {
      final newFiles = picked.map((e) => File(e.path)).toList();

      if (_selectedStickerFiles.length + newFiles.length > 30) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Max 30 stickers allowed.')),
        );
        return;
      }

      setState(() {
        _selectedStickerFiles.addAll(newFiles);
        _stickerNameControllers.addAll(List.generate(
          newFiles.length,
              (_) => TextEditingController(),
        ));
      });
    }
  }

  Future<void> _pickCoverImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _coverImage = File(picked.path);
      });
    }
  }

  Future<void> _uploadStickerPack() async {
    if (_packNameController.text.trim().isEmpty ||
        _coinPriceController.text.trim().isEmpty ||
        _selectedStickerFiles.isEmpty ||
        _coverImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Fill all required fields and upload a cover image.")),
      );
      return;
    }

    setState(() => _isUploading = true);

    final packId = const Uuid().v4();
    final storage = FirebaseStorage.instance;
    final firestore = FirebaseFirestore.instance;
    final List<Map<String, dynamic>> uploadedStickers = [];

    // Upload cover image
    final coverRef = storage.ref().child('stickers/$packId/cover.png');
    await coverRef.putFile(_coverImage!);
    final coverUrl = await coverRef.getDownloadURL();

    // Upload individual stickers
    for (int i = 0; i < _selectedStickerFiles.length; i++) {
      final file = _selectedStickerFiles[i];
      final stickerId = 'sticker_$i';
      final stickerName = _stickerNameControllers[i].text.trim().isEmpty
          ? 'Sticker ${i + 1}'
          : _stickerNameControllers[i].text.trim();

      final ref = storage.ref().child('stickers/$packId/$stickerId.png');
      await ref.putFile(file);
      final url = await ref.getDownloadURL();

      uploadedStickers.add({
        'id': stickerId,
        'name': stickerName,
        'url': url,
      });
    }

    await firestore.collection('sticker_packs').doc(packId).set({
      'id': packId,
      'name': _packNameController.text.trim(),
      'description': _descriptionController.text.trim(),
      'coinPrice': int.tryParse(_coinPriceController.text.trim()) ?? 0,
      'rarity': _selectedRarity,
      'stickers': uploadedStickers,
      'coverUrl': coverUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });

    setState(() {
      _selectedStickerFiles.clear();
      _stickerNameControllers.clear();
      _packNameController.clear();
      _descriptionController.clear();
      _coinPriceController.clear();
      _selectedRarity = 'Common';
      _coverImage = null;
      _isUploading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sticker Pack Uploaded!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Sticker Upload Page")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _packNameController,
              decoration: const InputDecoration(labelText: 'Sticker Pack Name'),
            ),
            TextField(
              controller: _coinPriceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Coin Price'),
            ),
            DropdownButton<String>(
              value: _selectedRarity,
              items: ['Common','Uncommon', 'Rare', 'Epic', 'Legendary', 'Mythic', 'Limited']
                  .map((rarity) => DropdownMenuItem(
                value: rarity,
                child: Text(rarity),
              ))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedRarity = val);
              },
            ),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _pickCoverImage,
              icon: const Icon(Icons.image),
              label: const Text("Upload Cover Image"),
            ),
            if (_coverImage != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Image.file(_coverImage!, height: 100),
              ),
            ElevatedButton.icon(
              onPressed: _pickStickers,
              icon: const Icon(Icons.collections),
              label: const Text("Add Stickers (max 30)"),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _selectedStickerFiles.isEmpty
                  ? const Center(child: Text('No stickers selected.'))
                  : GridView.builder(
                itemCount: _selectedStickerFiles.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.8,
                ),
                itemBuilder: (context, index) {
                  return Column(
                    children: [
                      Stack(
                        children: [
                          AspectRatio(
                            aspectRatio: 1,
                            child: Image.file(_selectedStickerFiles[index], fit: BoxFit.cover),
                          ),
                          Positioned(
                            right: 0,
                            top: 0,
                            child: IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  _selectedStickerFiles.removeAt(index);
                                  _stickerNameControllers.removeAt(index);
                                });
                              },
                            ),
                          )
                        ],
                      ),
                      TextField(
                        controller: _stickerNameControllers[index],
                        decoration: const InputDecoration(
                          hintText: 'Sticker Name',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            _isUploading
                ? const CircularProgressIndicator()
                : ElevatedButton(
              onPressed: _uploadStickerPack,
              child: const Text("Upload Sticker Pack"),
            ),
          ],
        ),
      ),
    );
  }
}
