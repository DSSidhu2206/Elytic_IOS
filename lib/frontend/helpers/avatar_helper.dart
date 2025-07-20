// lib/frontend/helpers/avatar_helper.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

ImageProvider getAvatarImageProvider(String? avatarUrl) {
  if (avatarUrl == null || avatarUrl.isEmpty) {
    return const AssetImage('assets/avatars/avatar_1.png'); // fallback
  }
  if (avatarUrl.startsWith('http')) {
    return CachedNetworkImageProvider(avatarUrl);
  }
  return AssetImage(avatarUrl);
}

// PATCHED: No fallback for border images
ImageProvider getBorderImageProvider(String? borderUrl) {
  // Only return a CachedNetworkImageProvider if the URL is valid.
  if (borderUrl != null && borderUrl.isNotEmpty) {
    return CachedNetworkImageProvider(borderUrl);
  }
  // If borderUrl is null/empty, throw; the widget should never call this in that case.
  throw Exception('No borderUrl provided');
}
