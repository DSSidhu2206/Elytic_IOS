// lib/frontend/widgets/profile/profile_background_widget.dart

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// A widget that fetches and displays a user's custom profile background.
/// If [isCurrentUser] is true, allows previews only; all edits go through the profile editor.
class ProfileBackgroundWidget extends StatefulWidget {
  /// The UID of the profile being viewed.
  final String userId;

  /// Whether the profile belongs to the currently signed-in user.
  final bool isCurrentUser;

  const ProfileBackgroundWidget({
    Key? key,
    required this.userId,
    required this.isCurrentUser,
  }) : super(key: key);

  @override
  State<ProfileBackgroundWidget> createState() =>
      _ProfileBackgroundWidgetState();
}

class _ProfileBackgroundWidgetState extends State<ProfileBackgroundWidget> {
  String? _backgroundUrl;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBackground();
  }

  Future<void> _loadBackground() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();
      final data = doc.data();
      setState(() {
        // Use cosmetics.profileBackground (for future scalability)
        _backgroundUrl = data?['cosmetics']?['profileBackground'] as String?;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = "Failed to load background";
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasBackground =
        _backgroundUrl != null && _backgroundUrl!.isNotEmpty;

    return SizedBox(
      width: double.infinity,
      height: 200,
      child: Stack(
        children: [
          // Background (cached) or loading/error/empty
          Positioned.fill(
            child: Builder(
              builder: (context) {
                if (_loading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (_error != null) {
                  return Center(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                if (hasBackground) {
                  return CachedNetworkImage(
                    imageUrl: _backgroundUrl!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: 200,
                    errorWidget: (ctx, url, err) => const Center(
                        child: Text("Failed to load image",
                            style: TextStyle(color: Colors.red))),
                    placeholder: (ctx, url) =>
                    const Center(child: CircularProgressIndicator()),
                  );
                }
                // No background set
                return Container(
                  width: double.infinity,
                  height: 200,
                  color: Colors.grey[200],
                  child: const Center(
                    child: Text(
                      'No background set',
                      style: TextStyle(
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // No edit button here; all editing is handled via the profile editor screen.
        ],
      ),
    );
  }
}
