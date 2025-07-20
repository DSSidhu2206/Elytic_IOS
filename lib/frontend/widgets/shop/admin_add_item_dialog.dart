// lib/frontend/widgets/shop/admin_add_item_dialog.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart'; // <-- Needed for auth UID
import 'dart:typed_data';

import 'admin_shop_id_service.dart';
import 'admin_shop_image_upload.dart';

Future<void> showAdminAddItemDialog(
    BuildContext context, {
      required String shopTab,
      required int currentUserTier,
    }) async {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _itemId = TextEditingController();
  final TextEditingController _coinPrice = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _docId = TextEditingController();

  // Hold picked files
  Uint8List? iconBytes, cardBytes, assetBytes, borderBytes;
  String? iconFileName, cardFileName, assetFileName, borderFileName;

  String? iconUrl, cardUrl, assetUrl, borderUrl;
  String? iconVersion, cardVersion, assetVersion, borderVersion;

  bool _isSaving = false;
  String rarity = 'Common';

  const rarityOptions = [
    'Common',
    'Uncommon',
    'Rare',
    'Epic',
    'Legendary',
    'Mythical',
    'Limited'
  ];

  Future<void> _initIds() async {
    Map<String, String> ids;
    if (shopTab == "pets") {
      ids = await AdminShopIdService.getNextPetId();
    } else if (shopTab == "avatar_borders") {
      ids = await AdminShopIdService.getNextAvatarBorderId();
    } else {
      ids = await AdminShopIdService.getNextItemId();
    }
    _itemId.text = ids['nextId']!;
    _docId.text = ids['docId']!;
  }

  // Helper to increment version string "1.0.0" -> "1.0.1"
  String bumpVersion(String? old) {
    if (old == null) return "1.0.0";
    final parts = old.split('.');
    if (parts.length != 3) return "1.0.0";
    int patch = int.tryParse(parts[2]) ?? 0;
    return "${parts[0]}.${parts[1]}.${patch + 1}";
  }

  // PATCHED: Uploads to storage and returns URL + version
  Future<Map<String, String>?> uploadToStorage(
      Uint8List fileBytes,
      String folder,
      String originalFileName, {
        String? docId,
        String? shopTab,
        String? versionField,
      }) async {
    final ext = originalFileName.split('.').last;
    final fileName = "${DateTime.now().millisecondsSinceEpoch}_$originalFileName";

    // --- Version bump logic ---
    String version = "1.0.0";
    if (docId != null && shopTab != null) {
      final doc = await FirebaseFirestore.instance
          .collection(shopTab == "pets"
          ? "pet_data"
          : shopTab == "avatar_borders"
          ? "avatar_border_data"
          : "item_data")
          .doc(docId)
          .get();
      if (doc.exists) {
        String? prevVersion;
        if (versionField != null) {
          prevVersion = doc.data()?[versionField];
        } else {
          // Fallback: try all known fields in order
          prevVersion = doc.data()?['borderVersion'] ??
              doc.data()?['iconVersion'] ??
              doc.data()?['cardVersion'] ??
              doc.data()?['assetVersion'] ??
              doc.data()?['version'];
        }
        version = bumpVersion(prevVersion as String?);
      }
    }

    final ref = FirebaseStorage.instance.ref().child('$folder/$fileName');
    final meta = SettableMetadata(
      contentType: ext == 'png'
          ? 'image/png'
          : (ext == 'webp' ? 'image/webp' : 'image/jpeg'),
      cacheControl: 'public,max-age=604800', // 7 days cache
      customMetadata: {'version': version},
    );
    try {
      final uploadTask = await ref.putData(fileBytes, meta);
      final url = await uploadTask.ref.getDownloadURL();
      return {'url': url, 'version': version};
    } catch (_) {
      return null;
    }
  }

  await showDialog(
    context: context,
    builder: (ctx) {
      return FutureBuilder(
        future: _initIds(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AlertDialog(
              content: SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              ),
            );
          }
          return StatefulBuilder(
            builder: (context, setState) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: Text('Add New '
                  '${shopTab == "pets" ? "Pet" : shopTab == "items" ? "Item" : "Avatar Border"}'),
              content: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: _name,
                        decoration: const InputDecoration(labelText: 'Name'),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      TextFormField(
                        controller: _itemId,
                        decoration: InputDecoration(
                            labelText: shopTab == "pets"
                                ? "Pet ID"
                                : shopTab == "avatar_borders"
                                ? "Avatar Border ID"
                                : "Item ID"),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                        readOnly: true,
                      ),
                      DropdownButtonFormField<String>(
                        value: rarity,
                        items: rarityOptions
                            .map((r) => DropdownMenuItem(
                          value: r,
                          child: Text(r),
                        ))
                            .toList(),
                        onChanged: (val) => setState(() {
                          rarity = val ?? 'Common';
                        }),
                        decoration: const InputDecoration(labelText: 'Rarity'),
                      ),
                      TextFormField(
                        controller: _coinPrice,
                        decoration: const InputDecoration(labelText: 'Coin Price'),
                        keyboardType: TextInputType.number,
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      if (shopTab == "pets") ...[
                        const SizedBox(height: 12),
                        AdminShopImageUpload(
                          label: "icon",
                          onPicked: (bytes, fileName) {
                            iconBytes = bytes;
                            iconFileName = fileName;
                          },
                        ),
                        AdminShopImageUpload(
                          label: "card",
                          onPicked: (bytes, fileName) {
                            cardBytes = bytes;
                            cardFileName = fileName;
                          },
                        ),
                      ] else if (shopTab == "items") ...[
                        const SizedBox(height: 12),
                        AdminShopImageUpload(
                          label: "asset",
                          onPicked: (bytes, fileName) {
                            assetBytes = bytes;
                            assetFileName = fileName;
                          },
                        ),
                      ] else if (shopTab == "avatar_borders") ...[
                        const SizedBox(height: 12),
                        AdminShopImageUpload(
                          label: "Avatar Border Image (PNG, round/square, transparent)",
                          onPicked: (bytes, fileName) {
                            borderBytes = bytes;
                            borderFileName = fileName;
                          },
                        ),
                      ],
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _description,
                        decoration: const InputDecoration(labelText: 'Description (optional)'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _docId,
                        decoration: InputDecoration(
                          labelText: shopTab == "pets"
                              ? "Pet Data Document Name"
                              : shopTab == "avatar_borders"
                              ? "Avatar Border Data Document Name"
                              : "Item Data Document Name",
                          helperText: shopTab == "pets"
                              ? 'Used in pet_data collection'
                              : shopTab == "avatar_borders"
                              ? 'Used in avatar_border_data collection'
                              : 'Used in item_data collection',
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                        readOnly: true,
                      ),
                      const SizedBox(height: 10),
                      if (_isSaving) const CircularProgressIndicator(),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _isSaving
                      ? null
                      : () async {
                    if (!_formKey.currentState!.validate()) return;
                    if (shopTab == "pets" && (iconBytes == null || cardBytes == null)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please pick both icon and card images.')));
                      return;
                    }
                    if (shopTab == "items" && assetBytes == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please pick the asset image.')));
                      return;
                    }
                    if (shopTab == "avatar_borders" && borderBytes == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please pick the avatar border image.')));
                      return;
                    }

                    setState(() => _isSaving = true);

                    try {
                      final uid = FirebaseAuth.instance.currentUser?.uid;
                      if (uid != null) {
                        final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
                        final tier = userDoc.data()?['tier'];
                      }

                      final docId = _docId.text.trim();

                      // Uploads — PATCHED to return url+version and auto-increment version
                      if (shopTab == "pets") {
                        final iconRes = await uploadToStorage(
                          iconBytes!, "pets", iconFileName!,
                          docId: docId,
                          shopTab: shopTab,
                          versionField: "iconVersion",
                        );
                        final cardRes = await uploadToStorage(
                          cardBytes!, "pets", cardFileName!,
                          docId: docId,
                          shopTab: shopTab,
                          versionField: "cardVersion",
                        );
                        iconUrl = iconRes?['url'];
                        iconVersion = iconRes?['version'];
                        cardUrl = cardRes?['url'];
                        cardVersion = cardRes?['version'];
                        if (iconUrl == null || cardUrl == null) {
                          throw Exception("Image upload failed");
                        }
                      }
                      if (shopTab == "items") {
                        final assetRes = await uploadToStorage(
                          assetBytes!, "items", assetFileName!,
                          docId: docId,
                          shopTab: shopTab,
                          versionField: "assetVersion",
                        );
                        assetUrl = assetRes?['url'];
                        assetVersion = assetRes?['version'];
                        if (assetUrl == null) {
                          throw Exception("Asset upload failed");
                        }
                      }
                      if (shopTab == "avatar_borders") {
                        final borderRes = await uploadToStorage(
                          borderBytes!, "avatar_borders", borderFileName!,
                          docId: docId,
                          shopTab: shopTab,
                          versionField: "borderVersion",
                        );
                        borderUrl = borderRes?['url'];
                        borderVersion = borderRes?['version'];
                        if (borderUrl == null) {
                          throw Exception("Avatar border upload failed");
                        }
                      }

                      /// --- Shop Catalog Write ---
                      final shopData = {
                        "name": _name.text.trim(),
                        "id": _itemId.text.trim(),
                        "coinPrice": int.tryParse(_coinPrice.text.trim()) ?? 0,
                        "rarity": rarity,
                        "description": _description.text.trim(),
                        "createdAt": FieldValue.serverTimestamp(),
                        if (shopTab == "pets") ...{
                          "iconUrl": iconUrl,
                          "iconVersion": iconVersion,
                          "cardUrl": cardUrl,
                          "cardVersion": cardVersion,
                          "id": _itemId.text.trim(),
                        },
                        if (shopTab == "items") ...{
                          "assetUrl": assetUrl,
                          "assetVersion": assetVersion,
                          "item_id": _itemId.text.trim(),
                        },
                        if (shopTab == "avatar_borders") ...{
                          "avatar_border_id": _itemId.text.trim(),
                          "image_url": borderUrl,
                          "borderVersion": borderVersion,
                        },
                      };

                      await FirebaseFirestore.instance
                          .collection('shop')
                          .doc(shopTab)
                          .collection('items')
                          .doc('${shopData['id']}')
                          .set(shopData);

                      /// --- Global Catalog Write ---
                      final dataDoc = {
                        "name": _name.text.trim(),
                        "rarity": rarity,
                        "description": _description.text.trim(),
                        if (shopTab == "pets") ...{
                          "iconUrl": iconUrl,
                          "iconVersion": iconVersion,
                          "cardUrl": cardUrl,
                          "cardVersion": cardVersion,
                          "id": _itemId.text.trim(),
                        },
                        if (shopTab == "items") ...{
                          "assetUrl": assetUrl,
                          "assetVersion": assetVersion,
                          "item_id": _itemId.text.trim(),
                        },
                        if (shopTab == "avatar_borders") ...{
                          "avatar_border_id": _itemId.text.trim(),
                          "image_url": borderUrl,
                          "borderVersion": borderVersion,
                          "display_order": int.tryParse(_itemId.text.replaceAll(RegExp(r'[^0-9]'), "")) ?? 999,
                        },
                      };
                      await FirebaseFirestore.instance
                          .collection(shopTab == "pets"
                          ? "pet_data"
                          : shopTab == "avatar_borders"
                          ? "avatar_border_data"
                          : "item_data")
                          .doc(docId)
                          .set(dataDoc);

                      Navigator.of(ctx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${shopData['name']} added!')),
                      );
                    } catch (e) {
                      setState(() => _isSaving = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed: $e')),
                      );
                    }
                  },
                  child: const Text('Add'),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
