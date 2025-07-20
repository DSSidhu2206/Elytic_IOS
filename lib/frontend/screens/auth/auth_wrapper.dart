// lib/frontend/screens/auth/auth_wrapper.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:elytic/backend/services/chat_service.dart';
import 'package:elytic/backend/services/presence_service.dart';
import 'package:elytic/backend/services/user_service.dart'; // PATCH: Import user service
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthWrapper extends StatefulWidget {
  final User? user;
  const AuthWrapper({Key? key, this.user}) : super(key: key);

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  Timer? _tokenRefreshTimer;

  RemoteMessage? _pendingNotificationMessage;

  @override
  void initState() {
    super.initState();
    _askNotificationPermissionOnce(); // PATCH: Ask for notification permission only if not determined
    _initializeFCM();

    // Listen for auth state and token changes
    FirebaseAuth.instance.idTokenChanges().listen((user) async {
      if (user == null) {
        _cancelTokenRefreshTimer();
        Navigator.of(context).pushReplacementNamed('/landing');
      } else {
        await _scheduleTokenRefresh(user);
        // After login, if there is a pending notification, handle it now
        if (_pendingNotificationMessage != null) {
          await _handleNotificationNavigation(_pendingNotificationMessage!);
          _pendingNotificationMessage = null;
        }
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _routeUser());
  }

  // PATCH: Only prompt for notification permission if not yet determined
  Future<void> _askNotificationPermissionOnce() async {
    try {
      final settings = await _messaging.getNotificationSettings();
      if (settings.authorizationStatus == AuthorizationStatus.notDetermined) {
        final newSettings = await _messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        // Optionally, handle if denied and maybe show a one-time dialog later
        debugPrint('Notification permission requested: ${newSettings.authorizationStatus}');
      } else {
        debugPrint('Notification permission already handled: ${settings.authorizationStatus}');
      }
    } catch (e, st) {
      debugPrint('Failed to check/request notification permission: $e\n$st');
      // Fail silently; do NOT block app
    }
  }

  Future<void> _scheduleTokenRefresh(User user) async {
    _cancelTokenRefreshTimer();

    final idTokenResult = await user.getIdTokenResult();
    final expiresAt = idTokenResult.expirationTime;
    if (expiresAt == null) return;

    final now = DateTime.now();
    final durationUntilExpiry = expiresAt.difference(now);
    final refreshAfter = durationUntilExpiry - const Duration(minutes: 5);

    if (refreshAfter.isNegative) {
      await user.getIdToken(true);
      await _scheduleTokenRefresh(user);
      return;
    }

    _tokenRefreshTimer = Timer(refreshAfter, () async {
      try {
        await user.getIdToken(true);
        await _scheduleTokenRefresh(user);
      } catch (e) {
        await FirebaseAuth.instance.signOut();
      }
    });
  }

  void _cancelTokenRefreshTimer() {
    _tokenRefreshTimer?.cancel();
    _tokenRefreshTimer = null;
  }

  Future<void> _initializeFCM() async {
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      final token = await _messaging.getToken();
      if (token != null) {
        await _saveFcmToken(token);
      }

      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        await _saveFcmToken(newToken);
      });
    }

    // Removed FirebaseMessaging.onMessageOpenedApp listener here
  }

  // Keep _handleNotificationNavigation for internal calls but no external onMessageOpenedApp listener
  Future<void> _handleNotificationNavigation(RemoteMessage message) async {
    final data = message.data;
    final type = data['type'];

    // Ensure user is logged in before navigating
    final user = widget.user ?? FirebaseAuth.instance.currentUser;
    if (user == null) {
      // Store the notification to handle after login
      _pendingNotificationMessage = message;
      return;
    }

    // --- DM Notification ---
    if (type == 'dm' && data['otherUserId'] != null) {
      final otherUserId = data['otherUserId'];
      String? otherUserName = data['otherUserName'];
      String? otherUserAvatar = data['otherUserAvatar'];
      bool readReceiptsEnabled = data['readReceiptsEnabled'] == "true" || data['readReceiptsEnabled'] == true;

      // If info is not in the notification, fetch from Firestore
      if (otherUserName == null || otherUserAvatar == null) {
        try {
          final doc = await FirebaseFirestore.instance.collection('users').doc(otherUserId).get();
          final userData = doc.data();
          otherUserName ??= userData?['username'] ?? "Unknown";
          otherUserAvatar ??= userData?['avatarUrl'] ?? "";
          readReceiptsEnabled = userData?['readReceiptsEnabled'] ?? false;
        } catch (e) {
          // Show error and abort navigation
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to open DM: $e")),
          );
          return;
        }
      }

      // Before navigating to DM, navigate to last active room first
      String? lastRoom = await ChatService.getLastActiveRoom(user.uid);

      if (lastRoom == null || lastRoom.trim().isEmpty) {
        lastRoom = await _firstAvailableRoom('general');
      } else {
        final full = await ChatService.isRoomFullCached(lastRoom);
        if (full) {
          final baseMatch = RegExp(r'^([a-zA-Z]+)(\d+)$').firstMatch(lastRoom);
          final base = baseMatch?.group(1) ?? 'general';
          lastRoom = await _firstAvailableRoom(base);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Room $lastRoom is full, redirecting...')),
          );
        }
      }

      final roomDoc = await FirebaseFirestore.instance.collection('rooms').doc(lastRoom).get();
      final roomData = roomDoc.data();
      String displayName = roomData?['title'] ?? roomData?['displayName'] ?? _prettifyRoomId(lastRoom);

      final userInfo = await UserService.fetchDisplayInfo(user.uid);

      if (!mounted) return;

      // Navigate to last active room first (replace current stack)
      await Navigator.of(context).pushReplacementNamed(
        '/chat',
        arguments: {
          'roomId': lastRoom,
          'displayName': displayName,
          'userName': userInfo.username ?? '',
          'userImageUrl': userInfo.avatarUrl ?? '',
          'currentUserId': user.uid,
          'currentUserTier': userInfo.tier ?? 1,
        },
      );

      // Then push DM screen
      Navigator.of(context).pushNamed(
        '/dm',
        arguments: {
          'otherUserId': otherUserId,
          'otherUserName': otherUserName,
          'otherUserAvatar': otherUserAvatar,
          'readReceiptsEnabled': readReceiptsEnabled,
        },
      );

      return;
    }

    // --- Room Chat Notification (fallback, legacy) ---
    final roomId = data['roomId'] ?? message.data['roomId'];
    if (roomId != null) {
      Navigator.of(context).pushNamed(
        '/chat',
        arguments: {'roomId': roomId},
      );
    }
  }

  Future<void> _saveFcmToken(String token) async {
    final user = widget.user ?? FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userId = user.uid;

    final tokensRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('fcmTokens')
        .doc(token);

    try {
      await tokensRef.set({
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {}
  }

  Future<void> _routeUser() async {
    final user = widget.user ?? FirebaseAuth.instance.currentUser;
    if (user == null) {
      Navigator.of(context).pushReplacementNamed('/landing');
      return;
    }

    final uid = user.uid;

    final exists = await UserService.ensureUserDocExists(uid);
    if (!exists) {
      Navigator.of(context).pushReplacementNamed('/landing');
      return;
    }

    final userInfo = await UserService.fetchDisplayInfo(uid);

    if (userInfo.username == 'Unknown' || userInfo.avatarUrl.isEmpty) {
      Navigator.of(context).pushReplacementNamed('/landing');
      return;
    }

    final userName = userInfo.username;
    final userImageUrl = userInfo.avatarUrl;
    final userTier = userInfo.tier;
    final userAvatarBorderUrl = userInfo.currentBorderUrl;

    String? lastRoom = await ChatService.getLastActiveRoom(uid);

    String targetRoom;
    if (lastRoom == null || lastRoom.trim().isEmpty) {
      targetRoom = await _firstAvailableRoom('general');
    } else {
      final full = await ChatService.isRoomFullCached(lastRoom);
      if (full) {
        final baseMatch = RegExp(r'^([a-zA-Z]+)(\d+)$').firstMatch(lastRoom);
        final base = baseMatch?.group(1) ?? 'general';
        targetRoom = await _firstAvailableRoom(base);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Room $lastRoom is full. Redirecting to $targetRoom.'),
          ),
        );
      } else {
        targetRoom = lastRoom;
      }
    }

    final sessionId = const Uuid().v4();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sessionId', sessionId);

    await ChatService.joinRoom(targetRoom);

    try {
      await PresenceService.setupRoomPresence(
        userId: uid,
        roomId: targetRoom,
        userName: userName,
        avatarUrl: userImageUrl,
        userAvatarBorderUrl: userAvatarBorderUrl,
        tier: userTier,
      );
    } catch (e) {}

    final roomDoc = await FirebaseFirestore.instance.collection('rooms').doc(targetRoom).get();
    final roomData = roomDoc.data();
    String displayName;
    if (roomData != null) {
      displayName = roomData['title'] ?? roomData['displayName'] ?? _prettifyRoomId(targetRoom);
    } else {
      displayName = _prettifyRoomId(targetRoom);
    }

    if (!mounted) return;

    Navigator.of(context).pushReplacementNamed(
      '/chat',
      arguments: {
        'roomId': targetRoom,
        'displayName': displayName,
        'userName': userName,
        'userImageUrl': userImageUrl,
        'currentUserId': uid,
        'currentUserTier': userTier,
      },
    );
  }

  Future<String> _firstAvailableRoom(String baseName) async {
    var idx = 1;
    while (true) {
      final roomId = '$baseName$idx';
      if (!await ChatService.isRoomFullCached(roomId)) return roomId;
      idx++;
    }
  }

  @override
  void dispose() {
    _cancelTokenRefreshTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SizedBox.shrink(),
    );
  }
}

String _prettifyRoomId(String roomId) {
  return roomId
      .replaceAllMapped(RegExp(r'([a-zA-Z])(\d+)'), (m) => '${m[1]} ${m[2]}')
      .replaceAll('_', ' ')
      .split(' ')
      .map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : '')
      .join(' ')
      .trim();
}
