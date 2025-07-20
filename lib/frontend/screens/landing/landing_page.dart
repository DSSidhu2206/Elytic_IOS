// lib/frontend/screens/landing/landing_page.dart

import 'dart:math';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Landing page with a lively area of drifting avatars and three consistent buttons.
class LandingPage extends StatefulWidget {
  const LandingPage({Key? key}) : super(key: key);

  @override
  _LandingPageState createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: _buildLandingContent(context),
      ),
    );
  }

  Widget _buildLandingContent(BuildContext context) {
    final avatarPaths = List.generate(
      10,
          (i) => 'assets/avatars/avatar_${i + 1}.png',
    );

    return Column(
      children: [
        const SizedBox(height: 20),
        const Text(
          'Elytic',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          flex: 6,
          child: LayoutBuilder(
            builder: (context, constraints) => Stack(
              children: avatarPaths
                  .map((path) => _DriftingAvatar(
                assetPath: path,
                maxWidth: constraints.maxWidth,
                maxHeight: constraints.maxHeight,
              ))
                  .toList(),
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, '/signup'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    side: BorderSide(color: Colors.grey),
                    minimumSize: const Size(double.infinity, 44),
                  ),
                  child: const Text(
                    'Sign Up',
                    style: TextStyle(fontSize: 20),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, '/login'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    side: BorderSide(color: Colors.grey),
                    minimumSize: const Size(double.infinity, 44),
                  ),
                  child: const Text(
                    'Login',
                    style: TextStyle(fontSize: 20),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () async {
                    final Uri emailLaunchUri = Uri(
                      scheme: 'mailto',
                      path: 'elyticapp@gmail.com',
                      queryParameters: {
                        'subject': 'Support Request',
                      },
                    );

                    if (await canLaunchUrl(emailLaunchUri)) {
                      if (defaultTargetPlatform == TargetPlatform.android) {
                        // Show chooser dialog explicitly on Android
                        await launchUrl(
                          emailLaunchUri,
                          mode: LaunchMode.externalNonBrowserApplication,
                          webViewConfiguration:
                          const WebViewConfiguration(enableJavaScript: false),
                        );
                      } else {
                        // iOS and others, just launch normally
                        await launchUrl(emailLaunchUri);
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Could not open email client')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    side: BorderSide(color: Colors.grey),
                    minimumSize: const Size(double.infinity, 44),
                  ),
                  child: const Text(
                    'Contact Support',
                    style: TextStyle(fontSize: 20),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _DriftingAvatar extends StatefulWidget {
  final String assetPath;
  final double maxWidth, maxHeight;

  const _DriftingAvatar({
    required this.assetPath,
    required this.maxWidth,
    required this.maxHeight,
  });

  @override
  _DriftingAvatarState createState() => _DriftingAvatarState();
}

class _DriftingAvatarState extends State<_DriftingAvatar>
    with SingleTickerProviderStateMixin {
  static const double avatarSize = 90.0;
  late final AnimationController _ctrl;
  late Animation<Offset> _anim;
  late Offset _start, _end;
  final _rnd = Random();

  @override
  void initState() {
    super.initState();

    final durationSec = 3 + _rnd.nextInt(6);
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(seconds: durationSec),
    );

    _start = Offset(_rnd.nextDouble(), _rnd.nextDouble());
    _end = Offset(_rnd.nextDouble(), _rnd.nextDouble());
    _initAnimation();

    _ctrl.value = _rnd.nextDouble();

    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _start = _end;
        _end = Offset(_rnd.nextDouble(), _rnd.nextDouble());
        _initAnimation();
        _ctrl
          ..reset()
          ..forward();
      }
    });

    _ctrl.forward();
  }

  void _initAnimation() {
    _anim = Tween<Offset>(begin: _start, end: _end).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        final dx = _anim.value.dx * (widget.maxWidth - avatarSize);
        final dy = _anim.value.dy * (widget.maxHeight - avatarSize);
        return Positioned(
          left: dx,
          top: dy,
          child: Image.asset(widget.assetPath, width: avatarSize, height: avatarSize),
        );
      },
    );
  }
}
