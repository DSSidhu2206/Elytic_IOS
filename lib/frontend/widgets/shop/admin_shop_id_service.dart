// lib/frontend/widgets/shop/admin_shop_id_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class AdminShopIdService {
  /// Returns next petId and document id as strings: {nextId, docId}
  static Future<Map<String, String>> getNextPetId() async {
    final q = await FirebaseFirestore.instance
        .collection("pet_data")
        .get();
    int maxNum = 1000;
    for (var doc in q.docs) {
      final idVal = doc.data()['id'] ?? doc.id;
      int? numVal;
      if (idVal is int) numVal = idVal;
      if (idVal is String && int.tryParse(idVal) != null) numVal = int.parse(idVal);
      if (numVal != null && numVal > maxNum) {
        maxNum = numVal;
      }
    }
    final nextId = (maxNum + 1).toString();
    return {'nextId': nextId, 'docId': nextId};
  }

  /// Returns next item_id and document id as strings: {nextId, docId}
  static Future<Map<String, String>> getNextItemId() async {
    final q = await FirebaseFirestore.instance
        .collection("item_data")
        .get();

    int maxNum = 1000;
    for (var doc in q.docs) {
      final itemId = doc.data()['item_id'] ?? doc.id;
      if (itemId is String && itemId.startsWith('I')) {
        final numPart = int.tryParse(itemId.substring(1));
        if (numPart != null && numPart > maxNum) {
          maxNum = numPart;
        }
      }
    }
    final nextNum = maxNum + 1;
    final nextId = "I$nextNum";
    return {'nextId': nextId, 'docId': nextId};
  }

  /// Returns next avatar_border_id and doc id as strings: {nextId, docId}
  static Future<Map<String, String>> getNextAvatarBorderId() async {
    final q = await FirebaseFirestore.instance
        .collection("avatar_border_data")
        .get();

    int maxNum = 1000;
    for (var doc in q.docs) {
      // Accepts both old and new formats just in case
      final borderId = doc.data()['avatar_border_id'] ?? doc.id;
      if (borderId is String && borderId.startsWith('AB')) {
        final numPart = int.tryParse(borderId.substring(2));
        if (numPart != null && numPart > maxNum) {
          maxNum = numPart;
        }
      }
    }
    final nextNum = maxNum + 1;
    final nextId = "AB$nextNum";
    return {'nextId': nextId, 'docId': nextId};
  }
}
