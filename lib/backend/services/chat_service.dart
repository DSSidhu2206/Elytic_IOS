// lib/frontend/services/chat_service.dart

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart'; // for NetworkImage/ImageConfiguration
import 'package:shared_preferences/shared_preferences.dart';

class ChatService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;
  static final _rtdb = FirebaseDatabase.instance;

  static const _roomsCol = 'rooms';

  // Keys for device caches
  static const _stickerMetaCacheKey = 'sticker_pack_metadata_cache';
  static const _badgeMetaCacheKey   = 'badge_metadata_cache';

  // In-memory caches
  static List<Map<String, dynamic>>? _stickerPackMemoryCache;
  static List<Map<String, dynamic>>? _badgeMemoryCache;

  // Other existing caches...
  static final Map<String, dynamic> _roomCache               = {};
  static final Map<String, String?> _lastRoomCache           = {};
  static final Map<String, bool> _roomFullCache              = {};
  static final Map<String, DateTime> _roomFullCacheTimestamps = {};

  // ------------------------------------------
  //      STICKER PACK METADATA CACHING
  // ------------------------------------------
  static Future<List<Map<String, dynamic>>> getStickerPackMetadata() async {
    if (_stickerPackMemoryCache != null) {
      return _stickerPackMemoryCache!;
    }

    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_stickerMetaCacheKey);
    if (cached != null) {
      try {
        final List<dynamic> decoded = json.decode(cached);
        final data = decoded
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _stickerPackMemoryCache = data;
        return data;
      } catch (_) {
      }
    }

    final snap = await _firestore.collection('sticker_packs').get();
    final data = snap.docs.map((d) {
      final raw = _fixFirestoreTimestamps(d.data());
      if (raw is Map) {
        return Map<String, dynamic>.from(raw.map((k, v) => MapEntry(k.toString(), v)));
      } else {
        return <String, dynamic>{};
      }
    }).toList();

    _stickerPackMemoryCache = data;
    await prefs.setString(_stickerMetaCacheKey, json.encode(data));
    return data;
  }

  static Future<void> refreshStickerPackMetadataCache() async {
    final snap = await _firestore.collection('sticker_packs').get();
    final data = snap.docs.map((d) {
      final raw = _fixFirestoreTimestamps(d.data());
      if (raw is Map) {
        return Map<String, dynamic>.from(raw.map((k, v) => MapEntry(k.toString(), v)));
      } else {
        return <String, dynamic>{};
      }
    }).toList();

    final prefs = await SharedPreferences.getInstance();
    _stickerPackMemoryCache = data;
    await prefs.setString(_stickerMetaCacheKey, json.encode(data));
  }

  // ------------------------------------------
  //       BADGE METADATA CACHING (PATCHED)
  // ------------------------------------------
  /// Batch‐fetch all badges once, then cache in‐RAM + on‐device.
  static Future<List<Map<String, dynamic>>> getBadgeMetadata() async {
    if (_badgeMemoryCache != null) {
      return _badgeMemoryCache!;
    }

    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_badgeMetaCacheKey);
    if (cached != null) {
      try {
        final List<dynamic> decoded = json.decode(cached);
        final data = decoded
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        // PATCH: If any badge is missing 'id', or empty id, force refresh from Firestore
        final missingId = data.any((b) => b['id'] == null || b['id'].toString().isEmpty);
        if (!missingId) {
          _badgeMemoryCache = data;
          return data;
        }
        // else fall through to fetch from Firestore
      } catch (_) {
        // fall through
      }
    }

    // Always patch in 'id' from Firestore doc.id:
    final snap = await _firestore.collection('badges').get();
    final data = snap.docs.map((d) {
      final raw = _fixFirestoreTimestamps(d.data());
      Map<String, dynamic> map;
      if (raw is Map) {
        map = Map<String, dynamic>.from(raw.map((k, v) => MapEntry(k.toString(), v)));
      } else {
        map = <String, dynamic>{};
      }
      map['id'] = d.id; // always add doc id
      return map;
    }).toList();

    _badgeMemoryCache = data;
    await prefs.setString(_badgeMetaCacheKey, json.encode(data));
    return data;
  }

  /// Force‐refresh badges from Firestore, updating both caches.
  static Future<void> refreshBadgeMetadataCache() async {
    final snap = await _firestore.collection('badges').get();
    final data = snap.docs.map((d) {
      final raw = _fixFirestoreTimestamps(d.data());
      Map<String, dynamic> map;
      if (raw is Map) {
        map = Map<String, dynamic>.from(raw.map((k, v) => MapEntry(k.toString(), v)));
      } else {
        map = <String, dynamic>{};
      }
      map['id'] = d.id; // always add doc id
      return map;
    }).toList();

    final prefs = await SharedPreferences.getInstance();
    _badgeMemoryCache = data;
    await prefs.setString(_badgeMetaCacheKey, json.encode(data));
  }

  // ------------------------------------------
  //   Firestore → JSON safety helper
  // ------------------------------------------
  static dynamic _fixFirestoreTimestamps(dynamic value) {
    if (value is Map) {
      return value.map((k, v) => MapEntry(k, _fixFirestoreTimestamps(v)));
    } else if (value is List) {
      return value.map(_fixFirestoreTimestamps).toList();
    } else if (value is Timestamp) {
      return value.toDate().toIso8601String();
    } else {
      return value;
    }
  }

  // ------------------------------------------
  //      EXISTING ROOM / PRESENCE LOGIC
  // ------------------------------------------
  static Future<bool> isRoomFullCached(String roomId) async {
    final now = DateTime.now();
    if (_roomFullCache.containsKey(roomId) &&
        _roomFullCacheTimestamps.containsKey(roomId) &&
        now.difference(_roomFullCacheTimestamps[roomId]!) <
            const Duration(seconds: 15)) {
      return _roomFullCache[roomId]!;
    }
    final full = await isRoomFull(roomId);
    _roomFullCache[roomId] = full;
    _roomFullCacheTimestamps[roomId] = now;
    return full;
  }

  static Future<bool> isRoomFull(String? roomId) async {
    if (roomId == null || roomId.trim().isEmpty) return true;

    int capacity = 50;
    if (_roomCache.containsKey(roomId)) {
      capacity = _roomCache[roomId]['capacity'] ?? 50;
    } else {
      final snap = await _firestore.collection(_roomsCol).doc(roomId).get();
      if (!snap.exists) return false;
      final data = snap.data()!;
      _roomCache[roomId] = data;
      capacity = data['capacity'] ?? 50;
    }

    final presSnap = await _rtdb.ref('presence/$roomId').get();
    final presMap = presSnap.value as Map?;
    final count = presMap?.length ?? 0;
    return count >= capacity;
  }

  static Future<void> joinRoom(String roomId) async {
    if (roomId.trim().isEmpty) {
      throw Exception('Cannot join empty room');
    }
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Not authenticated');
    await _firestore
        .collection('users')
        .doc(uid)
        .set({'lastActiveRoom': roomId}, SetOptions(merge: true));
    _lastRoomCache[uid] = roomId;
  }

  static Future<void> leaveRoom(String roomId) async {
    // No-op
  }

  static Future<void> createRoomWithDisplayName(
      String roomId, Map<String, dynamic> roomData) async {
    final pretty = prettifyRoomId(roomId);
    final merged = {...roomData, 'displayName': pretty};
    await _firestore.collection(_roomsCol).doc(roomId).set(merged);
    _roomCache[roomId] = merged;
  }

  static String prettifyRoomId(String roomId) {
    var s = roomId
        .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}')
        .replaceAllMapped(RegExp(r'([A-Za-z])(\d+)'), (m) => '${m[1]} ${m[2]}')
        .replaceAll('_', ' ');
    return s
        .split(' ')
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ')
        .trim();
  }

  static Future<String?> getLastActiveRoom(String userId) async {
    if (_lastRoomCache.containsKey(userId)) return _lastRoomCache[userId];
    final doc = await _firestore.collection('users').doc(userId).get();
    final room = doc.data()?['lastActiveRoom'] as String?;
    _lastRoomCache[userId] = room;
    return room;
  }

  static Future<Map<String, Map<String, dynamic>>> fetchMultipleRooms(
      List<String> roomIds) async {
    const maxBatch = 30;
    final res = <String, Map<String, dynamic>>{};
    final toFetch = <String>[];
    for (var id in roomIds) {
      if (_roomCache.containsKey(id)) {
        res[id] = _roomCache[id];
      } else {
        toFetch.add(id);
      }
    }
    for (var i = 0; i < toFetch.length; i += maxBatch) {
      final batch = toFetch.sublist(
        i,
        i + maxBatch > toFetch.length ? toFetch.length : i + maxBatch,
      );
      final snap = await _firestore
          .collection(_roomsCol)
          .where(FieldPath.documentId, whereIn: batch)
          .get();
      for (var d in snap.docs) {
        res[d.id] = d.data();
        _roomCache[d.id] = d.data();
      }
    }
    for (var id in roomIds) {
      res.putIfAbsent(id, () => {});
    }
    return res;
  }

  static Future<Map<String, String?>> fetchMultipleUsersLastActiveRoom(
      List<String> userIds) async {
    const maxBatch = 30;
    final res = <String, String?>{};
    final toFetch = <String>[];
    for (var id in userIds) {
      if (_lastRoomCache.containsKey(id)) {
        res[id] = _lastRoomCache[id];
      } else {
        toFetch.add(id);
      }
    }
    for (var i = 0; i < toFetch.length; i += maxBatch) {
      final batch = toFetch.sublist(
        i,
        i + maxBatch > toFetch.length ? toFetch.length : i + maxBatch,
      );
      final snap = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: batch)
          .get();
      for (var d in snap.docs) {
        final room = d.data()['lastActiveRoom'] as String?;
        res[d.id] = room;
        _lastRoomCache[d.id] = room;
      }
    }
    for (var id in userIds) {
      res.putIfAbsent(id, () => null);
    }
    return res;
  }

  /// Optional: pre‐warm sticker & badge images into Flutter’s in‐memory cache
  static Future<void> cacheAllAssetsLocally() async {
    // stickers
    final sp = await getStickerPackMetadata();
    for (var pack in sp) {
      final cover = pack['coverUrl'] as String?;
      if (cover?.startsWith('http') ?? false) {
        await _downloadToDiskCache(cover!);
      }
      for (var s in (pack['stickers'] as List)) {
        final url = s['url'] as String?;
        if (url?.startsWith('http') ?? false) {
          await _downloadToDiskCache(url!);
        }
      }
    }
    // badges
    final bd = await getBadgeMetadata();
    for (var b in bd) {
      final icon = b['iconUrl'] as String?;
      if (icon?.startsWith('http') ?? false) {
        await _downloadToDiskCache(icon!);
      }
    }
  }

  static Future<void> _downloadToDiskCache(String imageUrl) async {
    try {
      final img = NetworkImage(imageUrl);
      await img.obtainKey(const ImageConfiguration());
    } catch (e) {
    }
  }

  // -------------- ADDED HELPER BELOW -----------------
  /// Returns the URL for a given stickerId using the in-memory sticker pack cache.
  static String? getCachedStickerUrl(String? stickerId) {
    if (stickerId == null || _stickerPackMemoryCache == null) return null;
    for (final pack in _stickerPackMemoryCache!) {
      if (pack.containsKey('stickers') && pack['stickers'] is List) {
        for (final sticker in (pack['stickers'] as List)) {
          if (sticker is Map && sticker['id'] == stickerId) {
            return sticker['url'] as String?;
          }
        }
      }
    }
    return null;
  }
}
