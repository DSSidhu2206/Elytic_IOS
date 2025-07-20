import 'dart:async';

import 'package:flutter/material.dart';
import 'package:elytic/frontend/helpers/avatar_helper.dart';

enum ElyticNotificationType {
  message,
  friendRequest,
  friendAccepted,
  tierUp,
  petPetted,
  petItemGift,
  mysteryBoxReward, // <-- NEW!
  giftCoins,        // <-- PATCH: Add here!
}

class CustomNotificationBanner extends StatelessWidget {
  final ElyticNotificationType type;
  final String title;
  final String message;
  final String? avatarUrl;
  final String? username;
  final int? tier;
  final String? petName;
  final String? itemName;
  final String? boxName;
  final String? rewardSummary;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;

  const CustomNotificationBanner({
    super.key,
    required this.type,
    required this.title,
    required this.message,
    this.avatarUrl,
    this.username,
    this.tier,
    this.petName,
    this.itemName,
    this.boxName,
    this.rewardSummary,
    this.onTap,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case ElyticNotificationType.message:
        return _ModernMessageBanner(
          avatarUrl: avatarUrl,
          username: username,
          message: message,
          onTap: onTap,
        );
      case ElyticNotificationType.friendRequest:
        return _FriendRequestBanner(
          avatarUrl: avatarUrl,
          username: username,
          message: message,
          onTap: onTap,
        );
      case ElyticNotificationType.friendAccepted:
        return _FriendAcceptedBanner(
          avatarUrl: avatarUrl,
          username: username,
          message: message,
          onTap: onTap,
        );
      case ElyticNotificationType.tierUp:
        return _TierUpBanner(
          tier: tier ?? 0,
          gifterUsername: username,
          gifterAvatarUrl: avatarUrl,
          onTap: onTap,
        );
      case ElyticNotificationType.petPetted:
        return _PetPettedBanner(
          avatarUrl: avatarUrl,
          username: username ?? 'Someone',
          petName: petName ?? 'your pet',
          onTap: onTap,
        );
      case ElyticNotificationType.petItemGift:
        return _PetItemGiftBanner(
          avatarUrl: avatarUrl,
          username: username ?? 'Someone',
          petName: petName ?? 'your pet',
          itemName: itemName ?? 'an item',
          onTap: onTap,
          onDismiss: onDismiss,
        );
      case ElyticNotificationType.mysteryBoxReward:
        return _MysteryBoxRewardBanner(
          boxName: boxName,
          rewardSummary: rewardSummary,
          onTap: onTap,
        );
      case ElyticNotificationType.giftCoins: // <-- PATCH: Add case!
        return _GiftCoinsBanner(
          avatarUrl: avatarUrl,
          username: username,
          message: message,
          onTap: onTap,
        );
    }
  }
}

class _ModernMessageBanner extends StatelessWidget {
  final String? avatarUrl;
  final String? username;
  final String message;
  final VoidCallback? onTap;

  const _ModernMessageBanner({
    this.avatarUrl,
    this.username,
    required this.message,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            // Removed boxShadow completely for cleaner look
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundImage: getAvatarImageProvider(avatarUrl),
                backgroundColor: Colors.grey[300],
                child: (avatarUrl == null || avatarUrl!.isEmpty)
                    ? Icon(Icons.person, color: Colors.grey[600], size: 28)
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      username ?? 'User',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      message,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  "DM",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Colors.black54,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _FriendRequestBanner extends StatelessWidget {
  final String? avatarUrl;
  final String? username;
  final String message;
  final VoidCallback? onTap;

  const _FriendRequestBanner({
    this.avatarUrl,
    this.username,
    required this.message,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green[600],
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundImage: getAvatarImageProvider(avatarUrl),
                backgroundColor: Colors.green[200],
                child: (avatarUrl == null || avatarUrl!.isEmpty)
                    ? const Icon(Icons.person, color: Colors.white, size: 28)
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(username ?? 'User',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.white)),
                    const SizedBox(height: 3),
                    Text(message,
                        style: const TextStyle(fontSize: 15, color: Colors.white),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FriendAcceptedBanner extends StatelessWidget {
  final String? avatarUrl;
  final String? username;
  final String message;
  final VoidCallback? onTap;

  const _FriendAcceptedBanner({
    this.avatarUrl,
    this.username,
    required this.message,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.indigo[500],
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundImage: getAvatarImageProvider(avatarUrl),
                backgroundColor: Colors.indigo[200],
                child: (avatarUrl == null || avatarUrl!.isEmpty)
                    ? const Icon(Icons.person, color: Colors.white, size: 28)
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(username ?? 'User',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.white)),
                    const SizedBox(height: 3),
                    Text(message,
                        style: const TextStyle(fontSize: 15, color: Colors.white),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TierUpBanner extends StatelessWidget {
  final int tier;
  final String? gifterUsername;
  final String? gifterAvatarUrl;
  final VoidCallback? onTap;

  const _TierUpBanner({
    required this.tier,
    this.gifterUsername,
    this.gifterAvatarUrl,
    this.onTap,
  });

  Color _getTierBgColor() {
    switch (tier) {
      case 1:
        return const Color(0xFFCD7F32); // Bronze
      case 2:
        return const Color(0xFFC0C0C0); // Silver
      case 3:
        return const Color(0xFFFFD700); // Gold
      case 4:
      case 5:
        return Colors.black;
      default:
        return Colors.blueGrey.shade400;
    }
  }

  Color _getTierTextColor() {
    if (tier == 4 || tier == 5) return Colors.white;
    if (tier == 1) return Colors.white;
    return Colors.black;
  }

  Color _getTierIconColor() {
    switch (tier) {
      case 1:
        return const Color(0xFFE7D1A6);
      case 2:
        return Colors.grey[800]!;
      case 3:
        return const Color(0xFFB8860B);
      default:
        return Colors.white;
    }
  }

  String _tierTitle() {
    switch (tier) {
      case 1:
        return "Elytic Basic – Bronze";
      case 2:
        return "Elytic Plus – Silver";
      case 3:
        return "Royalty – Gold";
      case 4:
        return "Junior Moderator";
      case 5:
        return "Senior Moderator";
      default:
        return "Tier Up!";
    }
  }

  String _congratsMessage() {
    final name = gifterUsername ?? "Admin";
    switch (tier) {
      case 1:
        return "Congratulations, you have been gifted Basic (subscription) by $name!";
      case 2:
        return "Congratulations, you have been gifted Plus (subscription) by $name!";
      case 3:
        return "Congratulations, you have been gifted Royalty (subscription) by $name!";
      case 4:
        return "You have been made an Elytic Junior Moderator by $name!";
      case 5:
        return "You have been made an Elytic Senior Moderator by $name!";
      default:
        return "Congratulations!";
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = _getTierBgColor();
    final text = _getTierTextColor();
    final icon = _getTierIconColor();

    return SafeArea(
      top: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                ),
                child: CircleAvatar(
                  radius: 25,
                  backgroundImage: getAvatarImageProvider(gifterAvatarUrl),
                  backgroundColor: Colors.grey[300],
                  child: (gifterAvatarUrl == null || gifterAvatarUrl!.isEmpty)
                      ? Icon(Icons.person, color: Colors.grey[600], size: 30)
                      : null,
                ),
              ),
              const SizedBox(width: 14),
              Icon(Icons.emoji_events, size: 36, color: icon),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _tierTitle(),
                      style: TextStyle(
                        color: text,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _congratsMessage(),
                      style: TextStyle(color: text.withAlpha(229), fontSize: 15),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class _PetPettedBanner extends StatelessWidget {
  final String? avatarUrl;
  final String username;
  final String petName;
  final VoidCallback? onTap;

  const _PetPettedBanner({
    this.avatarUrl,
    required this.username,
    required this.petName,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.orange.shade100,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundImage: getAvatarImageProvider(avatarUrl),
                backgroundColor: Colors.grey[300],
                child: (avatarUrl == null || avatarUrl!.isEmpty)
                    ? const Icon(Icons.pets, color: Colors.orange, size: 30)
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  "$username said Hello to $petName",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PetItemGiftBanner extends StatefulWidget {
  final String? avatarUrl;
  final String username;
  final String petName;
  final String itemName;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;

  const _PetItemGiftBanner({
    this.avatarUrl,
    required this.username,
    required this.petName,
    required this.itemName,
    this.onTap,
    this.onDismiss,
  });

  @override
  _PetItemGiftBannerState createState() => _PetItemGiftBannerState();
}

class _PetItemGiftBannerState extends State<_PetItemGiftBanner> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 5), () {
      widget.onDismiss?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: true,
      child: Dismissible(
        key: Key('petItemGift-${widget.username}-${widget.petName}-${widget.itemName}'),
        direction: DismissDirection.horizontal,
        onDismissed: (_) {
          widget.onDismiss?.call();
        },
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.purple.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundImage: getAvatarImageProvider(widget.avatarUrl),
                  backgroundColor: Colors.grey[300],
                  child: (widget.avatarUrl == null || widget.avatarUrl!.isEmpty)
                      ? const Icon(Icons.card_giftcard, color: Colors.purple, size: 30)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    "${widget.username} gave ${widget.itemName} to ${widget.petName}",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                      height: 1.3,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.black54),
                  onPressed: widget.onDismiss,
                  tooltip: 'Dismiss',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MysteryBoxRewardBanner extends StatelessWidget {
  final String? boxName;
  final String? rewardSummary;
  final VoidCallback? onTap;

  const _MysteryBoxRewardBanner({
    this.boxName,
    this.rewardSummary,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.amber.shade200,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.yellow.shade100,
                ),
                padding: const EdgeInsets.all(2),
                child: const Icon(Icons.card_giftcard, color: Colors.orange, size: 38),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      boxName != null ? 'Mystery Box: $boxName' : 'Mystery Box Reward!',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.deepOrange,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      rewardSummary ?? "You received surprise rewards!",
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                        color: Colors.black87,
                        height: 1.3,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GiftCoinsBanner extends StatelessWidget {
  final String? avatarUrl;
  final String? username;
  final String message;
  final VoidCallback? onTap;

  const _GiftCoinsBanner({
    this.avatarUrl,
    this.username,
    required this.message,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.yellow.shade100,
                Colors.orange.shade50,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            backgroundBlendMode: BlendMode.overlay,
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundImage: getAvatarImageProvider(avatarUrl),
                backgroundColor: Colors.amber[100],
                child: (avatarUrl == null || avatarUrl!.isEmpty)
                    ? const Icon(Icons.attach_money, color: Colors.orange, size: 30)
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      username ?? "Someone",
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: Color(0xFFCA8802),
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.card_giftcard, size: 18, color: Colors.amber[700]),
                        const SizedBox(width: 7),
                        const Text(
                          "Gifted you coins!",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Color(0xFFCA8802),
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      message,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 15.3,
                        color: Color(0xFF222222),
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
