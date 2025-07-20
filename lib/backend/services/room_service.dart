// lib/frontend/services/room_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class RoomService {
  static final RoomService _instance = RoomService._internal();
  factory RoomService() => _instance;
  RoomService._internal();

  // SUPERESET: One source of truth for all categories (update this as needed!)
  static const List<String> allRoomCategories = [
    'General',
    'Teen',
    'Love & Dating',
    'Pokemon',
    'America',
    'UK',
    'Spanish',
    'India',
    'Anime & Manga',
    'Tech & Gadgets',
    'Gaming Hub',
    'Music Lounge',
    'Movies & TV',
    'Sports Zone',
    'Education & Learning',
    'Furry Fandom',
    'Health & Wellness',
    'Travel & Adventure',
    'Foodies',
    'Fashion & Style',
    'Art & Design',
    'Photography',
    'Memes & Humor',
    'Science & Space',
    'Finance & Crypto',
    'History & Culture',
    'Fitness & Yoga',
    'Self Improvement',
    'K-Pop',
    'Movies & Netflix',
    // Add VIP or extra rooms here if needed!
  ];

  Map<String, String?> _backgroundCache = {};
  static Future<void>? _loadFuture;
  static List<String> _loadedRoomNames = [];

  /// Loads backgrounds for all rooms in [roomNames] (default: all categories), only once per session.
  /// Calling again returns the same future unless you clearCache().
  Future<void> loadAllRoomBackgrounds([List<String>? roomNames]) {
    final names = roomNames ?? allRoomCategories;
    if (_loadFuture != null && _loadedRoomNames.toSet().containsAll(names)) {
      return _loadFuture!;
    }
    _loadedRoomNames = names;
    _loadFuture = _doLoad(names);
    return _loadFuture!;
  }

  Future<void> _doLoad(List<String> roomNames) async {
    final Map<String, String?> result = {};
    const int batchSize = 30; // Firestore max whereIn is 30
    for (int i = 0; i < roomNames.length; i += batchSize) {
      final batch = roomNames.sublist(
        i,
        (i + batchSize > roomNames.length) ? roomNames.length : i + batchSize,
      );

      final querySnapshot = await FirebaseFirestore.instance
          .collection('room_backgrounds')
          .where(FieldPath.documentId, whereIn: batch)
          .get();

      for (final doc in querySnapshot.docs) {
        result[doc.id] = doc.data()['imageUrl'] as String?;
      }

      // For any room IDs not found in Firestore, set null explicitly
      for (final id in batch) {
        if (!result.containsKey(id)) {
          result[id] = null;
        }
      }
    }
    _backgroundCache = result;
  }

  String? getRoomBackground(String roomName) {
    return _backgroundCache[roomName];
  }

  /// Checks if all (or [roomNames]) have backgrounds loaded in cache
  bool isLoadedFor([List<String>? roomNames]) {
    final names = roomNames ?? allRoomCategories;
    return _backgroundCache.length == names.length &&
        names.every(_backgroundCache.containsKey);
  }

  void clearCache() {
    _backgroundCache.clear();
    _loadFuture = null;
    _loadedRoomNames = [];
  }
}
