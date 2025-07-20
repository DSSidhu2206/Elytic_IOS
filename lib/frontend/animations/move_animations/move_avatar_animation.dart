// lib/frontend/animations/move_animations/move_avatar_animation.dart

import 'package:flutter/material.dart';

/// Animates an avatar moving smoothly from one position to another
/// with a natural “start slow → speed up → slow down” effect.
class MoveAvatarAnimation extends StatefulWidget {
  /// Unique user ID (for keys, not used in animation logic).
  final String userId;

  /// Target absolute position (pixels) where the avatar should end up.
  final Offset position;

  /// Size of the avatar (pixels).
  final double size;

  /// The avatar widget (e.g. a CircleAvatar).
  final Widget avatar;

  /// Called when the movement animation completes.
  final VoidCallback onAnimationComplete;

  const MoveAvatarAnimation({
    Key? key,
    required this.userId,
    required this.position,
    required this.size,
    required this.avatar,
    required this.onAnimationComplete,
  }) : super(key: key);

  @override
  _MoveAvatarAnimationState createState() => _MoveAvatarAnimationState();
}

class _MoveAvatarAnimationState extends State<MoveAvatarAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<Offset> _offsetAnim;
  Offset? _previousPosition;

  @override
  void initState() {
    super.initState();
    // Initialize controller for a half‐second animation
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    // Set initial previousPosition so first build draws at target
    _previousPosition = widget.position;
    _buildAnimation();
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant MoveAvatarAnimation old) {
    super.didUpdateWidget(old);
    // If the target position has changed, rebuild the tween and rerun
    if (widget.position != _previousPosition) {
      _previousPosition = old.position;
      _buildAnimation();
      _controller
        ..reset()
        ..forward();
    }
  }

  void _buildAnimation() {
    _offsetAnim = Tween<Offset>(
      begin: _previousPosition!,
      end: widget.position,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onAnimationComplete();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _offsetAnim,
      builder: (context, child) {
        return Positioned(
          left: _offsetAnim.value.dx,
          top: _offsetAnim.value.dy,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: widget.avatar,
          ),
        );
      },
    );
  }
}
