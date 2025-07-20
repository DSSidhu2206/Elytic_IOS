// lib/frontend/widgets/common/user_avatar.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elytic/frontend/helpers/avatar_helper.dart';

class UserAvatar extends StatelessWidget {
  final String userId;
  final double size;
  final BoxShape shape;
  final VoidCallback? onTap; // You can pass a custom onTap if you ever want

  const UserAvatar({
    Key? key,
    required this.userId,
    this.size = 60,
    this.shape = BoxShape.circle,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
      builder: (context, snapshot) {
        final userData = snapshot.data?.data() as Map<String, dynamic>?;

        final avatarPath = userData?['avatarUrl'] ?? userData?['avatarPath'] ?? '';
        final borderId = userData?['settings']?['selectedAvatarBorderId'] ?? userData?['selectedAvatarBorderId'];

        // We'll load the border if borderId is present, but only if it's not null/empty
        return borderId != null && borderId is String && borderId.isNotEmpty
            ? FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('avatar_border_data')
              .doc(borderId)
              .get(),
          builder: (context, borderSnapshot) {
            final borderUrl = borderSnapshot.data?.data() is Map
                ? (borderSnapshot.data!.data() as Map)['image_url'] as String?
                : null;

            return _buildAvatarWithBorder(
              context,
              avatarPath,
              borderUrl,
            );
          },
        )
            : _buildAvatarWithBorder(
          context,
          avatarPath,
          null,
        );
      },
    );
  }

  Widget _buildAvatarWithBorder(BuildContext context, String? avatarPath, String? borderUrl) {
    // Widget composition for border + avatar + tap
    Widget avatarWidget = Stack(
      alignment: Alignment.center,
      children: [
        // Avatar base layer
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: shape,
            color: Colors.grey[200],
            image: DecorationImage(
              image: getAvatarImageProvider(avatarPath),
              fit: BoxFit.cover,
            ),
          ),
        ),
        // Border on top
        if ((borderUrl ?? '').isNotEmpty)
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: shape,
              image: DecorationImage(
                image: getBorderImageProvider(borderUrl),
                fit: BoxFit.cover,
              ),
            ),
          ),
      ],
    );

    // Tap-to-enlarge logic
    return GestureDetector(
      onTap: onTap ??
              () {
            showDialog(
              context: context,
              builder: (context) => _FullScreenAvatarDialog(
                avatarPath: avatarPath,
                borderUrl: borderUrl,
                shape: shape,
              ),
            );
          },
      child: avatarWidget,
    );
  }
}

// Helper for enlarged dialog
class _FullScreenAvatarDialog extends StatelessWidget {
  final String? avatarPath;
  final String? borderUrl;
  final BoxShape shape;

  const _FullScreenAvatarDialog({
    Key? key,
    this.avatarPath,
    this.borderUrl,
    required this.shape,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Full screen with transparent dark background and a close button
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // The blurred/dark background
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.black.withOpacity(0.75),
            ),
          ),
          // Enlarged avatar
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    shape: shape,
                    color: Colors.grey[200],
                    image: DecorationImage(
                      image: getAvatarImageProvider(avatarPath),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                if ((borderUrl ?? '').isNotEmpty)
                  Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      shape: shape,
                      image: DecorationImage(
                        image: getBorderImageProvider(borderUrl),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Close button (top right)
          Positioned(
            top: 32,
            right: 32,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black87,
                ),
                padding: const EdgeInsets.all(10),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
