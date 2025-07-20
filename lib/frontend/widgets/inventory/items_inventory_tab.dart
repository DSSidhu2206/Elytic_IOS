// lib/frontend/widgets/inventory/items_inventory_tab.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ItemsInventoryTab extends StatelessWidget {
  const ItemsInventoryTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text('Not signed in.'));

    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('items');

    return StreamBuilder<QuerySnapshot>(
      stream: ref.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No items owned.'));
        }
        final docs = snapshot.data!.docs;

        return GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 32,
            crossAxisSpacing: 12,
            childAspectRatio: 0.85,
          ),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final String name = data['name'] ?? '';
            final String rarity = data['rarity'] ?? '';
            final String assetUrl = data['assetUrl'] ?? '';
            final int count = (data['count'] ?? data['quantity'] ?? 1) as int;

            return GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(name.isNotEmpty ? name : "Item"),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (assetUrl.isNotEmpty)
                          CachedNetworkImage(
                            imageUrl: assetUrl,
                            fit: BoxFit.contain,
                            height: 120,
                            placeholder: (ctx, url) => const SizedBox(
                              height: 120,
                              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                            ),
                            errorWidget: (ctx, e, s) => const Icon(Icons.inventory_2_outlined, size: 60),
                          ),
                        if (rarity.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 18),
                            child: Text(
                              'Rarity: $rarity',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.deepPurple,
                                fontSize: 17,
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.only(top: 18.0),
                          child: Text(
                            'x$count',
                            style: const TextStyle(fontSize: 20, color: Colors.black),
                          ),
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              },
              child: LayoutBuilder(
                builder: (ctx, constraints) {
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Center(
                        child: assetUrl.isNotEmpty
                            ? CachedNetworkImage(
                          imageUrl: assetUrl,
                          fit: BoxFit.contain,
                          width: constraints.maxWidth * 0.9,
                          height: constraints.maxHeight * 0.75,
                          placeholder: (ctx, url) => const Center(
                            child: SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (ctx, e, s) => const Icon(Icons.inventory_2_outlined, size: 34),
                        )
                            : const Icon(Icons.inventory_2_outlined, size: 34),
                      ),
                      // Black xN badge, top right of image
                      Positioned(
                        // Right up against top right of image, with slight offset to overlap
                        right: constraints.maxWidth * 0.10 - 8,
                        top: constraints.maxHeight * 0.12 - 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "x$count",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
