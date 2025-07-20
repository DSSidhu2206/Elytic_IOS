import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'notification_type_icon.dart';
import 'package:elytic/frontend/helpers/avatar_helper.dart'; // PATCHED: avatar helper import

class NotificationTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback? onTap;
  final bool unread;

  const NotificationTile({
    super.key,
    required this.data,
    this.onTap,
    this.unread = false,
  });

  @override
  Widget build(BuildContext context) {
    final type = data['type'] ?? '';
    final title = data['title'] ?? '';
    final body = data['body'] ?? '';
    final createdAt = data['createdAt']?.toDate();
    final subtitle = data['subtitle'];
    final avatarUrl = data['avatarUrl'];
    final username = data['username'];
    final icon = NotificationTypeIcon(
      type: type,
      isRead: !unread,
    );

    // PATCH: Companion gift notification fields
    final itemImageUrl = data['itemImageUrl'];
    final itemName = data['itemName'];
    final message = data['message'];

    final isCompanionGift = type == 'pet_item_gift';
    final isTierUpgrade = type == 'tier_upgrade';
    final isCoinGift = type == 'coin_gift';
    final isSubscriptionGift = type == 'subscription_gift';

    // PATCH: Detect gift/tier for background color
    Color? _giftBgColor;
    int? _tier;

    if (isCompanionGift) {
      _tier = data['tier'] is int
          ? data['tier']
          : int.tryParse(data['tier']?.toString() ?? '');
    } else if (isTierUpgrade) {
      // Try 'tier', 'newTier', or nested data fields (robust to all possible Firestore fields)
      if (data['tier'] != null) {
        _tier = data['tier'] is int
            ? data['tier']
            : int.tryParse(data['tier'].toString());
      } else if (data['newTier'] != null) {
        _tier = data['newTier'] is int
            ? data['newTier']
            : int.tryParse(data['newTier'].toString());
      } else if (data['data'] != null && data['data'] is Map<String, dynamic>) {
        final tierFromData = (data['data'] as Map<String, dynamic>)['newTier'];
        if (tierFromData != null) {
          _tier = tierFromData is int ? tierFromData : int.tryParse(tierFromData.toString());
        }
      }
    }

    if (_tier == 1) {
      _giftBgColor = const Color(0xFFCD7F32); // Bronze
    } else if (_tier == 2) {
      _giftBgColor = const Color(0xFFC0C0C0); // Silver
    } else if (_tier == 3) {
      _giftBgColor = const Color(0xFFFFD700); // Gold
    }

    // --- PATCHED avatar logic ---
    Widget _buildLeading() {
      if (type == 'friend_request') {
        // Always use current avatar logic for friend requests (untouched)
        return avatarUrl != null && avatarUrl.toString().isNotEmpty
            ? CircleAvatar(backgroundImage: getAvatarImageProvider(avatarUrl))
            : icon;
      }
      // For other gift/upgrade notifications, show sender avatar if present
      if (isCompanionGift || isTierUpgrade || isCoinGift || isSubscriptionGift) {
        if (avatarUrl != null && avatarUrl.toString().isNotEmpty) {
          return CircleAvatar(backgroundImage: getAvatarImageProvider(avatarUrl));
        }
      }
      // Default to icon for everything else
      return icon;
    }

    return ListTile(
      onTap: onTap,
      leading: _buildLeading(), // PATCHED
      title: Text(
        title.toString().isNotEmpty
            ? title
            : _getDefaultTitle(type, username, itemName),
        style: TextStyle(
          fontWeight: unread ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: isCompanionGift
          ? _CompanionGiftSubtitle(
        username: username,
        itemImageUrl: itemImageUrl,
        itemName: itemName,
        message: message,
        body: body,
        subtitle: subtitle,
      )
          : Text(
        subtitle?.toString().isNotEmpty == true
            ? subtitle
            : body.toString().isNotEmpty
            ? body
            : _getDefaultSubtitle(type, username),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: createdAt != null
          ? Text(
        DateFormat('h:mm a').format(createdAt),
        style: TextStyle(
          fontSize: 12,
          color: unread
              ? Theme.of(context).colorScheme.primary
              : Colors.grey,
        ),
      )
          : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      tileColor: (isCompanionGift || isTierUpgrade)
          ? _giftBgColor ??
          (unread
              ? Theme.of(context)
              .colorScheme
              .primary
              .withAlpha((255 * 0.07).toInt())
              : null)
          : (unread
          ? Theme.of(context)
          .colorScheme
          .primary
          .withAlpha((255 * 0.07).toInt())
          : null),
    );
  }

  String _getDefaultTitle(String type, String? username, String? itemName) {
    switch (type) {
      case 'friend_request':
        return username != null
            ? '$username sent you a friend request'
            : 'Friend Request';
      case 'friend_accepted':
        return username != null
            ? '$username accepted your friend request'
            : 'Friend Accepted';
      case 'bio_removed':
        return 'Profile Bio Removed';
      case 'shop_purchase':
        return 'Purchase Successful!';
      case 'pet_level_up':
        return 'Companion Leveled Up!';
      case 'pet_item_gift':
        return username != null && itemName != null
            ? '$username sent your Companion a $itemName!'
            : 'Your Companion Received an Item!';
      case 'tier_upgrade':
        return 'Tier Upgraded!';
      case 'event':
        return 'Event';
      default:
        return 'Notification';
    }
  }

  String _getDefaultSubtitle(String type, String? username) {
    switch (type) {
      case 'friend_request':
        return 'Sent you a friend request';
      case 'friend_accepted':
        return 'Accepted your friend request';
      case 'bio_removed':
        return 'Your profile bio was removed for violating our guidelines.';
      case 'shop_purchase':
        return 'You made a purchase in the shop.';
      case 'pet_level_up':
        return 'Your Companion leveled up!';
      case 'pet_item_gift':
        return 'Your Companion received a gift!';
      case 'tier_upgrade':
        return 'Congratulations on your new tier!';
      case 'event':
        return 'A new event is live!';
      default:
        return '';
    }
  }
}

// PATCH: Custom subtitle widget for companion gifts
class _CompanionGiftSubtitle extends StatelessWidget {
  final String? username;
  final String? itemImageUrl;
  final String? itemName;
  final String? message;
  final String? body;
  final String? subtitle;

  const _CompanionGiftSubtitle({
    super.key,
    this.username,
    this.itemImageUrl,
    this.itemName,
    this.message,
    this.body,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final List<Widget> rowChildren = [];
    if (itemImageUrl != null && itemImageUrl!.isNotEmpty) {
      rowChildren.add(
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: Image.network(itemImageUrl!, width: 36, height: 36),
        ),
      );
    }
    final List<String> parts = [];
    if (username != null && username!.isNotEmpty) {
      parts.add('$username sent your Companion');
    }
    if (itemName != null && itemName!.isNotEmpty) {
      parts.add(itemName!);
    }
    if (message != null && message!.isNotEmpty) {
      parts.add('"$message"');
    }
    final displayText =
    parts.isNotEmpty ? parts.join(' ') : (subtitle ?? body ?? '');

    rowChildren.add(
      Flexible(
        child: Text(
          displayText,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: rowChildren,
    );
  }
}
