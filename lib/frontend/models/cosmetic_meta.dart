// lib/frontend/models/cosmetics_meta.dart

class ChatBubbleMeta {
  final String id;
  final String name;
  final String? rarity;
  final String? description;
  final int displayOrder;

  ChatBubbleMeta({
    required this.id,
    required this.name,
    required this.displayOrder,
    this.rarity,
    this.description,
  });

  factory ChatBubbleMeta.fromFirestore(Map<String, dynamic> data) {
    return ChatBubbleMeta(
      id: data['chat_bubble_id'],
      name: data['name'] ?? '',
      displayOrder: int.tryParse(data['display_order']?.toString() ?? '999') ?? 999,
      rarity: data['rarity'],
      description: data['description'],
    );
  }
}

class AvatarBorderMeta {
  final String id;
  final String name;
  final String? rarity;
  final String? description;
  final int displayOrder;
  final String? imageUrl;

  AvatarBorderMeta({
    required this.id,
    required this.name,
    required this.displayOrder,
    this.rarity,
    this.description,
    this.imageUrl,
  });

  factory AvatarBorderMeta.fromFirestore(Map<String, dynamic> data) {
    return AvatarBorderMeta(
      id: data['avatar_border_id'],
      name: data['name'] ?? '',
      displayOrder: int.tryParse(data['display_order']?.toString() ?? '999') ?? 999,
      rarity: data['rarity'],
      description: data['description'],
      imageUrl: data['image_url'],
    );
  }
}
