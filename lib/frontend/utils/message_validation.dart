// lib/frontend/utils/message_validation.dart

import 'dart:core';
import 'package:elytic/backend/utils/tier_permissions.dart';

class MessageValidationException implements Exception {
  final String message;
  MessageValidationException(this.message);
  @override
  String toString() => 'MessageValidationException: $message';
}

class MessageValidator {
  static final Map<String, DateTime> _lastSentAt = {};
  static const int defaultMaxLength = 120;
  static const int minIntervalSeconds = 4;

  /// Stricter regex for plausible URLs and domains.
  static final RegExp _urlPattern = RegExp(
    r'((https?:\/\/)?(www\.)?[a-zA-Z0-9\-]+\.[a-zA-Z]{2,8}(\.[a-zA-Z]{2,8})?(\/[^\s]*)?)',
    caseSensitive: false,
  );

  static String validate({
    required String userId,
    required int userTier,
    required String rawText,
  }) {
    final now = DateTime.now();

    final last = _lastSentAt[userId];
    if (last != null) {
      final diff = now.difference(last).inSeconds;
      if (diff < minIntervalSeconds) {
        throw MessageValidationException(
            'Please wait ${minIntervalSeconds - diff}s before sending another message.');
      }
    }

    // PATCH: Allow tier 2 and above to always send links.
    final canSendLinks = userTier >= 2 ||
        (getTierPermissionValue(userTier, TierPermission.canSendLinks) ?? false);
    if (!canSendLinks && _urlPattern.hasMatch(rawText)) {
      throw MessageValidationException(
          'You are not allowed to send links.');
    }

    // PATCH: Allow tier 2 and above to send up to 200 chars.
    final int maxLength = userTier >= 2
        ? 200
        : (getTierPermissionValue(userTier, TierPermission.maxMessageLength) ?? defaultMaxLength);
    final sanitized = rawText.length > maxLength
        ? rawText.substring(0, maxLength)
        : rawText;

    _lastSentAt[userId] = now;
    return sanitized;
  }
}
