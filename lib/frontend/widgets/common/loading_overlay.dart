// lib/frontend/widgets/common/loading_overlay.dart

import 'package:flutter/material.dart';

class LoadingOverlay extends StatelessWidget {
  final bool isVisible;
  final Widget? customLoader;
  final String? loadingText;

  const LoadingOverlay({
    Key? key,
    required this.isVisible,
    this.customLoader,
    this.loadingText,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    return Stack(
      children: [
        // Simple semi-transparent background
        Positioned.fill(
          child: Container(
            color: Colors.black.withOpacity(0.22),
          ),
        ),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              customLoader ??
                  const CircularProgressIndicator(
                    strokeWidth: 3.2,
                  ),
              if (loadingText != null) ...[
                const SizedBox(height: 18),
                Text(
                  loadingText!,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.normal,
                    color: Colors.white,
                    decoration: TextDecoration.none, // Ensures NO underline
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.visible,
                  maxLines: 2,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
