// lib/frontend/widgets/profile/user_like_count_widget.dart

import 'package:flutter/material.dart';
import 'package:elytic/backend/services/user_service.dart';

class UserLikeCountWidget extends StatefulWidget {
  final String userId;
  final String? currentUserId; // Pass this in for safety!
  final double size;
  final TextStyle? countStyle;

  const UserLikeCountWidget({
    Key? key,
    required this.userId,
    this.currentUserId,
    this.size = 48,
    this.countStyle,
  }) : super(key: key);

  @override
  State<UserLikeCountWidget> createState() => _UserLikeCountWidgetState();
}

class _UserLikeCountWidgetState extends State<UserLikeCountWidget>
    with SingleTickerProviderStateMixin {
  bool _hasLiked = false;
  bool _loading = true;
  bool _likingInProgress = false;
  int _optimisticCount = 0;

  late AnimationController _controller;
  late Animation<double> _iconScale;

  @override
  void initState() {
    super.initState();
    _loadInitialState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _iconScale = Tween<double>(begin: 1.0, end: 1.13).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadInitialState() async {
    final currentUserId = widget.currentUserId;
    if (currentUserId == null) return;
    final liked = await UserService.hasUserLiked(widget.userId, currentUserId: currentUserId);
    if (mounted) {
      setState(() {
        _hasLiked = liked;
        _loading = false;
      });
    }
  }

  Future<void> _handleLike(int currentCount) async {
    if (_hasLiked) return; // prevent double-like

    setState(() {
      _likingInProgress = true;
      // Optimistic UI
      _hasLiked = true;
      _optimisticCount = currentCount + 1;
    });

    // Animate
    _controller
      ..reset()
      ..forward();

    // Show "Profile liked" snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile liked'),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );

    try {
      final result = await UserService.likeUser(widget.userId);
      if (result['status'] == 'alreadyLiked') {
        // Rollback optimistic if already liked (shouldn't happen)
        setState(() {
          _optimisticCount = currentCount; // revert
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You have already liked this user.'),
            duration: Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      // Rollback optimistic if error
      setState(() {
        _hasLiked = false;
        _optimisticCount = currentCount;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong.'),
          duration: Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() => _likingInProgress = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwnProfile = widget.currentUserId == widget.userId;

    if (_loading) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return StreamBuilder<int>(
      stream: UserService.likeCountStream(widget.userId),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        final displayCount = (_hasLiked && _optimisticCount > count) ? _optimisticCount : count;
        final heartImage = 'assets/icons/like_heart.png';

        final displayHeart = SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Image.asset(
                heartImage,
                width: widget.size,
                height: widget.size,
                fit: BoxFit.contain,
              ),
              Center(
                child: Text(
                  '$displayCount',
                  style: widget.countStyle ??
                      TextStyle(
                        fontSize: widget.size * 0.75,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            blurRadius: 2,
                            color: Colors.black.withOpacity(0.16),
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                ),
              ),
            ],
          ),
        );

        if (isOwnProfile) {
          return displayHeart;
        }

        // Others' profile: tappable, animate on like, disabled if already liked
        return GestureDetector(
          onTap: (_hasLiked || _likingInProgress)
              ? null
              : () => _handleLike(count),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: (_hasLiked || _likingInProgress) ? 0.85 : 1.0,
            child: Tooltip(
              message: _hasLiked
                  ? "You liked this profile"
                  : "Like this user",
              child: ScaleTransition(
                scale: _iconScale,
                child: displayHeart,
              ),
            ),
          ),
        );
      },
    );
  }
}
