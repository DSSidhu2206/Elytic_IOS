// lib/backend/services/user_service.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
// <<<<< PATCH: Import Firebase Storage >>>>>
import 'package:firebase_storage/firebase_storage.dart';

import '../../frontend/models/cosmetic_meta.dart';

class UserDisplayInfo {
  final String userId;
  final String username;
  final String avatarUrl;
  final String currentBorderUrl;
  final String currentBubbleId;
  final int tier;
  final String bio;
  final String? profileBackground;
  final bool readReceiptsEnabled;
  final int? receivedItemsCount;

  // NEW CACHE FIELDS ADDED HERE
  final int? coins;
  final int? usernameChangeTokensBought;
  final int? usernameChangeTokensOwned;
  final int? likeCount;
  final String? badgeUrl;

  UserDisplayInfo({
    required this.userId,
    required this.username,
    required this.avatarUrl,
    required this.currentBorderUrl,
    required this.currentBubbleId,
    required this.tier,
    required this.bio,
    required this.profileBackground,
    required this.readReceiptsEnabled,
    this.receivedItemsCount,
    this.coins,
    this.usernameChangeTokensBought,
    this.usernameChangeTokensOwned,
    this.likeCount,
    this.badgeUrl,
  });

  factory UserDisplayInfo.fromMap(
      String userId,
      Map<String, dynamic>? data, {
        int? receivedItemsCount,
        int? coins,
        int? usernameChangeTokensBought,
        int? usernameChangeTokensOwned,
        int? likeCount,
        String? badgeUrl,
      }) {
    String avatar =
        data?['avatarUrl'] ?? data?['avatarPath'] ?? 'assets/avatars/avatar_1.png';
    String bio = data?['bio'] ?? '';
    String? profileBackground;
    if (data?['cosmetics'] is Map &&
        data?['cosmetics']?['profileBackground'] != null) {
      profileBackground = data?['cosmetics']?['profileBackground'];
    } else {
      profileBackground = null;
    }
    bool readReceipts = true;
    if (data?['settings'] is Map &&
        data?['settings']?['readReceipts'] != null) {
      readReceipts = data?['settings']?['readReceipts'] == true;
    } else if (data?['readReceipts'] != null) {
      readReceipts = data?['readReceipts'] == true;
    }

    final currentBorderUrl = data?['selectedAvatarBorderUrl'] ?? '';

    final currentBubbleId = data?['selectedChatBubbleId'] ?? '';

    return UserDisplayInfo(
      userId: userId,
      username: data?['username'] ?? 'Unknown',
      avatarUrl: avatar,
      currentBorderUrl: currentBorderUrl,
      currentBubbleId: currentBubbleId,
      tier: data?['tier'] ?? 0,
      bio: bio,
      profileBackground: profileBackground,
      readReceiptsEnabled: readReceipts,
      receivedItemsCount: receivedItemsCount ?? data?['receivedItemsCount'],
      coins: coins ?? (data?['coins'] is int ? data!['coins'] as int : null),
      usernameChangeTokensBought: usernameChangeTokensBought ??
          (data?['usernameChangeTokensBought'] is int
              ? data!['usernameChangeTokensBought'] as int
              : null),
      usernameChangeTokensOwned: usernameChangeTokensOwned ??
          (data?['username_change_tokens'] is int
              ? data!['username_change_tokens'] as int
              : null),
      likeCount: likeCount ?? (data?['likes'] is int ? data!['likes'] as int : null),
      badgeUrl: badgeUrl ?? (data?['mainBadgeUrl'] as String?),
    );
  }
}

// -- PATCH: Model for Received Item including expiresAt & expired --
class ReceivedItemInfo {
  final String id;
  final String itemId;
  final DateTime? expiresAt;
  final bool expired;
  final Map<String, dynamic> data;

  ReceivedItemInfo({
    required this.id,
    required this.itemId,
    this.expiresAt,
    required this.expired,
    required this.data,
  });

  factory ReceivedItemInfo.fromMap(String id, Map<String, dynamic>? data) {
    DateTime? expiresAt;
    bool expired = false;
    if (data != null && data['expiresAt'] != null) {
      var raw = data['expiresAt'];
      if (raw is Timestamp) {
        expiresAt = raw.toDate();
      } else if (raw is int) {
        expiresAt = DateTime.fromMillisecondsSinceEpoch(
            raw > 1000000000000 ? raw : raw * 1000);
      } else if (raw is String) {
        expiresAt = DateTime.tryParse(raw);
      }
      if (expiresAt != null) {
        expired = expiresAt.isBefore(DateTime.now());
      }
    }
    return ReceivedItemInfo(
      id: id,
      itemId: data?['itemId'] ?? '',
      expiresAt: expiresAt,
      expired: expired,
      data: data ?? {},
    );
  }
}

// --- PATCH: Model for VIP Room ---
class VIPRoomInfo {
  final String id;
  final String name;
  final String description;
  final String creator;
  final int members;
  final bool inviteOnly;
  final Map<String, dynamic> data;

  VIPRoomInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.creator,
    required this.members,
    required this.inviteOnly,
    required this.data,
  });

  factory VIPRoomInfo.fromMap(String id, Map<String, dynamic>? data) {
    return VIPRoomInfo(
      id: id,
      name: data?['name'] ?? '',
      description: data?['description'] ?? '',
      creator: data?['creator'] ?? '',
      members: (data?['members'] != null && data?['members'] is int)
          ? data!['members']
          : (data?['members'] as num?)?.toInt() ?? 0,
      inviteOnly: data?['inviteOnly'] == true,
      data: data ?? {},
    );
  }
}

class UserService {
  static final _firestore = FirebaseFirestore.instance;
  static final _functions = FirebaseFunctions.instance;
  static final _auth = FirebaseAuth.instance;
  // <<<<< PATCH: Firebase Storage instance >>>>>
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  // --- Caching ---
  static final Map<String, UserDisplayInfo> _profileCache = {};
  static final Map<String, Map<String, dynamic>> _dailyCache = {};
  static final Map<String, int> _likeCountCache = {};
  static Map<String, Map<String, dynamic>>? _allItemsCache;
  static final Map<String, int> _receivedItemsCountCache = {};
  static final Map<String, List<ReceivedItemInfo>> _receivedItemsCache = {};
  static final Map<String, int> _coinsCache = {};
  static final Map<String, int> _tokensBoughtCache = {};
  static final Map<String, int> _tokensOwnedCache = {};
  static final Map<String, String?> _badgeUrlCache = {};
  static final Map<String, Map<String, dynamic>> _userDocCache = {};

  // --- VIP Room Caching ---
  static List<VIPRoomInfo>? _vipRoomsCache;
  static DateTime? _vipRoomsCacheTime;
  static const Duration _vipRoomsCacheDuration = Duration(seconds: 30);

  // --- NEW PATCH: Stream of visible badges based on user tier ---
  static Stream<List<Map<String, dynamic>>> getVisibleBadgesForCurrentUser() async* {
    final user = _auth.currentUser;
    if (user == null) {
      yield [];
      return;
    }
    final uid = user.uid;
    await for (final userSnap in _firestore.collection('users').doc(uid).snapshots()) {
      final data = userSnap.data();
      final int tier = (data?['tier'] is int) ? data!['tier'] as int : 0;

      final badgeSnap = await _firestore
          .collection('badges')
          .where('badgeTier', isLessThanOrEqualTo: tier)
          .get();

      final badges = badgeSnap.docs
          .map((d) => {
        'id': d.id,
        ...d.data(),
      })
          .toList();
      yield badges;
    }
  }

  // --- Username/Email Check ---
  static Future<bool> checkUsernameAvailable(String username) async {
    try {
      final snap = await FirebaseDatabase.instance
          .ref('username_checks/$username')
          .get();
      return snap.value == null;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> checkEmailAvailable(String email) async {
    try {
      final safeEmail = email.replaceAll('.', ',');
      final snap = await FirebaseDatabase.instance
          .ref('email_checks/$safeEmail')
          .get();
      return snap.value == null;
    } catch (e) {
      return false;
    }
  }

  /// PATCH 1: Set an item as active and remove all others
  static Future<void> setActiveItem(String userId, Map<String, dynamic> itemData) async {
    final colRef = _firestore.collection('users').doc(userId).collection('activeItems');
    final docs = await colRef.get();
    for (final doc in docs.docs) {
      await doc.reference.delete();
    }
    await colRef.doc(itemData['itemId']).set({
      ...itemData,
      'equipped': true,
    });
  }

  /// PATCH 2: Fetch the currently active item ID (only if not expired)
  static Future<String?> fetchAndCleanCurrentActiveItemId(String userId) async {
    final snap = await _firestore
        .collection('users')
        .doc(userId)
        .collection('activeItems')
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final doc = snap.docs.first;
    final data = doc.data();
    final raw = data['expiresAt'];
    DateTime? expires;
    if (raw is Timestamp) expires = raw.toDate();
    else if (raw is int) expires = DateTime.fromMillisecondsSinceEpoch(
        raw > 1000000000000 ? raw : raw * 1000);
    else if (raw is String) expires = DateTime.tryParse(raw);
    if (expires != null && expires.isBefore(DateTime.now())) {
      await doc.reference.delete();
      return null;
    }
    return doc.id;
  }

  /// Fetch *all* received items for a user (with caching)
  static Future<List<ReceivedItemInfo>> fetchReceivedItems(String userId,
      {bool forceRefresh = false}) async {
    if (_receivedItemsCache.containsKey(userId) && !forceRefresh) {
      return _receivedItemsCache[userId]!;
    }
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('receivedItems')
        .get();
    final items = snapshot.docs
        .map((doc) => ReceivedItemInfo.fromMap(doc.id, doc.data()))
        .toList();
    _receivedItemsCache[userId] = items;
    _receivedItemsCountCache[userId] = items.length;
    return items;
  }

  /// Fetch the number of received items for a user (cached, and now optimized!)
  static Future<int> fetchReceivedItemsCount(String userId,
      {bool forceRefresh = false}) async {
    // PATCH: Try to fetch from cache, then from user doc, only fallback to subcollection if field missing
    if (_receivedItemsCountCache.containsKey(userId) && !forceRefresh) {
      return _receivedItemsCountCache[userId]!;
    }
    // Try to read from user doc field, only fallback to subcollection if not present
    final doc = await _firestore.collection('users').doc(userId).get();
    final data = doc.data();
    final countField = data?['receivedItemsCount'];
    if (countField is int) {
      _receivedItemsCountCache[userId] = countField;
      return countField;
    } else {
      // Fallback: read subcollection (expensive, should only happen once if ever)
      final items = await fetchReceivedItems(userId, forceRefresh: forceRefresh);
      _receivedItemsCountCache[userId] = items.length;
      // PATCH: Write count back to user doc for future optimization (optional)
      await doc.reference.set({'receivedItemsCount': items.length}, SetOptions(merge: true));
      return items.length;
    }
  }

  // -- User Display Info (optimized for fewer reads) --
  static Future<UserDisplayInfo> fetchProfileInfo(String userId) async {
    final cached = _profileCache[userId];
    if (cached != null) return cached;

    // PATCH: Read user doc ONCE, get receivedItemsCount from field if present
    final doc = await _firestore.collection('users').doc(userId).get();
    final data = doc.data() ?? {};
    final count = data['receivedItemsCount'] is int
        ? data['receivedItemsCount'] as int
        : 0; // fallback to 0 if not set (should be written by Cloud Function or similar)

    // CACHE coins, tokens, likes, badgeUrl here too
    final coins = data['coins'] is int ? data['coins'] as int : null;
    final tokensBought = data['usernameChangeTokensBought'] is int ? data['usernameChangeTokensBought'] as int : null;
    final tokensOwned = data['username_change_tokens'] is int ? data['username_change_tokens'] as int : null;
    final likes = data['likes'] is int ? data['likes'] as int : null;
    final badgeUrl = data['mainBadgeUrl'] as String?;

    final info = UserDisplayInfo.fromMap(userId, data,
        receivedItemsCount: count,
        coins: coins,
        usernameChangeTokensBought: tokensBought,
        usernameChangeTokensOwned: tokensOwned,
        likeCount: likes,
        badgeUrl: badgeUrl);

    _profileCache[userId] = info;
    return info;
  }

  static Future<UserDisplayInfo> fetchDisplayInfo(String userId) {
    return fetchProfileInfo(userId);
  }

  /// PATCH: Optimize to batch fetch user docs ONLY, never call receivedItemsCount in loop
  static Future<Map<String, UserDisplayInfo>> fetchMultipleProfileInfos(
      List<String> userIds) async {
    const maxBatch = 30;
    Map<String, UserDisplayInfo> result = {};

    List<String> toFetch = [];
    for (var id in userIds) {
      if (_profileCache.containsKey(id)) {
        result[id] = _profileCache[id]!;
      } else {
        toFetch.add(id);
      }
    }

    for (var i = 0; i < toFetch.length; i += maxBatch) {
      final batch = toFetch.sublist(
          i, (i + maxBatch > toFetch.length) ? toFetch.length : i + maxBatch);
      final query = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: batch)
          .get();
      for (var doc in query.docs) {
        final data = doc.data();
        final count = data['receivedItemsCount'] is int
            ? data['receivedItemsCount'] as int
            : 0;

        final coins = data['coins'] is int ? data['coins'] as int : null;
        final tokensBought = data['usernameChangeTokensBought'] is int ? data['usernameChangeTokensBought'] as int : null;
        final tokensOwned = data['username_change_tokens'] is int ? data['username_change_tokens'] as int : null;
        final likes = data['likes'] is int ? data['likes'] as int : null;
        final badgeUrl = data['mainBadgeUrl'] as String?;

        final info = UserDisplayInfo.fromMap(doc.id, data,
            receivedItemsCount: count,
            coins: coins,
            usernameChangeTokensBought: tokensBought,
            usernameChangeTokensOwned: tokensOwned,
            likeCount: likes,
            badgeUrl: badgeUrl);

        result[doc.id] = info;
        _profileCache[doc.id] = info;
      }
    }
    for (var id in userIds) {
      result[id] ??= UserDisplayInfo.fromMap(id, null, receivedItemsCount: 0);
      _profileCache[id] ??= result[id]!;
    }
    return result;
  }

  static void invalidateCache(String userId) {
    _profileCache.remove(userId);
    _dailyCache.remove(userId);
    _likeCountCache.remove(userId);
    _receivedItemsCountCache.remove(userId);
    _receivedItemsCache.remove(userId);
  }

  static Future<bool> ensureUserDocExists(String uid) async {
    final userDocRef = _firestore.collection('users').doc(uid);
    final userDoc = await userDocRef.get();
    if (userDoc.exists) return true;
    try {
      await userDocRef.set({
        'createdAt': FieldValue.serverTimestamp(),
        'tier': 0,
        'receivedItemsCount': 0, // PATCH: always start with count 0
      }, SetOptions(merge: true));
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> fetchUserDailyDataById(
      String userId, {
        bool forceNetwork = false,
      }) async {
    if (_dailyCache.containsKey(userId) && !forceNetwork) {
      return _dailyCache[userId]!;
    }
    final userDoc = forceNetwork
        ? await _firestore
        .collection('users')
        .doc(userId)
        .get(const GetOptions(source: Source.server))
        : await _firestore.collection('users').doc(userId).get();

    final tier = (userDoc.data()?['tier'] ?? 0) as int;
    final dailyDoc = forceNetwork
        ? await _firestore
        .collection('users')
        .doc(userId)
        .collection('daily')
        .doc('main')
        .get(const GetOptions(source: Source.server))
        : await _firestore
        .collection('users')
        .doc(userId)
        .collection('daily')
        .doc('main')
        .get();

    final lastClaimed = dailyDoc.data()?['lastClaimed'];
    final lastCoinsClaimed = dailyDoc.data()?['lastCoinsClaimed'];
    final coinsClaimed = dailyDoc.data()?['coinsClaimed'];
    final lastBoxClaimedRaw = dailyDoc.data()?['lastBoxClaimed'];
    DateTime? lastBoxClaimed;
    if (lastBoxClaimedRaw is Timestamp) {
      lastBoxClaimed = lastBoxClaimedRaw.toDate();
    } else if (lastBoxClaimedRaw is DateTime) {
      lastBoxClaimed = lastBoxClaimedRaw;
    } else {
      lastBoxClaimed = null;
    }

    final dailyData = {
      'lastClaimed': lastClaimed,
      'lastCoinsClaimed': lastCoinsClaimed,
      'coinsClaimed': coinsClaimed,
      'lastBoxClaimed': lastBoxClaimed,
      'tier': tier,
    };

    _dailyCache[userId] = dailyData;
    return dailyData;
  }

  static Future<Map<String, dynamic>> fetchUserDailyData(
      {bool forceNetwork = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not signed in');
    final uid = user.uid;

    if (_dailyCache.containsKey(uid) && !forceNetwork) {
      return _dailyCache[uid]!;
    }
    final userDoc = forceNetwork
        ? await _firestore
        .collection('users')
        .doc(uid)
        .get(const GetOptions(source: Source.server))
        : await _firestore.collection('users').doc(uid).get();
    final tier = (userDoc.data()?['tier'] ?? 0) as int;

    final dailyDoc = forceNetwork
        ? await _firestore
        .collection('users')
        .doc(uid)
        .collection('daily')
        .doc('main')
        .get(const GetOptions(source: Source.server))
        : await _firestore
        .collection('users')
        .doc(uid)
        .collection('daily')
        .doc('main')
        .get();

    final lastClaimed = dailyDoc.data()?['lastClaimed'];
    final lastCoinsClaimed = dailyDoc.data()?['lastCoinsClaimed'];
    final coinsClaimed = dailyDoc.data()?['coinsClaimed'];
    final lastBoxClaimedRaw = dailyDoc.data()?['lastBoxClaimed'];
    DateTime? lastBoxClaimed;
    if (lastBoxClaimedRaw is Timestamp) {
      lastBoxClaimed = lastBoxClaimedRaw.toDate();
    } else if (lastBoxClaimedRaw is DateTime) {
      lastBoxClaimed = lastBoxClaimedRaw;
    } else {
      lastBoxClaimed = null;
    }

    final dailyData = {
      'lastClaimed': lastClaimed,
      'lastCoinsClaimed': lastCoinsClaimed,
      'coinsClaimed': coinsClaimed,
      'lastBoxClaimed': lastBoxClaimed,
      'tier': tier,
    };

    _dailyCache[uid] = dailyData;
    return dailyData;
  }

  static void invalidateDailyCache(String userId) {
    _dailyCache.remove(userId);
  }

  static Future<Map<String, Map<String, dynamic>>> fetchAllItems(
      {bool forceRefresh = false}) async {
    if (_allItemsCache != null && !forceRefresh) {
      return _allItemsCache!;
    }
    final query = await _firestore.collection('item_data').get();
    final items = <String, Map<String, dynamic>>{};
    for (final doc in query.docs) {
      items[doc.id] = doc.data();
    }
    _allItemsCache = items;
    return items;
  }

  static void invalidateAllItemsCache() {
    _allItemsCache = null;
  }

  static Future<int> getLikeCount(String userId) async {
    if (_likeCountCache.containsKey(userId)) {
      return _likeCountCache[userId]!;
    }
    final doc = await _firestore.collection('users').doc(userId).get();
    final count = doc.data()?['likes'] ?? 0;
    _likeCountCache[userId] = count;
    return count;
  }

  static Stream<int> likeCountStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) => (doc.data()?['likes'] ?? 0) as int);
  }

  static Future<bool> hasUserLiked(String targetUserId, {String? currentUserId}) async {
    final uid = currentUserId ?? _auth.currentUser?.uid;
    if (uid == null) return false;
    final doc = await _firestore
        .collection('users')
        .doc(uid)
        .collection('liked')
        .doc(targetUserId)
        .get();
    return doc.exists;
  }

  static Future<Map<String, dynamic>> likeUser(String targetUserId) async {
    final callable = _functions.httpsCallable('likeUser');
    final res = await callable.call({'targetUserId': targetUserId});
    final data = res.data as Map<String, dynamic>;
    if (data['status'] == 'success') {
      _likeCountCache[targetUserId] =
          (_likeCountCache[targetUserId] ?? 0) + 1;
    }
    return data;
  }

  static StreamSubscription listenFriendStatus({
    required String currentUserId,
    required String targetUserId,
    required void Function(String? status) onStatusChanged,
  }) {
    return _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('friendRequests')
        .doc(targetUserId)
        .snapshots()
        .listen((snap) async {
      final friendDoc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('friends')
          .doc(targetUserId)
          .get();
      String? status;
      if (friendDoc.exists) {
        status = 'accepted';
      } else {
        String? s1 = snap.data()?['status'] as String?;
        final rev = await _firestore
            .collection('users')
            .doc(targetUserId)
            .collection('friendRequests')
            .doc(currentUserId)
            .get();
        String? s2 = rev.data()?['status'] as String?;
        if (s1 == 'accepted' && s2 == 'accepted') {
          status = 'accepted';
        } else if (s1 == 'pending') {
          status = 'pending';
        } else if (s2 == 'pending') {
          status = 'incoming';
        }
      }
      onStatusChanged(status);
    });
  }

  static Future<void> removeFriend(String userA, String userB) async {
    final b = _firestore.batch();
    b.delete(_firestore
        .collection('users')
        .doc(userA)
        .collection('friendRequests')
        .doc(userB));
    b.delete(_firestore
        .collection('users')
        .doc(userB)
        .collection('friendRequests')
        .doc(userA));
    b.delete(_firestore
        .collection('users')
        .doc(userA)
        .collection('friends')
        .doc(userB));
    b.delete(_firestore
        .collection('users')
        .doc(userB)
        .collection('friends')
        .doc(userA));
    await b.commit();
  }

  // --- PATCH: VIP Room Fetching ---

  /// Fetch all VIP rooms (with caching & performance optimization)
  static Future<List<VIPRoomInfo>> fetchVIPRooms({bool forceRefresh = false}) async {
    final now = DateTime.now();
    if (_vipRoomsCache != null &&
        _vipRoomsCacheTime != null &&
        now.difference(_vipRoomsCacheTime!) < _vipRoomsCacheDuration &&
        !forceRefresh) {
      return _vipRoomsCache!;
    }
    final query = await _firestore.collection('vip_rooms').get();
    final List<VIPRoomInfo> rooms = query.docs
        .map((doc) => VIPRoomInfo.fromMap(doc.id, doc.data()))
        .toList();
    _vipRoomsCache = rooms;
    _vipRoomsCacheTime = DateTime.now();
    return rooms;
  }

  /// Fetch VIP room info for a batch of room IDs (batch optimization)
  static Future<Map<String, VIPRoomInfo>> fetchMultipleVIPRoomInfos(
      List<String> roomIds, {bool forceRefresh = false}) async {
    Map<String, VIPRoomInfo> result = {};
    const maxBatch = 30;
    List<String> toFetch = [];

    // Use cache if available and not forcing refresh
    if (_vipRoomsCache != null && !forceRefresh) {
      for (final id in roomIds) {
        final found = _vipRoomsCache!.where((r) => r.id == id);
        if (found.isNotEmpty) {
          result[id] = found.first;
        } else {
          toFetch.add(id);
        }
      }
    } else {
      toFetch = roomIds;
    }

    for (var i = 0; i < toFetch.length; i += maxBatch) {
      final batch = toFetch.sublist(
          i, (i + maxBatch > toFetch.length) ? toFetch.length : i + maxBatch);
      final query = await _firestore
          .collection('vip_rooms')
          .where(FieldPath.documentId, whereIn: batch)
          .get();
      for (var doc in query.docs) {
        final info = VIPRoomInfo.fromMap(doc.id, doc.data());
        result[doc.id] = info;
        _vipRoomsCache = (_vipRoomsCache ?? [])..add(info);
      }
    }
    for (final id in roomIds) {
      result[id] ??= VIPRoomInfo.fromMap(id, null);
    }
    return result;
  }

  /// Invalidate the VIP rooms cache
  static void invalidateVIPRoomsCache() {
    _vipRoomsCache = null;
    _vipRoomsCacheTime = null;
  }

  /// --- PATCH: Fetch current user tier from Firestore ---
  static Future<int> fetchCurrentUserTier() async {
    final user = _auth.currentUser;
    if (user == null) {
      return 0;
    }
    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) {
      return 0;
    }
    final data = doc.data();
    if (data == null) {
      return 0;
    }
    final tier = data['tier'];
    if (tier is int) {
      return tier;
    }
    if (tier is String) {
      return int.tryParse(tier) ?? 0;
    }
    return 0;
  }

  // <<<<< PATCH: Fetch voice note download URL from Firebase Storage >>>>>
  static Future<String> fetchVoiceNoteUrl(String storagePath) async {
    try {
      final ref = _storage.ref(storagePath);
      return await ref.getDownloadURL();
    } catch (e) {
      return '';
    }
  }

  // <<<<< PATCH: Added fetchChatBubbleData >>>>>
  static Future<Map<String, dynamic>> fetchChatBubbleData(String userId) async {
    final metaSnap = await _firestore.collection('chat_bubble_data').get();
    final allMetas = metaSnap.docs
        .map((doc) => ChatBubbleMeta.fromFirestore(doc.data()))
        .where((meta) => meta.id != 'CB1000')
        .toList();

    final Map<String, int> prices = {};
    for (final doc in metaSnap.docs) {
      final data = doc.data();
      if (data['id'] != 'CB1000') {
        int price = 0;
        if (data['coinPrice'] is int) {
          price = data['coinPrice'] as int;
        } else if (data['priceCoins'] is int) {
          price = data['priceCoins'] as int;
        }
        prices[data['id']] = price;
      }
    }

    Set<String> ownedSet = {};
    final invDoc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('inventory')
        .doc('chat_bubbles')
        .get();
    if (invDoc.exists && invDoc.data() != null) {
      final data = invDoc.data()!;
      ownedSet = data.values.whereType<String>().toSet();
    }

    final userDoc = await _firestore.collection('users').doc(userId).get();
    String? selected;
    if (userDoc.exists) {
      selected = userDoc.data()?['selectedChatBubbleId'] as String?;
    }
    if (selected == null && ownedSet.isNotEmpty) selected = ownedSet.first;

    allMetas.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

    return {
      'bubbleMetas': allMetas,
      'bubblePrices': prices,
      'ownedBubbles': ownedSet,
      'selectedChatBubbleId': selected,
    };
  }

  /// PATCH 2: Save selected chat bubble id for a user
  static Future<void> saveSelectedChatBubble(String userId, String? bubbleId) async {
    final ref = _firestore.collection('users').doc(userId);
    if (bubbleId == null) {
      await ref.set({'selectedChatBubbleId': FieldValue.delete()}, SetOptions(merge: true));
    } else {
      await ref.set({'selectedChatBubbleId': bubbleId}, SetOptions(merge: true));
    }
  }

  // <<<<< PATCH: Add getUserBadgeUrl method >>>>>
  static Future<String?> getUserBadgeUrl(String userId, {bool forceRefresh = false}) async {
    if (!forceRefresh && _badgeUrlCache.containsKey(userId)) return _badgeUrlCache[userId];
    final doc = await _firestore.collection('users').doc(userId).get();
    if (!doc.exists) return null;
    final data = doc.data();
    final badgeUrl = data?['mainBadgeUrl'] as String?;
    _badgeUrlCache[userId] = badgeUrl;
    return badgeUrl;
  }

  // <<< PATCH: Add method to fetch username change token counts >>>
  static Future<int> fetchUsernameChangeTokensBought(String userId, {bool forceRefresh = false}) async {
    if (!forceRefresh && _tokensBoughtCache.containsKey(userId)) return _tokensBoughtCache[userId]!;
    final doc = await _firestore.collection('users').doc(userId).get();
    if (!doc.exists) return 0;
    final data = doc.data();
    final tokens = (data?['usernameChangeTokensBought'] is int) ? data!['usernameChangeTokensBought'] as int : 0;
    _tokensBoughtCache[userId] = tokens;
    return tokens;
  }

  static Future<int> fetchUsernameChangeTokensOwned(String userId, {bool forceRefresh = false}) async {
    if (!forceRefresh && _tokensOwnedCache.containsKey(userId)) return _tokensOwnedCache[userId]!;
    final doc = await _firestore.collection('users').doc(userId).get();
    if (!doc.exists) return 0;
    final data = doc.data();
    final tokens = (data?['username_change_tokens'] is int) ? data!['username_change_tokens'] as int : 0;
    _tokensOwnedCache[userId] = tokens;
    return tokens;
  }

  // <<< PATCH: Add method to fetch user coins >>>
  static Future<int> fetchUserCoins(String userId, {bool forceRefresh = false}) async {
    if (!forceRefresh && _coinsCache.containsKey(userId)) return _coinsCache[userId]!;
    final doc = await _firestore.collection('users').doc(userId).get();
    if (!doc.exists) return 0;
    final data = doc.data();
    final coins = (data?['coins'] is int) ? data!['coins'] as int : 0;
    _coinsCache[userId] = coins;
    return coins;
  }

  /// Returns the number of username change tokens the current signed-in user owns.
  static Future<int> fetchUsernameChangeTokens() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 0;
    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) return 0;
    final data = doc.data();
    return (data?['username_change_tokens'] is int) ? data!['username_change_tokens'] as int : 0;
  }

}
