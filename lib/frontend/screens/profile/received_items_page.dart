// lib/frontend/screens/profile/received_items_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
// PATCH: Import cached_network_image
import 'package:cached_network_image/cached_network_image.dart';
// PATCH: Import UserService
import 'package:elytic/backend/services/user_service.dart';

class ReceivedItemsPage extends StatefulWidget {
  final String userId;

  const ReceivedItemsPage({Key? key, required this.userId}) : super(key: key);

  @override
  State<ReceivedItemsPage> createState() => _ReceivedItemsPageState();
}

class _ReceivedItemsPageState extends State<ReceivedItemsPage> {
  late Future<List<Map<String, dynamic>>> _itemsFuture;

  String? _mainPetId;

  @override
  void initState() {
    super.initState();
    _itemsFuture = _fetchItems();
  }

  // PATCH 1: Fetch mainPetId, then fetch received items from mainPet's activeItems
  Future<List<Map<String, dynamic>>> _fetchItems() async {
    // Get mainPetId from user doc
    final userSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .get();

    final userData = userSnap.data();
    String? mainPetId = userData?['mainPetId']?.toString();
    _mainPetId = mainPetId;
    if (mainPetId == null || mainPetId.isEmpty) return [];

    // Get activeItems from user's main pet
    final activeItemsSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('pets')
        .doc(mainPetId)
        .collection('activeItems')
        .get();

    final now = DateTime.now();
    final items = activeItemsSnap.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      DateTime? expiresAt;
      if (data['expiresAt'] != null) {
        try {
          final ts = data['expiresAt'];
          if (ts is Timestamp) {
            expiresAt = ts.toDate();
          } else if (ts is DateTime) {
            expiresAt = ts;
          }
        } catch (_) {}
      }
      bool expired = expiresAt != null && expiresAt.isBefore(now);
      Duration? timeLeft = expiresAt != null ? expiresAt.difference(now) : null;
      data['expired'] = expired;
      data['expiresAt'] = expiresAt;
      data['timeLeft'] = timeLeft;
      return data;
    }).toList();

    // Sort: non-expired first, then expired
    items.sort((a, b) {
      if (a['expired'] == b['expired']) {
        final at = a['expiresAt'] as DateTime?;
        final bt = b['expiresAt'] as DateTime?;
        if (at != null && bt != null) return at.compareTo(bt);
        return 0;
      }
      return a['expired'] ? 1 : -1;
    });

    return items;
  }

  // PATCH 2: Set as active calls UserService.setActiveItem and updates RTDB.
  Future<void> _setAsActiveItem(String itemId) async {
    // Find the item data in the fetched list
    final allItems = await _itemsFuture;
    final item = allItems.firstWhere((i) => i['id'] == itemId, orElse: () => <String, dynamic>{});
    if (item.isEmpty) return;

    // Remove fields Firestore can't store
    final filtered = Map<String, dynamic>.from(item)
      ..remove('timeLeft')
      ..remove('expired');

    filtered['equipped'] = true;
    filtered['timestamp'] = FieldValue.serverTimestamp();

    // PATCH: Write to Firestore user/activeItems (as ONLY active item)
    await UserService.setActiveItem(widget.userId, filtered);

    // Write to RTDB presence for all rooms (unchanged)
    final presenceRoot = FirebaseDatabase.instance.ref('presence');
    final presenceSnap = await presenceRoot.get();
    if (presenceSnap.exists) {
      final data = presenceSnap.value as Map?;
      if (data != null) {
        for (final roomId in data.keys) {
          final roomMap = data[roomId];
          if (roomMap is Map && roomMap[widget.userId] != null) {
            await FirebaseDatabase.instance
                .ref('presence/$roomId/${widget.userId}/activeItemId')
                .set(itemId);
          }
        }
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Active item updated!')),
      );
      setState(() {
        _itemsFuture = _fetchItems(); // Optionally refresh the list
      });
    }
  }

  String _formatDuration(Duration d) {
    if (d.inSeconds < 60) return "${d.inSeconds}s";
    if (d.inMinutes < 60) return "${d.inMinutes}m";
    if (d.inHours < 24) return "${d.inHours}h ${d.inMinutes % 60}m";
    return "${d.inDays}d ${d.inHours % 24}h";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Your Received Items"),
        backgroundColor: Colors.teal.shade700,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _itemsFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data!;
          if (items.isEmpty) {
            return const Center(child: Text("You haven't received any items yet."));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: items.length,
            itemBuilder: (context, idx) {
              final item = items[idx];
              final isExpired = item['expired'] == true;
              final iconUrl = item['assetUrl'] ?? '';
              final name = item['name'] ?? item['itemName'] ?? item['id'] ?? "Unknown";
              final rarity = (item['rarity'] ?? '').toString();
              final timeLeft = item['timeLeft'] as Duration?;
              final expiresAt = item['expiresAt'] as DateTime?;

              return Opacity(
                opacity: isExpired ? 0.5 : 1.0,
                child: Card(
                  color: isExpired ? Colors.grey[200] : Colors.white,
                  margin: const EdgeInsets.symmetric(vertical: 7),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  child: ListTile(
                    leading: iconUrl != ''
                        ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      // PATCH: Use CachedNetworkImage
                      child: CachedNetworkImage(
                        imageUrl: iconUrl,
                        width: 54,
                        height: 54,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const SizedBox(
                            width: 32,
                            height: 32,
                            child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
                        errorWidget: (context, url, error) =>
                        const Icon(Icons.broken_image, size: 32),
                      ),
                    )
                        : Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.card_giftcard, size: 32, color: Colors.grey),
                    ),
                    title: Text(
                      name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isExpired ? Colors.grey : Colors.black87,
                        fontSize: 18,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (rarity.isNotEmpty)
                          Text(
                            "Rarity: ${rarity[0].toUpperCase()}${rarity.substring(1)}",
                            style: TextStyle(
                              color: isExpired ? Colors.grey : Colors.deepPurple,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        if (expiresAt != null && !isExpired)
                          Text(
                            "Expires in: ${_formatDuration(timeLeft!)}",
                            style: const TextStyle(
                              color: Colors.teal,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        if (isExpired && expiresAt != null)
                          Text(
                            "Expired: ${DateFormat.yMd().add_Hm().format(expiresAt)}",
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                      ],
                    ),
                    trailing: !isExpired
                        ? ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text("Set as Active"),
                      onPressed: () => _setAsActiveItem(item['id']),
                    )
                        : const Text("Expired",
                        style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w700)),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
