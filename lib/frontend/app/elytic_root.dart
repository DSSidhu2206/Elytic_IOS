// lib/frontend/app/elytic_root.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:uuid/uuid.dart';
import '../providers/notification_listener.dart';
import '../theme/app_theme.dart';
import 'app_router.dart';
import '../providers/dm_navigation_notifier.dart';
import '../animations/landing_animations/landing_page_animation.dart';
import '../../main.dart';
import 'fcm_initializer.dart';
import '../../../backend/services/user_service.dart';
import '../../../backend/services/chat_service.dart';
import '../../../backend/services/presence_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:cloud_functions/cloud_functions.dart';

class ElyticRoot extends StatelessWidget {
  const ElyticRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeNotifier()),
        ChangeNotifierProvider(create: (_) => DmNavigationNotifier()),
      ],
      child: Consumer<ThemeNotifier>(
        builder: (context, themeNotifier, _) {
          return FcmInitializer(
            child: MaterialApp(
              title: 'Elytic',
              debugShowCheckedModeBanner: false,
              theme: ThemeData.light(),
              darkTheme: ThemeData.dark(),
              themeMode: themeNotifier.themeMode,
              scaffoldMessengerKey: scaffoldMessengerKey,
              navigatorKey: navigatorKey,
              home: const _AnimatedLandingWrapper(),
              onGenerateRoute: AppRoutes.generateRoute,
            ),
          );
        },
      ),
    );
  }
}

class _AnimatedLandingWrapper extends StatefulWidget {
  const _AnimatedLandingWrapper({super.key});

  @override
  State<_AnimatedLandingWrapper> createState() =>
      _AnimatedLandingWrapperState();
}

class _AnimatedLandingWrapperState extends State<_AnimatedLandingWrapper> {
  bool _animationComplete = false;
  bool _routingComplete = false;
  bool _loadingAfterAnimation = false;
  User? _user;
  bool _authStateLoaded = false;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;

  RemoteMessage? _pendingNotificationMessage;

  @override
  void initState() {
    super.initState();

    // PATCH: On cold start, do NOT forcibly navigate on notification tap.
    // Instead, just treat it like normal app open.
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) async {
      if (message != null) {
        // Just store notification if you want to handle later, or ignore.
        _pendingNotificationMessage = message;
        // Don't navigate forcibly here — let auth logic route user properly.
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ChatService.getStickerPackMetadata();
      ChatService.getBadgeMetadata();
    });

    _purchaseSub = InAppPurchase.instance.purchaseStream.listen(_onPurchaseUpdated);

    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      setState(() {
        _user = user;
        _authStateLoaded = true;
        _routingComplete = false;
        _loadingAfterAnimation = false;
      });

      if (user != null) {
        if (_animationComplete) {
          _startRouting(user);
        }

        // Optionally, handle any pending notification now after login and routing
        if (_pendingNotificationMessage != null && _routingComplete) {
          // For simplicity, just clear it or handle with your existing logic here
          _pendingNotificationMessage = null;
        }
      } else {
        setState(() => _routingComplete = true);
      }
    });

    // PATCH: On notification tap while app in background or foreground,
    // do NOT forcibly navigate to landing.
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      // You can optionally store or handle notification here
      // but do NOT forcibly navigate.
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _purchaseSub?.cancel();
    super.dispose();
  }

  void _onPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    for (final purchase in purchaseDetailsList) {
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        _handleEntitlement(purchase);
      }
      if (purchase.pendingCompletePurchase) {
        InAppPurchase.instance.completePurchase(purchase);
      }
    }
  }

  Future<void> _handleEntitlement(PurchaseDetails purchase) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final String productId = purchase.productID;
    final String purchaseToken = purchase.verificationData.serverVerificationData;
    final bool isSubscription = productId.contains('subscription');

    try {
      await FirebaseAuth.instance.currentUser?.getIdToken(true); // PATCH: force ID token refresh

      final callable = FirebaseFunctions.instance.httpsCallable('verifyPlayPurchaseAndGrant');
      final result = await callable.call({
        "productId": productId,
        "purchaseToken": purchaseToken,
        "isSubscription": isSubscription,
      });

      final data = result.data;
      String msg;
      if (data is Map && data['success'] == true) {
        msg = "Purchase successful!";
      } else if (data is Map && data['message'] != null) {
        msg = data['message'].toString();
      } else {
        msg = "Purchase processed. Please check your balance.";
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Purchase verification failed: ${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _startRouting(User user) async {
    setState(() {
      _loadingAfterAnimation = true;
    });

    await _handleRouting(user);

    setState(() {
      _loadingAfterAnimation = false;
    });

    _tryNavigate();
  }

  Future<void> _handleRouting(User? user) async {
    if (user == null) {
      setState(() => _routingComplete = true);
      return;
    }

    final uid = user.uid;

    final ensureUserDocFuture = UserService.ensureUserDocExists(uid);
    final fetchUserInfoFuture = UserService.fetchDisplayInfo(uid);
    final fetchLastRoomFuture = ChatService.getLastActiveRoom(uid);

    final userDocExists = await ensureUserDocFuture;
    if (!userDocExists) {
      setState(() => _routingComplete = true);
      return;
    }

    final results = await Future.wait<dynamic>([
      fetchUserInfoFuture,
      fetchLastRoomFuture,
    ]);

    final userInfo = results[0] as UserDisplayInfo?;
    final lastRoomRaw = results[1] as String?;

    if (userInfo == null ||
        userInfo.username == 'Unknown' ||
        (userInfo.avatarUrl?.isEmpty ?? true)) {
      setState(() => _routingComplete = true);
      return;
    }

    String lastRoom = lastRoomRaw ?? '';

    if (lastRoom.trim().isEmpty) {
      lastRoom = await _firstAvailableRoom('general');
    } else {
      final full = await ChatService.isRoomFullCached(lastRoom);
      if (full) {
        final baseMatch = RegExp(r'^([a-zA-Z]+)(\d+)$').firstMatch(lastRoom);
        final base = baseMatch!.group(1)!;
        final oldRoom = lastRoom;
        lastRoom = await _firstAvailableRoom(base);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Room $oldRoom is full. Redirecting to $lastRoom.'),
              ),
            );
          }
        });
      }
    }

    await ChatService.joinRoom(lastRoom);
    PresenceService.setupRoomPresence(
      userId: uid,
      roomId: lastRoom,
      userName: userInfo.username,
      avatarUrl: userInfo.avatarUrl ?? '',
      userAvatarBorderUrl: userInfo.currentBorderUrl ?? '',
      tier: userInfo.tier ?? 1,
    ).catchError((_) {});
    await saveSessionIdLocally(const Uuid().v4());

    final roomDoc =
    await FirebaseFirestore.instance.collection('rooms').doc(lastRoom).get();
    final roomData = roomDoc.data();
    String displayName =
        roomData?['title'] ?? roomData?['displayName'] ?? _prettifyRoomId(lastRoom);

    _pendingNavigation = _NavigationData(
      route: '/chat',
      arguments: {
        'roomId': lastRoom,
        'displayName': displayName,
        'userName': userInfo.username,
        'userImageUrl': userInfo.avatarUrl ?? '',
        'currentUserId': uid,
        'currentUserTier': userInfo.tier ?? 1,
      },
    );

    setState(() => _routingComplete = true);
  }

  Future<String> _firstAvailableRoom(String baseName) async {
    var idx = 1;
    while (true) {
      final roomId = '$baseName$idx';
      if (!await ChatService.isRoomFullCached(roomId)) return roomId;
      idx++;
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

  Future<void> saveSessionIdLocally(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sessionId', sessionId);
  }

  _NavigationData? _pendingNavigation;

  void _tryNavigate() {
    if (_routingComplete) {
      if (_user == null) {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/landing');
        }
      } else if (_pendingNavigation != null) {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed(
            _pendingNavigation!.route,
            arguments: _pendingNavigation!.arguments,
          );
        }
      }
    }
  }

  @override
  void didUpdateWidget(covariant _AnimatedLandingWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    _tryNavigate();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tryNavigate();
  }

  @override
  Widget build(BuildContext context) {
    if (!_authStateLoaded) {
      return const SizedBox();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _tryNavigate());

    if (_user != null && _user!.uid.isNotEmpty) {
      if (_routingComplete && !_loadingAfterAnimation) {
        return const SizedBox();
      }

      if (_animationComplete && _loadingAfterAnimation) {
        return Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  'Elytic',
                  style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 20),
                SizedBox(
                  width: 150,
                  child: LinearProgressIndicator(),
                ),
              ],
            ),
          ),
        );
      }

      return NotificationListenerWidget(
        userId: _user!.uid,
        child: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: LandingAnimation(
              onAnimationComplete: () {
                setState(() {
                  _animationComplete = true;
                  if (_user != null) {
                    _startRouting(_user!);
                  }
                });
              },
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: LandingAnimation(
          onAnimationComplete: () {
            setState(() => _animationComplete = true);
            _tryNavigate();
          },
        ),
      ),
    );
  }
}

class _NavigationData {
  final String route;
  final Object? arguments;
  _NavigationData({required this.route, this.arguments});
}
