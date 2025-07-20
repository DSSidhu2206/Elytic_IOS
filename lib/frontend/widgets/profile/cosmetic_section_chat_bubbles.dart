// lib/frontend/widgets/profile/cosmetic_section_chat_bubbles.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/cosmetic_meta.dart';
import 'cosmetic_previews.dart';
// <<<<< PATCH: Import UserService >>>>>
import 'package:elytic/backend/services/user_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // for FieldValue and SetOptions

class CosmeticSectionChatBubbles extends StatefulWidget {
  const CosmeticSectionChatBubbles({Key? key}) : super(key: key);

  @override
  State<CosmeticSectionChatBubbles> createState() => _CosmeticSectionChatBubblesState();
}

class _CosmeticSectionChatBubblesState extends State<CosmeticSectionChatBubbles> {
  List<ChatBubbleMeta> bubbleMetas = [];
  Map<String, int> bubblePrices = {};
  Set<String> ownedBubbles = {};
  String? selectedChatBubbleId;
  bool loading = true;
  bool saving = false;
  final String userId = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    loadBubbleData();
  }

  Future<void> loadBubbleData() async {
    setState(() => loading = true);

    final data = await UserService.fetchChatBubbleData(userId);

    // We need to cast carefully and convert List<dynamic> to List<ChatBubbleMeta>
    final bubbleMetasRaw = data['bubbleMetas'] as List<dynamic>? ?? [];
    final allMetas = bubbleMetasRaw.cast<ChatBubbleMeta>();

    final prices = Map<String, int>.from(data['bubblePrices'] ?? {});
    // ownedBubbles might come as Iterable<dynamic> (e.g., List or Set)
    final ownedSetRaw = data['ownedBubbles'] as Iterable<dynamic>? ?? [];
    final ownedSet = ownedSetRaw.map((e) => e.toString()).toSet();

    final selected = data['selectedChatBubbleId'] as String?;

    setState(() {
      bubbleMetas = allMetas;
      bubblePrices = prices;
      ownedBubbles = ownedSet;
      selectedChatBubbleId = selected;
      loading = false;
    });
  }

  Future<void> saveSelectedBubble(String? bubbleId) async {
    setState(() {
      saving = true;
      selectedChatBubbleId = bubbleId;
    });

    await UserService.saveSelectedChatBubble(userId, bubbleId);

    setState(() => saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Chat bubble style updated!')),
    );
  }

  void _showLockedBubbleDialog({int? coinPrice}) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Locked Chat Bubble"),
        content: Text(
          "You currently don't own this chat bubble.\n"
              "It can be obtained through shop/events."
              "${coinPrice != null && coinPrice > 0 ? "\nPrice: $coinPrice coins" : ""}",
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushNamed('/shop', arguments: {'tab': 'chat_bubbles'});
            },
            child: const Text("Go to Shop"),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());

    List<ChatBubbleMeta> owned = [];
    List<ChatBubbleMeta> unowned = [];
    for (final meta in bubbleMetas) {
      if (ownedBubbles.contains(meta.id)) {
        owned.add(meta);
      } else {
        unowned.add(meta);
      }
    }
    final sortedBubbles = [...owned, ...unowned];

    final removeTile = GestureDetector(
      onTap: saving ? null : () async => await saveSelectedBubble(null),
      child: Container(
        decoration: BoxDecoration(
          border: selectedChatBubbleId == null
              ? Border.all(color: Colors.deepPurple, width: 3)
              : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: selectedChatBubbleId == null
              ? [BoxShadow(color: Colors.deepPurpleAccent.withOpacity(0.1), blurRadius: 4)]
              : [],
        ),
        width: 160,
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 3),
            Expanded(
              child: Center(
                child: Icon(Icons.remove_circle_outline, size: 42, color: Colors.grey[600]),
              ),
            ),
            const SizedBox(height: 6),
            const Text("Remove Chat Bubble",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const Text("Use default bubble", style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Chat Bubble Style",
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        bubbleMetas.isEmpty
            ? const Text("No chat bubbles available.", style: TextStyle(color: Colors.red))
            : SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: sortedBubbles.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, i) {
              if (i == 0) return removeTile;

              final meta = sortedBubbles[i - 1];
              final isOwned = ownedBubbles.contains(meta.id);
              final isSelected = isOwned && meta.id == selectedChatBubbleId;
              final int? coinPrice = bubblePrices[meta.id];

              return Opacity(
                opacity: isOwned ? 1 : 0.4,
                child: GestureDetector(
                  onTap: saving
                      ? null
                      : () async {
                    if (isOwned) {
                      await saveSelectedBubble(meta.id);
                    } else {
                      _showLockedBubbleDialog(coinPrice: coinPrice);
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      border: isSelected
                          ? Border.all(color: Colors.deepPurple, width: 3)
                          : null,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: isSelected
                          ? [BoxShadow(color: Colors.deepPurpleAccent.withOpacity(0.1), blurRadius: 4)]
                          : [],
                    ),
                    width: 160,
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 3),
                        Expanded(child: bubblePreviewWidget(meta.id)),
                        const SizedBox(height: 6),
                        Text(meta.name,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        Row(
                          children: [
                            if (meta.rarity != null)
                              Container(
                                margin: const EdgeInsets.only(right: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.purple[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(meta.rarity!, style: const TextStyle(fontSize: 12)),
                              ),
                            if (!isOwned)
                              ...[
                                const Icon(Icons.lock_outline, size: 16, color: Colors.red),
                                if (coinPrice != null && coinPrice > 0)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 6),
                                    child: Text(
                                      "$coinPrice",
                                      style: const TextStyle(
                                        color: Colors.orange,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (saving)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}
