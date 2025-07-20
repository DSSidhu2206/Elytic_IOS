// lib/frontend/widgets/profile/avatar_border_preview.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

Widget avatarBorderPreviewImage(String? imageUrl) {
  return Stack(
    alignment: Alignment.center,
    children: [
      if (imageUrl != null && imageUrl.isNotEmpty)
        CachedNetworkImage(
          imageUrl: imageUrl,
          width: 75,
          height: 75,
          fit: BoxFit.contain,
          placeholder: (context, url) => const SizedBox(
            width: 75,
            height: 75,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          errorWidget: (context, error, stackTrace) => const SizedBox(
            width: 75,
            height: 75,
            child: Icon(Icons.broken_image, size: 42),
          ),
        ),
      CircleAvatar(
        radius: 26,
        backgroundColor: Colors.grey[300],
        child: const Icon(Icons.person, color: Colors.white, size: 32),
      ),
    ],
  );
}
