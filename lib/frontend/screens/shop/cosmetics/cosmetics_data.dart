// lib/frontend/screens/shop/cosmetics/cosmetics_data.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class CosmeticItem {
  final String id;
  final String name;
  final String imagePath; // Always a network URL or asset path
  final int priceCoins;
  final double priceIAP;
  final String category; // avatar_borders, chat_bubbles, etc.
  final String? codeId;  // For code-based items like chat bubbles (e.g., chat_bubble_id)

  const CosmeticItem({
    required this.id,
    required this.name,
    required this.imagePath,
    required this.priceCoins,
    required this.priceIAP,
    required this.category,
    this.codeId,
  });

  // BULLETPROOF: Always use the right image field by category
  factory CosmeticItem.fromDoc(DocumentSnapshot doc, String category) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    String imagePath = '';
    String? codeId;

    if (category == 'avatar_borders') {
      imagePath = data['image_url'] ?? '';
    } else if (category == 'chat_bubbles') {
      codeId = data['chat_bubble_id'] ?? doc.id;
      imagePath = ''; // handled by bubble preview
    } else {
      imagePath = data['assetUrl'] ?? data['iconUrl'] ?? data['imagePath'] ?? data['imageUrl'] ?? '';
    }

    return CosmeticItem(
      id: doc.id,
      name: data['name'] ?? '',
      imagePath: imagePath,
      priceCoins: data['priceCoins'] ?? 0,
      priceIAP: (data['priceIAP'] is int)
          ? (data['priceIAP'] as int).toDouble()
          : (data['priceIAP'] ?? 0.0),
      category: category,
      codeId: codeId,
    );
  }
}

class CosmeticsData {
  // Firestore collection names for each cosmetic category
  static String _collectionForCategory(String category) {
    switch (category) {
      case 'avatar_borders':
        return 'avatar_border_data';
      case 'chat_bubbles':
        return 'chat_bubble_data';
      case 'badges':
        return 'badge_data';
      case 'profiles':
        return 'profile_data';
      default:
        return 'cosmetics';
    }
  }

  // Streams only the items for the given IDs (rotation), batched (10 at a time)
  static Stream<List<CosmeticItem>> streamItemsByIds({
    required String category,
    required List<String> ids,
  }) async* {
    if (ids.isEmpty) {
      yield [];
      return;
    }
    List<CosmeticItem> items = [];
    for (var i = 0; i < ids.length; i += 10) {
      final batch = ids.sublist(i, i + 10 > ids.length ? ids.length : i + 10);
      final snapshot = await FirebaseFirestore.instance
          .collection(_collectionForCategory(category))
          .where(FieldPath.documentId, whereIn: batch)
          .get();
      items.addAll(snapshot.docs.map((doc) => CosmeticItem.fromDoc(doc, category)));
    }
    yield items;
  }
}
