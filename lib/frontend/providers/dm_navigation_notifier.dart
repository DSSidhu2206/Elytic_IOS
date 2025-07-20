import 'package:flutter/material.dart';

class DmNavigationNotifier extends ChangeNotifier {
  String? recipientUserId;
  String? recipientUserName;
  String? recipientAvatar;

  void composeNewMessage({required String userId, required String userName, required String avatar}) {
    recipientUserId = userId;
    recipientUserName = userName;
    recipientAvatar = avatar;
    notifyListeners();
  }

  void clear() {
    recipientUserId = null;
    recipientUserName = null;
    recipientAvatar = null;
    notifyListeners();
  }
}
