// lib/frontend/screens/notifications/notification_center_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:elytic/frontend/widgets/notifications/notification_tile.dart';
import 'package:elytic/frontend/widgets/notifications/notification_empty_state.dart';

class NotificationCenterScreen extends StatefulWidget {
  final String currentUserId;

  const NotificationCenterScreen({super.key, required this.currentUserId});

  @override
  State<NotificationCenterScreen> createState() => _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  @override
  Widget build(BuildContext context) {
    final notifCollection = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.currentUserId)
        .collection('notifications')
        .orderBy('createdAt', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'Mark all as read',
            onPressed: _markAllAsRead,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: notifCollection.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data?.docs ?? [];

          // PATCH: Filter out DM notifications here!
          final filteredDocs = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final type = data['type']?.toString();
            // Add more types if you want to filter more
            return type != 'dm';
          }).toList();

          if (filteredDocs.isEmpty) {
            return const NotificationEmptyState();
          }
          return ListView.separated(
            itemCount: filteredDocs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final data = filteredDocs[i].data() as Map<String, dynamic>;
              final notifId = filteredDocs[i].id;

              // PATCH: Only make some notifications tappable
              final type = data['type']?.toString() ?? '';
              final username = data['username'];
              final isTierUpgrade = type == 'tier_upgrade';
              final isShopPurchase = type == 'shop_purchase';
              final isCompanionGift = type == 'pet_item_gift' && username != null && username.toString().isNotEmpty;

              VoidCallback? _onTap;
              if (isTierUpgrade || isShopPurchase || isCompanionGift) {
                _onTap = () {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: Text(data['title'] ?? "Notification"),
                      content: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (data['avatarUrl'] != null && (data['avatarUrl'] as String).isNotEmpty)
                              Center(
                                child: CircleAvatar(
                                  backgroundImage: NetworkImage(data['avatarUrl']),
                                  radius: 28,
                                ),
                              ),
                            if (data['itemImageUrl'] != null && (data['itemImageUrl'] as String).isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 16, bottom: 8),
                                child: Center(
                                  child: Image.network(data['itemImageUrl'], width: 60, height: 60),
                                ),
                              ),
                            if (data['username'] != null && (data['username'] as String).isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text("From: ${data['username']}", style: const TextStyle(fontWeight: FontWeight.w500)),
                              ),
                            if (data['itemName'] != null && (data['itemName'] as String).isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text("Item: ${data['itemName']}"),
                              ),
                            if (data['message'] != null && (data['message'] as String).isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text("Message: \"${data['message']}\""),
                              ),
                            if (data['body'] != null && (data['body'] as String).isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(data['body']),
                              ),
                            if (data['tierName'] != null && (data['tierName'] as String).isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text("Tier: ${data['tierName']}"),
                              ),
                          ],
                        ),
                      ),
                      actions: [
                        TextButton(
                          child: const Text("Close"),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  );
                };
              }

              return Dismissible(
                key: Key(notifId),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: const Color.fromRGBO(244, 67, 54, 0.9),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: const Icon(Icons.delete, color: Colors.white, size: 28),
                ),
                onDismissed: (direction) async {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(widget.currentUserId)
                      .collection('notifications')
                      .doc(notifId)
                      .delete();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Notification deleted')),
                  );
                },
                child: NotificationTile(
                  data: data,
                  unread: !(data['read'] == true), // patched
                  onTap: _onTap,
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _markAllAsRead() async {
    final batch = FirebaseFirestore.instance.batch();
    final notifSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.currentUserId)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .get();
    for (final doc in notifSnapshot.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }
}
