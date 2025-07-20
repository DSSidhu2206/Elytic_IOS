// lib/frontend/app/fcm_initializer.dart

import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FcmInitializer extends StatefulWidget {
  final Widget child;
  const FcmInitializer({ required this.child, Key? key }) : super(key: key);

  @override
  _FcmInitializerState createState() => _FcmInitializerState();
}

class _FcmInitializerState extends State<FcmInitializer> {
  @override
  void initState() {
    super.initState();
    _uploadFcmToken();
    _listenForTokenRefresh();

    // IMPORTANT: Disable system notification display on foreground messages
    FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: false,
      sound: false,
    );

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // No system notification here to avoid duplicates.
      // Your NotificationListenerWidget will handle in-app UI.
    });
  }

  Future<void> _uploadFcmToken() async {
    try {
      String? newToken = await FirebaseMessaging.instance.getToken();
      final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (newToken != null && currentUserId != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .collection('fcmTokens')
            .doc(newToken)
            .set({
          'createdAt': FieldValue.serverTimestamp(),
          'platform': Theme.of(context).platform.toString(),
        });
      }
    } catch (e) {
    }
  }

  void _listenForTokenRefresh() {
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (newToken != null && currentUserId != null) {
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUserId)
              .collection('fcmTokens')
              .doc(newToken)
              .set({
            'createdAt': FieldValue.serverTimestamp(),
            'platform': Theme.of(context).platform.toString(),
          });
        } catch (e) {
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
