// lib/frontend/app/app_router.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../screens/landing/landing_page.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/auth/login_screen.dart';
import '../widgets/layout/room_layout.dart';
import '../screens/shop/shop_page.dart';
import '../providers/notification_listener.dart';
import '../screens/pets/pet_profile_screen.dart';
import '../screens/pets/pet_profile_edit_screen.dart';
// Removed import for PetGalleryScreen here
import '../screens/profile/user_profile_screen.dart';
import '../screens/shop/admin_shop_rotation_screen.dart';
import '../screens/shop/create_mystery_box_page.dart';
import '../screens/home/vip_room_tab.dart';
import '../../frontend/screens/vip/create_vip_room_screen.dart';

// Add import for SubscriptionsScreen here
import '/frontend/screens/shop/subscriptions_page.dart';

class AppRoutes {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/landing':
        return MaterialPageRoute(builder: (_) => const LandingPage());

      case '/signup':
        return MaterialPageRoute(builder: (_) => const SignupScreen());

      case '/login':
        return MaterialPageRoute(builder: (_) => const LoginScreen());

      case '/chat':
        final args = settings.arguments;
        if (args is! Map<String, dynamic>) {
          return _errorRoute('Missing or invalid arguments for RoomLayout');
        }
        final roomId = args['roomId'] as String?;
        final userName = args['userName'] as String?;
        final userImageUrl = args['userImageUrl'] as String?;
        final currentUserId = args['currentUserId'] as String?;
        final currentUserTier = args['currentUserTier'] as int?;
        final providedDisplayName = args['displayName'] as String?;
        if (roomId == null || userName == null || userImageUrl == null || currentUserId == null || currentUserTier == null) {
          return _errorRoute('Missing required chat parameters');
        }
        if (providedDisplayName != null) {
          return MaterialPageRoute(
            builder: (_) => NotificationListenerWidget(
              userId: currentUserId,
              child: RoomLayout(
                roomId: roomId,
                displayName: providedDisplayName,
                userName: userName,
                userImageUrl: userImageUrl,
                currentUserId: currentUserId,
                currentUserTier: currentUserTier,
              ),
            ),
          );
        }
        return MaterialPageRoute(
          builder: (_) => FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('rooms').doc(roomId).get(),
            builder: (context, snapshot) {
              String displayName = roomId;
              if (snapshot.hasData && snapshot.data!.exists) {
                final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
                final title = data['title'] as String?;
                displayName = title ?? displayName;
              }
              return NotificationListenerWidget(
                userId: currentUserId,
                child: RoomLayout(
                  roomId: roomId,
                  displayName: displayName,
                  userName: userName,
                  userImageUrl: userImageUrl,
                  currentUserId: currentUserId,
                  currentUserTier: currentUserTier,
                ),
              );
            },
          ),
        );

      case '/room': {
        final args = settings.arguments;
        if (args is! Map<String, dynamic>) {
          return _errorRoute('Missing or invalid arguments for /room');
        }

        final roomId = args['roomId'] as String?;
        final roomName = args['roomName'] as String?;
        final isVIP = args['isVIP'] as bool? ?? false;
        final currentUser = FirebaseAuth.instance.currentUser;

        if (roomId == null || roomName == null || currentUser == null) {
          return _errorRoute('Missing required room parameters');
        }

        return MaterialPageRoute(
          builder: (_) => NotificationListenerWidget(
            userId: currentUser.uid,
            child: RoomLayout(
              roomId: roomId,
              displayName: roomName,
              userName: currentUser.displayName ?? currentUser.email ?? 'Unknown',
              userImageUrl: currentUser.photoURL ?? '',
              currentUserId: currentUser.uid,
              currentUserTier: 1,
              isVIP: isVIP,
            ),
          ),
        );
      }

      case '/shop':
        return MaterialPageRoute(builder: (_) => ShopPage());

      case '/create_mystery_box':
        return MaterialPageRoute(builder: (_) => const CreateMysteryBoxPage());

      case '/vip_rooms':
        return MaterialPageRoute(
          builder: (_) => const VIPRoomTab(),
        );

      case '/create_vip_room':
        return MaterialPageRoute(
          builder: (_) => const CreateVIPRoomScreen(),
        );

    // Removed '/pets' route usage

      case '/petProfile': {
        final args = settings.arguments;
        if (args is! Map<String, dynamic>) {
          return _errorRoute('Missing or invalid arguments for PetProfileScreen');
        }
        if (!args.containsKey('currentUserUsername')) {
          return _errorRoute('Missing required argument: currentUserUsername for PetProfileScreen');
        }
        return MaterialPageRoute(
          builder: (_) => PetProfileScreen(
            userId: args['userId'] as String,
            petId: args['petId'] as String,
            petName: args['petName'] as String,
            petAvatar: args['petAvatar'] as String,
            nickname: args['nickname'] as String?,
            isCurrentUser: args['isCurrentUser'] as bool,
            currentUserId: args['currentUserId'] as String,
            currentUserTier: args['currentUserTier'] as int,
            currentUserUsername: args['currentUserUsername'] as String,
          ),
        );
      }

      case '/editPetProfile': {
        final args = settings.arguments;
        if (args is! Map<String, dynamic>) {
          return _errorRoute('Missing or invalid arguments for PetProfileEditScreen');
        }
        return MaterialPageRoute(
          builder: (_) => PetProfileEditScreen(
            userId: args['userId'] as String,
            petId: args['petId'] as String,
            petName: args['petName'] as String,
            petAvatar: args['petAvatar'] as String,
            nickname: args['nickname'] as String?,
          ),
        );
      }

      case '/user_profile': {
        final args = settings.arguments;
        if (args is! Map<String, dynamic>) {
          return _errorRoute('Missing or invalid arguments for UserProfileScreen');
        }
        if (!args.containsKey('userId') || !args.containsKey('currentUserId') || !args.containsKey('currentUserTier')) {
          return _errorRoute('Missing required arguments for UserProfileScreen');
        }
        return MaterialPageRoute(
          builder: (_) => UserProfileScreen(
            userId: args['userId'] as String,
            currentUserId: args['currentUserId'] as String,
            currentUserTier: args['currentUserTier'] as int,
          ),
        );
      }

      case '/shop_rotation': {
        final args = settings.arguments;
        if (args is! Map<String, dynamic> || args['currentUserId'] == null || args['currentUserTier'] == null) {
          return _errorRoute('You do not have permission to access this page.');
        }
        if (args['currentUserTier'] != 6) {
          return _errorRoute('You do not have permission to access this page.');
        }
        return MaterialPageRoute(
          builder: (_) => const AdminShopRotationScreen(),
        );
      }

    // Added route for subscriptions screen
      case '/subscriptions':
        return MaterialPageRoute(
          builder: (_) => ShopPage(initialIndex: 2), // 2 is the index for Subscriptions tab
        );

      default:
        return _errorRoute('Route not found: ${settings.name}');
    }
  }

  static Route<dynamic> _errorRoute(String message) {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(child: Text(message)),
      ),
    );
  }
}
