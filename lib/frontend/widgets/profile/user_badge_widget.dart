// lib/frontend/widgets/profile/user_badge_widget.dart

import 'package:flutter/material.dart';

class UserBadgeWidget extends StatelessWidget {
  final String? badgeUrl;
  final double size; // badge size on screen

  const UserBadgeWidget({
    Key? key,
    required this.badgeUrl,
    this.size = 48,
  }) : super(key: key);

  void _showEnlargedBadge(BuildContext context) {
    if (badgeUrl == null) return;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: InteractiveViewer(
          child: Image.network(
            badgeUrl!,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return SizedBox(
                width: 200,
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              );
            },
            errorBuilder: (context, error, stackTrace) => const SizedBox(
              width: 200,
              height: 200,
              child: Center(child: Icon(Icons.error)),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (badgeUrl == null) {
      return SizedBox(
        width: size,
        height: size,
        child: const Center(child: Icon(Icons.shield_outlined, size: 24, color: Colors.grey)),
      );
    }

    return GestureDetector(
      onTap: () => _showEnlargedBadge(context),
      child: Image.network(
        badgeUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Icon(Icons.shield_outlined, size: size, color: Colors.grey),
      ),
    );
  }
}
