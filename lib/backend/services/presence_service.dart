// lib/backend/services/presence_service.dart

import 'dart:async';
import 'dart:math';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_service.dart';

class PresenceService {
  static final Random _rng = Random();
  static final FirebaseDatabase _database = FirebaseDatabase.instance;

  static final Map<String, StreamSubscription<DatabaseEvent>> _connectionSubscriptions = {};
  static final Map<String, Timer> _heartbeatTimers = {};

  // ---- Caching section ----
  static final Map<String, String> _borderUrlCache = {};    // userId -> borderUrl
  static final Map<String, String> _activeItemIdCache = {}; // userId -> activeItemId
  static final Map<String, String> _avatarUrlCache = {};    // userId -> avatarUrl

  /// Instantly update avatar border cache after user changes border
  static void setCachedBorderUrl(String userId, String borderUrl) {
    _borderUrlCache[userId] = borderUrl;
  }

  /// Instantly update active item cache after user changes item
  static void setCachedActiveItemId(String userId, String itemId) {
    _activeItemIdCache[userId] = itemId;
  }

  /// Instantly update avatarUrl cache after user changes avatar
  static void setCachedAvatarUrl(String userId, String avatarUrl) {
    _avatarUrlCache[userId] = avatarUrl;
  }

  /// Fetches user's currently equipped avatar border URL (with cache)
  /// Now fetches from user doc directly (not settings/cosmetics)
  static Future<String> fetchUserAvatarBorderUrl(String userId) async {
    if (_borderUrlCache.containsKey(userId)) {
      return _borderUrlCache[userId]!;
    }
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();
    final data = doc.data();
    String url = '';
    if (data != null) {
      url = data['selectedAvatarBorderUrl'] as String? ?? '';
      // Fallback if url not found: resolve from borderId
      if (url.isEmpty && data['selectedAvatarBorderId'] is String) {
        final borderId = data['selectedAvatarBorderId'] as String;
        if (borderId.isNotEmpty) {
          url = await _getBorderUrlFromBorderId(borderId);
        }
      }
    }
    _borderUrlCache[userId] = url;
    return url;
  }

  /// Helper to fetch border URL by borderId from avatar_border_data
  static final Map<String, String> _borderIdUrlCache = {}; // borderId -> url
  static Future<String> _getBorderUrlFromBorderId(String borderId) async {
    if (_borderIdUrlCache.containsKey(borderId)) {
      return _borderIdUrlCache[borderId]!;
    }
    final doc = await FirebaseFirestore.instance
        .collection('avatar_border_data')
        .doc(borderId)
        .get();
    final url = doc.data()?['image_url'] as String? ?? '';
    _borderIdUrlCache[borderId] = url;
    return url;
  }

  /// Fetches user's currently equipped main active item ID (with cache)
  /// PATCH: Always returns the latest equipped, non-expired item
  static Future<String> fetchUserActiveItemId(String userId) async {
    final now = DateTime.now();

    // Always get all docs, sort by grantedAt (descending), filter non-expired
    final activeItemsSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('activeItems')
        .orderBy('grantedAt', descending: true)
        .get();

    String id = '';
    for (final doc in activeItemsSnap.docs) {
      final data = doc.data();
      final expiresAt = data['expiresAt'];
      DateTime? expires;
      if (expiresAt is Timestamp) {
        expires = expiresAt.toDate();
      } else if (expiresAt is DateTime) {
        expires = expiresAt;
      }
      // If expiresAt not present, treat as expired and skip
      if (expires != null && expires.isAfter(now)) {
        id = doc.id;
        break;
      }
    }

    // PATCH: If no valid item, clear cache!
    if (id.isEmpty) {
      _activeItemIdCache.remove(userId);
    } else {
      _activeItemIdCache[userId] = id;
    }
    return id;
  }

  /// Always fetch latest avatarUrl from Firestore (and cache)
  static Future<String> fetchUserAvatarUrl(String userId) async {
    if (_avatarUrlCache.containsKey(userId)) {
      return _avatarUrlCache[userId]!;
    }
    final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    final url = doc.data()?['avatarUrl'] as String? ?? '';
    _avatarUrlCache[userId] = url;
    return url;
  }

  /// Call this EVERY TIME a user joins a room,
  /// now *automatically* fetches border & active item & avatar if not passed.
  static Future<void> setupRoomPresence({
    required String userId,
    required String roomId,
    required String userName,
    String? avatarUrl,      // avatarUrl now optional; always fetch if not passed
    int? tier,
    String? userAvatarBorderUrl,
    String? activeItemId,
    double? x,
    double? y,
  }) async {
    String resolvedAvatarUrl = avatarUrl ?? await fetchUserAvatarUrl(userId);
    String borderUrl = (userAvatarBorderUrl == null || userAvatarBorderUrl.isEmpty)
        ? await fetchUserAvatarBorderUrl(userId)
        : userAvatarBorderUrl;
    String mainActiveItemId = activeItemId ?? await fetchUserActiveItemId(userId);

    final double resolvedX = x ?? (0.1 + _rng.nextDouble() * 0.3);
    final double resolvedY = y ?? (0.1 + _rng.nextDouble() * 0.3);
    final userPresenceRef = _database.ref('presence/$roomId/$userId');
    final connectedRef = _database.ref('.info/connected');

    final presenceData = {
      'userName': userName,
      'avatarUrl': resolvedAvatarUrl,
      'userAvatarBorderUrl': borderUrl,
      'activeItemId': mainActiveItemId,
      'tier': tier ?? 0,
      'x': resolvedX,
      'y': resolvedY,
    };

    final isOnline = {
      ...presenceData,
      'state': 'online',
      'last_changed': ServerValue.timestamp,
    };

    final isOffline = {
      ...presenceData,
      'state': 'offline',
      'last_changed': ServerValue.timestamp,
    };

    // Cancel any existing listeners for this user
    await _connectionSubscriptions[userId]?.cancel();

    final sub = connectedRef.onValue.listen((event) async {
      final connected = event.snapshot.value as bool? ?? false;
      if (connected) {
        await userPresenceRef.onDisconnect().set(isOffline);
        await userPresenceRef.set(isOnline);
      }
    });

    _connectionSubscriptions[userId] = sub;
    _startHeartbeat(userId, roomId);
  }

  /// Remove user's presence when leaving room
  static Future<void> clearRoomPresence(String userId, String roomId) async {
    await _database.ref('presence/$roomId/$userId').remove();
    await _connectionSubscriptions[userId]?.cancel();
    _connectionSubscriptions.remove(userId);
    stopHeartbeat(userId);
  }

  /// Update user position in lounge area, always using latest border/item/avatar from cache if possible.
  static Future<void> updateUserPosition({
    required String userId,
    required String roomId,
    required String userName,
    String? avatarUrl, // avatarUrl now optional!
    required int tier,
    required double x,
    required double y,
    String? userAvatarBorderUrl,
    String? activeItemId,
  }) async {
    final borderUrl = userAvatarBorderUrl ?? _borderUrlCache[userId] ?? '';
    final mainActiveItemId = activeItemId ?? _activeItemIdCache[userId] ?? '';
    final resolvedAvatarUrl = avatarUrl ?? _avatarUrlCache[userId] ?? '';

    final userPresenceRef = _database.ref('presence/$roomId/$userId');

    final updateData = {
      'x': x,
      'y': y,
      'userName': userName,
      'avatarUrl': resolvedAvatarUrl,
      'tier': tier,
      'userAvatarBorderUrl': borderUrl,
      'activeItemId': mainActiveItemId,
      'last_changed': ServerValue.timestamp,
    };

    await userPresenceRef.update(updateData);
  }

  /// Listen to presence updates for a room
  static Stream<DatabaseEvent> presenceStream(String roomId) {
    return _database.ref('presence/$roomId').onValue;
  }

  /// Internal: Keeps presence alive with periodic timestamp updates
  static void _startHeartbeat(String userId, String roomId) {
    stopHeartbeat(userId);
    final ref = _database.ref('presence/$roomId/$userId');

    final timer = Timer.periodic(const Duration(seconds: 20), (_) {
      ref.update({'last_changed': ServerValue.timestamp});
    });

    _heartbeatTimers[userId] = timer;
  }

  /// Stops the heartbeat timer for a user
  static void stopHeartbeat(String userId) {
    _heartbeatTimers[userId]?.cancel();
    _heartbeatTimers.remove(userId);
  }
}
