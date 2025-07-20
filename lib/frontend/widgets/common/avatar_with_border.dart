// lib/frontend/widgets/common/avatar_with_border.dart

import 'package:flutter/material.dart';
import 'package:elytic/frontend/helpers/avatar_helper.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AvatarWithBorder extends StatelessWidget {
  final String avatarPath;
  final String? borderUrl; // Firestore download URL (or null/empty if no border)
  final double size;

  const AvatarWithBorder({
    Key? key,
    required this.avatarPath,
    this.borderUrl,
    this.size = 80,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final avatarProvider = getAvatarImageProvider(avatarPath);

    // The outer box is 1.5x the avatar size
    final double borderBoxSize = size * 1.5;

    return SizedBox(
      width: borderBoxSize,
      height: borderBoxSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Avatar (drawn first, now under border)
          Center(
            child: CircleAvatar(
              radius: size / 2,
              backgroundImage: avatarProvider,
              backgroundColor: Colors.grey[200],
              child: avatarPath.isEmpty
                  ? const Icon(Icons.person, size: 32)
                  : null,
            ),
          ),
          // Border (drawn above avatar)
          if (borderUrl != null && borderUrl!.isNotEmpty)
            Positioned.fill(
              child: IgnorePointer(
                child: CachedNetworkImage(
                  imageUrl: borderUrl!,
                  fit: BoxFit.cover,
                  errorWidget: (context, error, stackTrace) =>
                  const SizedBox(), // hide border if load fails
                  placeholder: (context, url) => const SizedBox(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
