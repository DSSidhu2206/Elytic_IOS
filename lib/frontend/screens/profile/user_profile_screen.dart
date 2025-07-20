// lib/frontend/screens/profile/user_profile_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:elytic/backend/services/friend_service.dart';
import 'package:elytic/backend/services/user_service.dart'; // User info, likes, received count
import 'package:elytic/backend/services/pet_service.dart';  // Main pet info, level, rarity, icon, etc.
import 'package:elytic/frontend/widgets/moderation/moderation_actions_popup.dart';
import 'package:elytic/frontend/widgets/moderation/admin_actions_popup.dart';
import 'package:elytic/frontend/screens/profile/user_profile_action_buttons.dart';
import 'package:elytic/frontend/screens/profile/edit_profile_screen.dart';
import 'package:elytic/frontend/screens/social/dm_room_page.dart';
import 'package:elytic/frontend/widgets/common/username_text.dart';
import 'package:elytic/frontend/helpers/avatar_helper.dart';
import 'package:elytic/frontend/screens/pets/pet_profile_screen.dart';
import 'package:elytic/frontend/widgets/common/elytic_loader.dart';
import 'package:elytic/frontend/widgets/profile/user_main_pet_avatar.dart';
// PATCH: Import profile background widget
import 'package:elytic/frontend/widgets/profile/profile_background_widget.dart';
// PATCH: Import OnlineStatusDot
import 'package:elytic/frontend/widgets/common/online_status_dot.dart';
// PATCH: Import ReceivedItemsPage
import 'package:elytic/frontend/screens/profile/received_items_page.dart';
// PATCH: Import UserLikeCountWidget
import 'package:elytic/frontend/widgets/profile/user_like_count_widget.dart';
// PATCH: Import UserBadgeWidget
import 'package:elytic/frontend/widgets/profile/user_badge_widget.dart';
import 'package:cloud_functions/cloud_functions.dart'; // <-- PATCH: Add this
import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;
  final String currentUserId;
  final int currentUserTier;

  const UserProfileScreen({
    super.key,
    required this.userId,
    required this.currentUserId,
    required this.currentUserTier,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  bool _isLoading = false;
  String? _friendStatus;
  bool _blockedEitherWay = false;
  StreamSubscription? _blockedSub1;
  StreamSubscription? _blockedSub2;
  bool _friendStatusLoaded = true; // PATCH: Set to true immediately
  String? _currentUserUsername;

  UserDisplayInfo? _profileInfo;
  bool _profileLoaded = false;

  PetDisplayInfo? _mainPet;
  bool _petLoaded = false;

  String? _badgeUrl;
  bool _badgeUrlLoaded = false;

  // New: list of current user's friends (userIds)
  List<String> _friendsList = [];
  // New: list of current user's sent friend request userIds
  List<String> _sentFriendRequests = [];

  @override
  void initState() {
    super.initState();
    _fetchCurrentUserUsername();
    _fetchProfileInfo();
    _fetchMainPet();
    _fetchBadgeUrl();
    _startBlockedStatusListener();
    _fetchFriendsList();
    _fetchSentFriendRequests();
    _fetchFriendStatus(); // PATCH: Always fetch status on init!
  }

  Future<void> _fetchFriendsList() async {
    try {
      final friends = await FriendService.fetchFriendUserIds(widget.currentUserId);
      if (!mounted) return;
      setState(() {
        _friendsList = friends;
      });
    } catch (e) {
      // Optionally fallback or ignore
    }
  }

  Future<void> _fetchSentFriendRequests() async {
    try {
      final sentRequests = await FriendService.fetchSentFriendRequestUserIds(widget.currentUserId);
      if (!mounted) return;
      setState(() {
        _sentFriendRequests = sentRequests;
      });
    } catch (e) {
      // Optionally fallback or ignore
    }
  }

  Future<void> _fetchFriendStatus() async {
    final status = await FriendService.getFriendStatus(widget.currentUserId, widget.userId);
    if (!mounted) return;
    setState(() {
      _friendStatus = status;
    });
  }

  Future<void> _fetchCurrentUserUsername() async {
    final info = await UserService.fetchProfileInfo(widget.currentUserId);
    if (!mounted) return;
    setState(() {
      _currentUserUsername = info.username;
    });
  }

  Future<void> _fetchProfileInfo() async {
    if (!mounted) return;
    setState(() {
      _profileLoaded = false;
    });
    final info = await UserService.fetchProfileInfo(widget.userId);
    if (!mounted) return;
    setState(() {
      _profileInfo = info;
      _profileLoaded = true;
    });
  }

  Future<void> _fetchMainPet() async {
    if (!mounted) return;
    setState(() => _petLoaded = false);
    final pet = await PetService.fetchMainPet(widget.userId);
    if (!mounted) return;
    setState(() {
      _mainPet = pet;
      _petLoaded = true;
    });
  }

  Future<void> _fetchBadgeUrl() async {
    final url = await UserService.getUserBadgeUrl(widget.userId);
    if (!mounted) return;
    setState(() {
      _badgeUrl = url;
      _badgeUrlLoaded = true;
    });
  }

  // PATCH: Only listen to blocked status (no friendRequests read)
  void _startBlockedStatusListener() {
    final currentId = widget.currentUserId;
    final targetId = widget.userId;

    // Use Firestore snapshots for blocked status using FriendService's fetchBlockedUsers logic
    _blockedSub1 = FirebaseFirestore.instance
        .collection('users')
        .doc(currentId)
        .collection('blocked')
        .doc(targetId)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      setState(() {
        _blockedEitherWay = snap.exists || _blockedEitherWay;
      });
    });

    _blockedSub2 = FirebaseFirestore.instance
        .collection('users')
        .doc(targetId)
        .collection('blocked')
        .doc(currentId)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      setState(() {
        _blockedEitherWay = snap.exists || _blockedEitherWay;
      });
    });
  }

  @override
  void dispose() {
    _blockedSub1?.cancel();
    _blockedSub2?.cancel();
    super.dispose();
  }

  Future<void> _addFriend() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final scaffold = ScaffoldMessenger.of(context);

    try {
      await FriendService.sendFriendRequest(widget.currentUserId, widget.userId);
      await _fetchFriendStatus(); // PATCH: fetch after request!
      await _fetchSentFriendRequests(); // PATCH: update sent requests list after request
      if (!mounted) return;
      scaffold.showSnackBar(
        const SnackBar(content: Text("Friend request sent!")),
      );
    } catch (e) {
      if (!mounted) return;
      scaffold.showSnackBar(
        SnackBar(content: Text("Failed to send friend request: $e")),
      );
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  Future<void> _unfriend() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final scaffold = ScaffoldMessenger.of(context);

    try {
      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('removeFriend');
      await callable.call({
        'currentUserId': widget.currentUserId,
        'friendId': widget.userId,
      });
      await _fetchFriendStatus(); // PATCH: fetch after remove!
      await _fetchFriendsList(); // PATCH: update friends list after removal
      if (!mounted) return;
      scaffold.showSnackBar(
        const SnackBar(content: Text("Unfriended!")),
      );
    } catch (e) {
      if (!mounted) return;
      scaffold.showSnackBar(
        SnackBar(content: Text("Failed to unfriend: $e")),
      );
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  Future<void> _block() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final scaffold = ScaffoldMessenger.of(context);

    try {
      await FriendService.blockUser(widget.currentUserId, widget.userId);
      if (!mounted) return;
      scaffold.showSnackBar(
        const SnackBar(content: Text("User blocked.")),
      );
    } catch (e) {
      if (!mounted) return;
      scaffold.showSnackBar(
        SnackBar(content: Text("Failed to block: $e")),
      );
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  Future<void> _unblock() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final scaffold = ScaffoldMessenger.of(context);

    try {
      await FriendService.unblockUser(widget.currentUserId, widget.userId);
      if (!mounted) return;
      scaffold.showSnackBar(
        const SnackBar(content: Text("User unblocked.")),
      );
    } catch (e) {
      if (!mounted) return;
      scaffold.showSnackBar(
        SnackBar(content: Text("Failed to unblock: $e")),
      );
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  void _messageUser(UserDisplayInfo userInfo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DMRoomPage(
          otherUserId: widget.userId,
          otherUserName: userInfo.username,
          otherUserAvatar: userInfo.avatarUrl,
          readReceiptsEnabled: true,
        ),
      ),
    );
  }

  void _openPetProfile() {
    if (_mainPet == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PetProfileScreen(
          userId: widget.userId,
          petId: _mainPet!.petId,
          petName: _mainPet!.name,
          petAvatar: _mainPet!.iconUrl,
          isCurrentUser: widget.currentUserId == widget.userId,
          currentUserId: widget.currentUserId,
          currentUserTier: widget.currentUserTier,
          currentUserUsername: _currentUserUsername ?? widget.currentUserId,
        ),
      ),
    );
  }

  // Opens a constrained preview of the banner at 200px height
  void _showBackgroundPreview() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: EdgeInsets.zero,
        backgroundColor: Colors.transparent,
        child: SizedBox(
          width: double.infinity,
          height: 200,
          child: ProfileBackgroundWidget(
            userId: widget.userId,
            isCurrentUser: widget.currentUserId == widget.userId,
          ),
        ),
      ),
    );
  }

  // Edit profile, via pencil icon
  void _openEditProfileScreen(UserDisplayInfo userInfo) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(userId: widget.currentUserId),
      ),
    );
  }

  // PATCH: Open received items page
  void _openReceivedItemsPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReceivedItemsPage(
          userId: widget.userId,
        ),
      ),
    );
  }

  String getDisplayFriendStatus() {
    if (_friendsList.contains(widget.userId)) {
      return 'accepted';
    }
    if (_sentFriendRequests.contains(widget.userId)) {
      return 'pending';
    }
    return _friendStatus ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final isOwnProfile = widget.currentUserId == widget.userId;
    final isFriend = _friendsList.contains(widget.userId);

    if (!_profileLoaded || !_petLoaded || !_badgeUrlLoaded) {
      return const Scaffold(
        body: Center(child: ElyticLoader()),
      );
    }

    final info = _profileInfo!;
    final targetTier = info.tier;
    final targetUsername = info.username;
    final targetAvatarPath = info.avatarUrl;
    final targetBio = (info.bio.isEmpty) ? 'no bio' : info.bio;

    final avatarProvider = getAvatarImageProvider(targetAvatarPath);
    final borderProvider = (info.currentBorderUrl.isNotEmpty)
        ? getBorderImageProvider(info.currentBorderUrl)
        : null;

    // Pet logic (from PetService cache)
    ImageProvider? petAvatarProvider;
    int? mainPetLevel;
    String? petRarity;
    if (_mainPet != null) {
      if (_mainPet!.iconUrl.isNotEmpty) {
        petAvatarProvider = getAvatarImageProvider(_mainPet!.iconUrl);
      }
      mainPetLevel = _mainPet!.level;
      petRarity = _mainPet!.rarity;
    }

    return Scaffold(
      appBar: AppBar(
        title: SizedBox(
          width: 210,
          child: UsernameText(
            username: targetUsername,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.black),
            textAlign: TextAlign.center,
          ),
        ),
        backgroundColor: Colors.white,
        centerTitle: true,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: isOwnProfile
            ? [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _openEditProfileScreen(info),
            tooltip: 'Edit Profile',
          ),
        ]
            : null,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // HEADER STACK
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                GestureDetector(
                  onTap: isOwnProfile ? _showBackgroundPreview : null,
                  child: SizedBox(
                    width: double.infinity,
                    height: 200,
                    child: ProfileBackgroundWidget(
                      userId: widget.userId,
                      isCurrentUser: isOwnProfile,
                    ),
                  ),
                ),
                Positioned(
                  bottom: -60,
                  child: SizedBox(
                    width: 180,
                    height: 180,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        CircleAvatar(
                          radius: 70,
                          backgroundImage: avatarProvider,
                          backgroundColor: Colors.grey[200],
                          child:
                          avatarProvider == null ? const Icon(Icons.person, size: 70) : null,
                        ),
                        if (borderProvider != null)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                image: DecorationImage(
                                  image: borderProvider,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          top: 25,
                          right: 25,
                          child: OnlineStatusDot(userId: widget.userId),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),

            // --- LIKE & BADGE WIDGET ROW: left, right below avatar, above bio ---
            Padding(
              padding: const EdgeInsets.only(left: 1, right: 1, bottom: 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Heart/like widget - LEFT
                  UserLikeCountWidget(
                    userId: widget.userId,
                    currentUserId: widget.currentUserId,
                    size: 80,
                    countStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 35,
                      color: Colors.white,
                    ),
                  ),
                  // Badge widget - RIGHT (moved from gifted subs)
                  UserBadgeWidget(
                    badgeUrl: _badgeUrl,
                    size: 100,
                  ),
                ],
              ),
            ),

            // --- BIO ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 25.0),
              child: Text(
                targetBio,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),

            // PET AVATAR + LEVEL + RECEIVED ITEMS COUNT (all logic passed from services/caches)
            UserMainPetAvatar(
              imageProvider: petAvatarProvider,
              onPetTap: _openPetProfile,
              onReceivedItemsTap: _openReceivedItemsPage,
              isOwnProfile: isOwnProfile,
              size: 120,
              level: mainPetLevel,
              receivedItemsCount: info.receivedItemsCount,
              petRarity: petRarity, // <- PATCH: CORRECT PARAMETER NAME!
            ),

            const SizedBox(height: 24),

            if (!isOwnProfile)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6),
                child: UserProfileActionButtons(
                  isLoading: _isLoading,
                  friendStatus: getDisplayFriendStatus(),
                  onAddFriend: (!_blockedEitherWay &&
                      !_isLoading &&
                      getDisplayFriendStatus() != 'accepted' &&
                      getDisplayFriendStatus() != 'pending')
                      ? () => _addFriend()
                      : null,
                  onUnfriend: isFriend ? () => _unfriend() : () {},
                  onBlock: _blockedEitherWay ? () => _unblock() : () => _block(),
                  onMessageUser: _blockedEitherWay ? null : () => _messageUser(info),
                  currentUserId: widget.currentUserId,
                  targetUserId: widget.userId,
                  profileData: const {},
                  isBlocked: _blockedEitherWay,
                  friendsList: _friendsList,
                  sentFriendRequests: _sentFriendRequests,
                ),
              ),
            if (!isOwnProfile && widget.currentUserTier >= 4 && targetTier < 4)
              ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => ModerationActionsPopup(
                      modUserId: widget.currentUserId,
                      modUsername: _currentUserUsername ?? "",
                      modTier: widget.currentUserTier,
                      targetUser: info,
                      onClose: () => Navigator.of(context).pop(),
                    ),
                  );
                },
                child: const Text('Moderation Settings'),
              ),
            if (!isOwnProfile && widget.currentUserTier == 6)
              ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => AdminActionsPopup(
                      targetUserId: widget.userId,
                      targetUsername: targetUsername,
                      currentAdminAvatar: _profileInfo?.avatarUrl ?? '',
                      currentAdminUsername: _currentUserUsername ?? '',
                    ),
                  );
                },
                child: const Text('Admin Options'),
              ),
            const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }
}
