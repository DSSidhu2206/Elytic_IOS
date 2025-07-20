// lib/backend/services/pet_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class PetDisplayInfo {
  final String petId;
  final String name;
  final String? nickname;
  final String iconUrl;
  final String cardUrl;
  final String rarity;
  final bool isPremium;
  final bool isLocalAsset;
  final String description;
  final int level;
  final String ownerId;

  PetDisplayInfo({
    required this.petId,
    required this.name,
    this.nickname,
    required this.iconUrl,
    required this.cardUrl,
    required this.rarity,
    required this.isPremium,
    required this.isLocalAsset,
    required this.description,
    required this.level,
    required this.ownerId,
  });

  factory PetDisplayInfo.fromUserAndMaster(
      String petId,
      Map<String, dynamic>? userData,
      Map<String, dynamic>? masterData, {
        required String ownerId,
      }) {
    return PetDisplayInfo(
      petId: petId,
      name: masterData?['name'] as String? ?? 'Unknown',
      nickname: userData?['nickname'] as String?,
      iconUrl: masterData?['iconUrl'] as String? ?? '',
      cardUrl: masterData?['cardUrl'] as String? ?? '',
      rarity: masterData?['rarity'] as String? ?? 'common',
      isPremium: masterData?['isPremium'] as bool? ?? false,
      isLocalAsset: masterData?['isLocalAsset'] as bool? ?? false,
      description: masterData?['description'] as String? ?? '',
      level: _parseLevel(userData?['level']),
      ownerId: ownerId,
    );
  }

  static int _parseLevel(dynamic levelValue) {
    if (levelValue == null) return 1;
    if (levelValue is int) return levelValue;
    return int.tryParse(levelValue.toString()) ?? 1;
  }
}

class PetService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static final Map<String, PetDisplayInfo?> _mainPetCache = {};
  static final Map<String, Map<String, dynamic>?> _masterPetCache = {};

  /// Fetches a user's main pet, merged with master pet data.
  /// Throws on unexpected errors.
  static Future<PetDisplayInfo?> fetchMainPet(String userId, {bool forceRefresh = false}) async {
    if (!forceRefresh && _mainPetCache.containsKey(userId)) {
      return _mainPetCache[userId];
    }

    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data();

      if (userData == null || userData['mainPetId'] == null) {
        _mainPetCache[userId] = null;
        return null;
      }

      final mainPetIdRaw = userData['mainPetId'].toString();

      final userPetDocRef =
      _firestore.collection('users').doc(userId).collection('pets').doc(mainPetIdRaw);
      final masterPetDocRef = _firestore.collection('pet_data').doc(mainPetIdRaw);

      // Fetch user pet doc and master pet doc in parallel
      final docs = await Future.wait([userPetDocRef.get(), masterPetDocRef.get()]);

      final userPetData = docs[0].data();
      Map<String, dynamic>? masterPetData;

      if (!forceRefresh && _masterPetCache.containsKey(mainPetIdRaw)) {
        masterPetData = _masterPetCache[mainPetIdRaw];
      } else {
        masterPetData = docs[1].data();
        _masterPetCache[mainPetIdRaw] = masterPetData;
      }

      if (userPetData == null && masterPetData == null) {
        _mainPetCache[userId] = null;
        return null;
      }

      final petInfo = PetDisplayInfo.fromUserAndMaster(
        mainPetIdRaw,
        userPetData,
        masterPetData,
        ownerId: userId,
      );

      _mainPetCache[userId] = petInfo;
      return petInfo;
    } catch (e) {
      // Optionally log or rethrow for debugging
      rethrow;
    }
  }

  /// Clears cached main pet for userId.
  static void invalidatePetCache(String userId) => _mainPetCache.remove(userId);

  /// Clears cached master pet data for petId.
  static void invalidateMasterPetCache(String petId) => _masterPetCache.remove(petId);

  /// Clears all caches, e.g., on logout.
  static void clearAllCaches() {
    _mainPetCache.clear();
    _masterPetCache.clear();
  }
}
