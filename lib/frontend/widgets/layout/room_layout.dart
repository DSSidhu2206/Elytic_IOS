// lib/frontend/widgets/layout/room_layout.dart

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // PATCH
import 'package:elytic/frontend/screens/chat/chat_screen.dart';
import 'package:elytic/frontend/widgets/chat/message_input.dart';
import 'package:elytic/frontend/widgets/layout/lounge_area.dart';
import 'package:elytic/frontend/screens/profile/user_profile_screen.dart';
import 'package:elytic/frontend/widgets/appbars/custom_appbar.dart';
import 'package:elytic/frontend/screens/home/category_tabs_screen.dart';
import 'package:elytic/frontend/widgets/common/elytic_loader.dart';
import 'package:elytic/backend/services/chat_service.dart';
import 'package:elytic/backend/services/presence_service.dart';
import 'package:elytic/frontend/screens/settings/settings_screen.dart';
import 'package:elytic/frontend/screens/social/dm_list_page.dart';
import 'package:elytic/frontend/screens/social/friends_page.dart';
import 'package:elytic/backend/services/user_service.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Added import

// Added imports for news popup
import '../../widgets/news/news_dialog.dart';
import '../../models/news_service.dart';

class RoomLayout extends StatefulWidget {
  final String roomId;
  final String displayName;
  final String userName;
  final String userImageUrl;
  final String currentUserId;
  final int currentUserTier;
  final bool? isVIP; // PATCHED

  const RoomLayout({
    Key? key,
    required this.roomId,
    required this.displayName,
    required this.userName,
    required this.userImageUrl,
    required this.currentUserId,
    required this.currentUserTier,
    this.isVIP, // PATCHED
  }) : super(key: key);

  @override
  _RoomLayoutState createState() => _RoomLayoutState();
}

class _RoomLayoutState extends State<RoomLayout> {
  late final DatabaseReference _presenceRef;
  bool _isLoading = false;
  bool _isVIPRoom = false; // PATCHED

  // Added field to prevent multiple news dialogs
  bool _newsChecked = false;

  @override
  void initState() {
    super.initState();

    final random = Random();

    if (widget.isVIP != null) {
      _isVIPRoom = widget.isVIP!;
    } else {
      _checkIfRoomIsVIP(); // PATCHED
    }

    Future.microtask(() async {
      final prefs = await SharedPreferences.getInstance();
      final sessionId = prefs.getString('sessionId') ?? '';

      final displayInfo = await UserService.fetchDisplayInfo(widget.currentUserId);
      await PresenceService.setupRoomPresence(
        userId: widget.currentUserId,
        roomId: widget.roomId,
        userName: displayInfo.username,
        avatarUrl: displayInfo.avatarUrl,
        userAvatarBorderUrl: displayInfo.currentBorderUrl,
        tier: displayInfo.tier,
        x: random.nextDouble(),
        y: random.nextDouble(),
      );
    });

    _presenceRef = FirebaseDatabase.instance
        .ref('presence/${widget.roomId}/${widget.currentUserId}');

    // Added post-frame callback to show news popup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_newsChecked) {
        _newsChecked = true;
        _checkAndShowNews();
      }
    });
  }

  Future<void> _checkIfRoomIsVIP() async {
    try {
      final vipDoc = await FirebaseFirestore.instance
          .collection('vip_rooms')
          .doc(widget.roomId)
          .get();
      if (mounted) {
        setState(() {
          _isVIPRoom = vipDoc.exists;
        });
      }
    } catch (_) {
      // Fallback silently
    }
  }

  // Removed _leaveCurrentRoom method since no longer needed

  // Modified: only show dialog, do NOT update lastSeen here
  Future<void> _checkAndShowNews() async {
    final lastSeen = (await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.currentUserId)
        .get())
        .data()?['lastSeenNewsVersion'] as int? ?? 0;

    final news = await NewsService.fetchNewsSince(lastSeen);
    if (news.isNotEmpty) {
      await showDialog(
        context: context,
        builder: (_) => NewsDialog(
          items: news,
          currentUserId: widget.currentUserId,
        ),
      );
    }
  }

  @override
  void dispose() {
    ChatService.leaveRoom(widget.roomId);
    _presenceRef.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        roomName: widget.displayName,
        onShopTap: () {
          Navigator.pushNamed(context, '/shop');
        },
        onRoomNameTap: () async {
          // Removed loading and leaving room logic here per patch request
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CategoryTabsScreen()),
          );
        },
        onMessagesTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DmListPage(
                currentUserId: widget.currentUserId,
              ),
            ),
          );
        },
        onFriendsTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FriendsPage(
                currentUserId: widget.currentUserId,
                currentUserTier: widget.currentUserTier,
              ),
            ),
          );
        },
        onSettingsTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          );
        },
        currentUserId: widget.currentUserId,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              if (_isVIPRoom)
                Container(
                  width: double.infinity,
                  color: Colors.amber.shade100,
                  padding: const EdgeInsets.all(8),
                  child: const Text(
                    '🌟 This is a VIP Room!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              Expanded(
                flex: 1,
                child: ChatScreen(
                  roomId: widget.roomId,
                  currentUserId: widget.currentUserId,
                  userName: widget.userName,
                  userImageUrl: widget.userImageUrl,
                  currentUserTier: widget.currentUserTier,
                ),
              ),
              Expanded(
                flex: 1,
                child: LoungeArea(
                  roomId: widget.roomId,
                  currentUserId: widget.currentUserId,
                  currentUserName: widget.userName,
                  currentUserAvatarUrl: widget.userImageUrl,
                  currentUserTier: widget.currentUserTier,
                  onUserMoved: (updated) {
                    final ref = FirebaseDatabase.instance
                        .ref('presence/${widget.roomId}/${updated.userId}');
                    ref.update({
                      'x': updated.x,
                      'y': updated.y,
                      'last_changed': DateTime.now().millisecondsSinceEpoch,
                    });
                  },
                  onAvatarTap: (tappedId, _) {
                    if (tappedId == widget.currentUserId) return;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => UserProfileScreen(
                          userId: tappedId,
                          currentUserId: widget.currentUserId,
                          currentUserTier: widget.currentUserTier,
                        ),
                      ),
                    );
                  },
                ),
              ),
              MessageInput(
                roomId: widget.roomId,
                currentUserId: widget.currentUserId,
                currentUserTier: widget.currentUserTier,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
