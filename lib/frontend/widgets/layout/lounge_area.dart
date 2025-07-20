// lib/frontend/widgets/layout/lounge_area.dart

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
// PATCH: Import AvatarWithBorder
import 'package:elytic/frontend/widgets/common/avatar_with_border.dart';
// PATCH: Import Firebase Firestore for asset fetching
import 'package:cloud_firestore/cloud_firestore.dart';
// PATCH: Import cached_network_image
import 'package:cached_network_image/cached_network_image.dart';

class LoungeUser {
  final String userId;
  final double x, y;
  final int tier;
  final String avatarUrl, userName;
  final String? userAvatarBorderUrl; // PATCH
  final String? activeItemId; // PATCH: Add activeItemId for overlay

  LoungeUser({
    required this.userId,
    required this.x,
    required this.y,
    required this.tier,
    required this.avatarUrl,
    required this.userName,
    this.userAvatarBorderUrl, // PATCH
    this.activeItemId, // PATCH
  });
}

class Avatar extends StatefulWidget {
  final LoungeUser user;
  final Size containerSize;
  final bool isCurrentUser;
  final bool playJoinAnimation;
  final void Function(TapUpDetails) onTapUp;

  const Avatar({
    Key? key,
    required this.user,
    required this.containerSize,
    required this.onTapUp,
    required this.isCurrentUser,
    required this.playJoinAnimation,
  }) : super(key: key);

  @override
  AvatarState createState() => AvatarState();
}

class AvatarState extends State<Avatar> with SingleTickerProviderStateMixin {
  late double _x, _y;
  bool _show = false;
  AnimationController? _joinCtrl;
  bool _hasAnimatedJoin = false;

  // PATCH: Cache for item asset URLs
  static final Map<String, String?> _itemAssetCache = {};

  String? _activeItemUrl;
  bool _loadingActiveItem = false;

  // PATCH: Keep last avatar url with cache buster to avoid rebuilding unnecessarily
  String? _lastAvatarUrlWithCacheBuster;
  String? _lastRawAvatarUrl;

  @override
  void initState() {
    super.initState();

    const padding = 0.10;
    _x = widget.user.x.clamp(padding, 1 - padding);
    _y = widget.user.y.clamp(padding, 1 - padding);

    if (widget.playJoinAnimation && !_hasAnimatedJoin) {
      _show = true;
      _hasAnimatedJoin = true;
      _joinCtrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 800),
      )..forward();
    } else {
      _show = true;
    }

    // PATCH: Load active item assetUrl if needed
    if (widget.user.activeItemId != null && widget.user.activeItemId!.isNotEmpty) {
      _fetchActiveItemUrl(widget.user.activeItemId!);
    }

    _updateAvatarUrlCacheBuster();
  }

  @override
  void didUpdateWidget(covariant Avatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    const padding = 0.10;
    final newX = widget.user.x.clamp(padding, 1 - padding);
    final newY = widget.user.y.clamp(padding, 1 - padding);

    if (newX != _x || newY != _y) {
      setState(() {
        _x = newX;
        _y = newY;
      });
    }

    // PATCH: Refetch active item if it changed
    if (widget.user.activeItemId != oldWidget.user.activeItemId) {
      if (widget.user.activeItemId != null && widget.user.activeItemId!.isNotEmpty) {
        _fetchActiveItemUrl(widget.user.activeItemId!);
      } else {
        setState(() => _activeItemUrl = null);
      }
    }

    _updateAvatarUrlCacheBuster();
  }

  void _updateAvatarUrlCacheBuster() {
    final baseUrl = widget.user.avatarUrl;
    if (baseUrl.isEmpty) {
      _lastAvatarUrlWithCacheBuster = baseUrl;
      _lastRawAvatarUrl = baseUrl;
      return;
    }
    if (baseUrl != _lastRawAvatarUrl) {
      // Only update cache buster if base avatar URL changed
      final separator = baseUrl.contains('?') ? '&' : '?';
      final newUrl = '$baseUrl${separator}v=${DateTime.now().millisecondsSinceEpoch}';
      setState(() {
        _lastAvatarUrlWithCacheBuster = newUrl;
        _lastRawAvatarUrl = baseUrl;
      });
    }
    // else: do nothing, keep old cache buster url to avoid unnecessary reloads
  }

  Future<void> _fetchActiveItemUrl(String itemId) async {
    if (_itemAssetCache.containsKey(itemId)) {
      setState(() {
        _activeItemUrl = _itemAssetCache[itemId];
      });
      return;
    }
    setState(() {
      _loadingActiveItem = true;
    });
    try {
      final doc = await FirebaseFirestore.instance.collection('item_data').doc(itemId).get();
      final url = (doc.data()?['assetUrl'] ?? '') as String;
      _itemAssetCache[itemId] = url;
      if (mounted) {
        setState(() {
          _activeItemUrl = url;
          _loadingActiveItem = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _activeItemUrl = null;
          _loadingActiveItem = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _joinCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.user.tier >= 2 ? 90.0 : 70.0;

    final dx = _x * widget.containerSize.width - size * 0.75; // center avatar+border
    final dy = _y * widget.containerSize.height - size * 0.75;

    if (!_show && widget.isCurrentUser) return const SizedBox.shrink();

    Widget avatarChild = Stack(
      clipBehavior: Clip.none,
      children: [
        AvatarWithBorder(
          avatarPath: _lastAvatarUrlWithCacheBuster ?? widget.user.avatarUrl,
          borderUrl: widget.user.userAvatarBorderUrl,
          size: size,
        ),
        // PATCH: Show the user's active item at bottom right, over avatar+border (transparent PNG, 1.75x previous size)
        if (_activeItemUrl != null && _activeItemUrl!.isNotEmpty)
          Positioned(
            bottom: -8,
            right: -8,
            child: SizedBox(
              width: size * 0.665,
              height: size * 0.665,
              child: CachedNetworkImage(
                imageUrl: _activeItemUrl!,
                fit: BoxFit.cover,
                errorWidget: (ctx, err, st) => Icon(Icons.inventory_2, color: Colors.grey[400]),
                placeholder: (ctx, url) => const SizedBox(
                  width: 24,
                  height: 24,
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              ),
            ),
          ),
      ],
    );

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
      left: dx,
      top: dy,
      width: size * 1.5,
      height: size * 1.5,
      child: GestureDetector(
        onTapUp: (details) {
          if (widget.isCurrentUser) {
            Navigator.of(context).pushNamed(
              '/user_profile',
              arguments: {
                'userId': widget.user.userId,
                'currentUserId': widget.user.userId,
                'currentUserTier': widget.user.tier,
              },
            );
          } else {
            widget.onTapUp(details);
          }
        },
        child: widget.playJoinAnimation && _joinCtrl != null && !_joinCtrl!.isCompleted
            ? ScaleTransition(
          scale: CurvedAnimation(
            parent: _joinCtrl!,
            curve: Curves.elasticOut,
          ),
          child: avatarChild,
        )
            : avatarChild,
      ),
    );
  }
}

class LoungeArea extends StatefulWidget {
  final String roomId;
  final String currentUserId;
  final String currentUserName;
  final String currentUserAvatarUrl;
  final int currentUserTier;
  final void Function(LoungeUser updated)? onUserMoved;
  final void Function(String tappedUserId, Offset globalTap)? onAvatarTap;

  const LoungeArea({
    Key? key,
    required this.roomId,
    required this.currentUserId,
    required this.currentUserName,
    required this.currentUserAvatarUrl,
    required this.currentUserTier,
    this.onUserMoved,
    this.onAvatarTap,
  }) : super(key: key);

  @override
  State<LoungeArea> createState() => _LoungeAreaState();
}

class _LoungeAreaState extends State<LoungeArea> {
  final Map<String, Map<String, dynamic>> _presenceData = {};
  // PATCH: Use GlobalKey (no type argument)
  final Map<String, GlobalKey> _avatarKeys = {};
  late final DatabaseReference _presenceRef;
  late final StreamSubscription<DatabaseEvent> _presenceSub;
  Set<String> _seenUsers = {};

  @override
  void initState() {
    super.initState();
    _presenceRef = FirebaseDatabase.instance.ref('presence/${widget.roomId}');
    _presenceSub = _presenceRef.onValue.listen(_onPresenceUpdate);
  }

  void _onPresenceUpdate(DatabaseEvent event) {
    final data = event.snapshot.value as Map?;
    if (data == null) {
      setState(() {
        _presenceData.clear();
      });
      return;
    }
    final random = Random();
    final Map<String, Map<String, dynamic>> newPresence = {};

    for (final entry in data.entries) {
      final uid = entry.key;
      final v = entry.value;
      if (v is! Map) continue;

      final state = v['state'];
      final lastChanged = v['last_changed'];

      if (state != 'online' || lastChanged == null) {
        continue;
      }

      const padding = 0.10;
      final rawX = (v['x'] as num?)?.toDouble() ?? random.nextDouble();
      final rawY = (v['y'] as num?)?.toDouble() ?? random.nextDouble();
      final x = rawX.clamp(padding, 1 - padding);
      final y = rawY.clamp(padding, 1 - padding);

      newPresence[uid] = Map<String, dynamic>.from(v);
      newPresence[uid]!['x'] = x;
      newPresence[uid]!['y'] = y;
    }

    setState(() {
      _presenceData
        ..clear()
        ..addAll(newPresence);
    });
  }

  @override
  void dispose() {
    _presenceSub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, bc) {
      final children = <Widget>[];
      final keysNow = _presenceData.keys.toSet();

      for (final userId in _presenceData.keys) {
        final p = _presenceData[userId]!;
        final x = (p['x'] as num?)?.toDouble() ?? 0.5;
        final y = (p['y'] as num?)?.toDouble() ?? 0.5;
        final avatarUrl = p['avatarUrl'] ?? '';
        final userName = p['userName'] ?? '';
        final tier = p['tier'] is int
            ? p['tier']
            : int.tryParse(p['tier']?.toString() ?? '') ?? 1;
        // PATCH: Pull border url from RTDB if present
        final borderUrl = p['userAvatarBorderUrl'] as String? ?? '';
        // PATCH: Pull active item id from RTDB if present
        final activeItemId = p['activeItemId'] as String? ?? '';

        final isJoin = !_seenUsers.contains(userId);
        if (isJoin) _seenUsers.add(userId);
        final key = _avatarKeys.putIfAbsent(userId, () => GlobalKey());

        children.add(Avatar(
          key: key,
          user: LoungeUser(
            userId: userId,
            x: x,
            y: y,
            avatarUrl: avatarUrl,
            userName: userName,
            tier: tier,
            userAvatarBorderUrl: borderUrl, // PATCH
            activeItemId: activeItemId, // PATCH
          ),
          containerSize: Size(bc.maxWidth, bc.maxHeight),
          isCurrentUser: userId == widget.currentUserId,
          playJoinAnimation: isJoin,
          onTapUp: (d) {
            if (widget.onAvatarTap != null && userId != widget.currentUserId) {
              widget.onAvatarTap!(userId, d.globalPosition);
            }
          },
        ));
      }

      _seenUsers = _seenUsers.intersection(keysNow);

      return Container(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.black
            : Colors.pink[50],
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) {
            final RenderBox box = ctx.findRenderObject() as RenderBox;
            final local = box.globalToLocal(details.globalPosition);
            final avatarSize = widget.currentUserTier >= 2 ? 65.0 : 50.0;

            final nx = (local.dx / bc.maxWidth)
                .clamp(avatarSize / 2 / bc.maxWidth, 1 - avatarSize / 2 / bc.maxWidth);
            final ny = (local.dy / bc.maxHeight)
                .clamp(avatarSize / 2 / bc.maxHeight, 1 - avatarSize / 2 / bc.maxHeight);

            widget.onUserMoved?.call(LoungeUser(
              userId: widget.currentUserId,
              x: nx,
              y: ny,
              tier: widget.currentUserTier,
              avatarUrl: widget.currentUserAvatarUrl,
              userName: widget.currentUserName,
              userAvatarBorderUrl: '', // PATCH: Could pass currentUser border if desired
              activeItemId: '', // PATCH
            ));
          },
          child: Stack(children: children),
        ),
      );
    });
  }
}

class AvatarShimmer extends StatelessWidget {
  final double x, y;

  const AvatarShimmer({Key? key, required this.x, required this.y}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final size = 70.0;
    final containerSize = MediaQuery.of(context).size;
    final dx = x * (containerSize.width - size);
    final dy = y * (containerSize.height - size);

    return Positioned(
      left: dx,
      top: dy,
      width: size,
      height: size,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
    );
  }
}
