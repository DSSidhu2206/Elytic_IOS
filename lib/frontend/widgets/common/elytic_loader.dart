// lib/frontend/widgets/common/elytic_loader.dart

import 'dart:math';
import 'package:flutter/material.dart';

class ElyticLoader extends StatelessWidget {
  final String text;
  final int tier;

  const ElyticLoader({
    Key? key,
    this.text = '',
    this.tier = 0,
  }) : super(key: key);

  Color _getTierColor() {
    switch (tier) {
      case 1:
        return const Color(0xFFCD7F32); // Bronze
      case 2:
        return const Color(0xFFC0C0C0); // Silver
      case 3:
        return const Color(0xFFFFD700); // Gold
      case 4:
        return const Color(0xFFFF9800); // Orange
      case 5:
        return const Color(0xFF9C27B0); // Purple
      default:
        return Colors.black; // Tier 0
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = _getTierColor();

    return Stack(
      children: [
        ModalBarrier(
          color: Colors.black.withOpacity(0.5),
          dismissible: false,
        ),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PulsingEWithSparkles(primary: primaryColor),
              if (text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Text(
                    text,
                    style: const TextStyle(
                      color: Colors.black, // Always black
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                      decoration: TextDecoration.none,
                    ),
                    overflow: TextOverflow.visible,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PulsingEWithSparkles extends StatefulWidget {
  final Color primary;

  const _PulsingEWithSparkles({Key? key, required this.primary}) : super(key: key);

  @override
  State<_PulsingEWithSparkles> createState() => _PulsingEWithSparklesState();
}

class _PulsingEWithSparklesState extends State<_PulsingEWithSparkles>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final int sparkleCount = 16;
  final List<_Sparkle> _sparkles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1100),
      vsync: this,
    )..repeat();

    _generateSparkles();
  }

  void _generateSparkles() {
    _sparkles.clear();
    for (int i = 0; i < sparkleCount; i++) {
      final angle = _random.nextDouble() * 2 * pi;
      final radius = 38 + _random.nextDouble() * 15;
      final delay = _random.nextDouble();
      final size = 4.0 + _random.nextDouble() * 3.0;
      _sparkles.add(_Sparkle(angle, radius, delay, size));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = widget.primary;

    return SizedBox(
      width: 110,
      height: 110,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final scale = 0.95 + 0.15 * (1 + sin(_controller.value * 2 * pi)) / 2;

          return Stack(
            alignment: Alignment.center,
            children: [
              // Sparkles
              ..._sparkles.map((sparkle) {
                final t = ((_controller.value + sparkle.delay) % 1.0);
                final opacity = (t < 0.7) ? (1 - t / 0.7) : 0.0;
                final rad = sparkle.radius + 12 * t;
                final dx = rad * cos(sparkle.angle);
                final dy = rad * sin(sparkle.angle);

                return Positioned(
                  left: 55 + dx - sparkle.size / 2,
                  top: 55 + dy - sparkle.size / 2,
                  child: Opacity(
                    opacity: opacity,
                    child: Container(
                      width: sparkle.size,
                      height: sparkle.size,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: primary.withOpacity(0.28),
                            blurRadius: 6,
                            spreadRadius: 0.5,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              // The pulsing E letter
              Transform.scale(
                scale: scale,
                child: Text(
                  'E',
                  style: TextStyle(
                    fontSize: 70,
                    color: primary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.1,
                    decoration: TextDecoration.none,
                    shadows: [
                      Shadow(
                        color: primary.withOpacity(0.5),
                        blurRadius: 16,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Sparkle {
  final double angle;
  final double radius;
  final double delay;
  final double size;

  _Sparkle(this.angle, this.radius, this.delay, this.size);
}
