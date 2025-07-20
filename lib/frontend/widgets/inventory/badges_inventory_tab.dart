// lib/frontend/screens/inventory/badges_inventory_tab.dart

import 'package:flutter/material.dart';
import 'package:elytic/backend/services/chat_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BadgesInventoryTab extends StatelessWidget {
  const BadgesInventoryTab({Key? key}) : super(key: key);

  Future<String?> _getCurrentMainBadgeId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    return doc.data()?['mainBadgeId'] as String?;
  }

  Future<void> _setMainBadge(BuildContext context, String badgeId, String badgeUrl) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'mainBadgeId': badgeId,
      'mainBadgeUrl': badgeUrl,
    }, SetOptions(merge: true));
  }

  void _showBadgeDialog(
      BuildContext context,
      Map<String, dynamic> badge,
      String badgeId,
      String iconUrl,
      VoidCallback onSetMain,
      ) {
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CachedNetworkImage(
                      imageUrl: badge['iconUrl'] ?? '',
                      height: 64,
                      width: 64,
                      fit: BoxFit.cover,
                      errorWidget: (c, e, s) => Container(
                        height: 64,
                        width: 64,
                        color: theme.colorScheme.surfaceVariant,
                        child: const Icon(Icons.broken_image, size: 36, color: Colors.grey),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    badge['name'] ?? 'Unnamed',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if ((badge['description'] ?? '').toString().trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        badge['description'],
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[700], fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: 16),
                  FutureBuilder<String?>(
                    future: _getCurrentMainBadgeId(),
                    builder: (context, snapshot) {
                      final isMain = snapshot.data == badgeId;
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const CircularProgressIndicator(strokeWidth: 2);
                      }
                      return isMain
                          ? ElevatedButton.icon(
                        onPressed: null,
                        icon: const Icon(Icons.verified, color: Colors.green),
                        label: const Text("Main Badge (Current)"),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.green[400],
                          disabledBackgroundColor: Colors.green[400],
                        ),
                      )
                          : ElevatedButton.icon(
                        onPressed: onSetMain,
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text("Set as Main Badge"),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: ChatService.getBadgeMetadata(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || snapshot.data == null) {
          return const Center(child: Text('Failed to load badges.'));
        }
        final badges = snapshot.data!;

        return FutureBuilder<String?>(
          future: _getCurrentMainBadgeId(),
          builder: (context, mainBadgeSnapshot) {
            final mainBadgeId = mainBadgeSnapshot.data;

            return LayoutBuilder(
              builder: (context, constraints) {
                return GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 180,
                    mainAxisSpacing: 2,
                    crossAxisSpacing: 2,
                    childAspectRatio: 1.05,
                  ),
                  itemCount: badges.length,
                  itemBuilder: (context, i) {
                    final data = badges[i];
                    final badgeId = data['id'] ?? '';
                    final badgeName = (data['name'] ?? '').toString().trim();
                    final badgeDesc = (data['description'] ?? '').toString().trim();
                    final iconUrl = (data['iconUrl'] ?? '').toString();

                    return LayoutBuilder(
                      builder: (context, itemConstraints) {
                        final itemHeight = itemConstraints.maxHeight;
                        final imageSize = itemHeight * 0.48;

                        return GestureDetector(
                          onTap: () {
                            bool saving = false;
                            void handleSetMain() async {
                              if (saving) return;
                              saving = true;
                              Navigator.of(context).pop();
                              await _setMainBadge(context, badgeId, iconUrl);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Main badge set!')),
                              );
                            };

                            _showBadgeDialog(
                              context,
                              data,
                              badgeId,
                              iconUrl,
                              handleSetMain,
                            );
                          },
                          child: Column(
                            mainAxisSize: MainAxisSize.max,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: CachedNetworkImage(
                                  imageUrl: iconUrl,
                                  height: imageSize,
                                  width: imageSize,
                                  fit: BoxFit.cover,
                                  placeholder: (c, s) => SizedBox(
                                    height: imageSize,
                                    width: imageSize,
                                    child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                  ),
                                  errorWidget: (c, e, s) => Container(
                                    height: imageSize,
                                    width: imageSize,
                                    color: theme.colorScheme.surfaceVariant,
                                    child: const Icon(Icons.broken_image, size: 36, color: Colors.grey),
                                  ),
                                ),
                              ),
                              SizedBox(height: itemHeight * 0.05),
                              Flexible(
                                child: Text(
                                  badgeName.isNotEmpty ? badgeName : 'Unnamed',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (badgeDesc.isNotEmpty)
                                Flexible(
                                  child: Padding(
                                    padding: EdgeInsets.only(top: itemHeight * 0.03),
                                    child: Text(
                                      badgeDesc,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: Colors.grey[600],
                                        fontSize: 10,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}
