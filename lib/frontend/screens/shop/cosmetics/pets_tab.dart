// lib/frontend/screens/shop/cosmetics/pets_tab.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elytic/frontend/widgets/shop/shop_detail_dialog.dart';
import 'package:elytic/frontend/widgets/shop/shop_grid_card.dart';

class PetsTab extends StatelessWidget {
  const PetsTab({Key? key}) : super(key: key);

  void _showItemDialog(BuildContext context, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (_) => ShopDetailDialog(itemData: data, type: 'pet'),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Listen to shop_rotations/pets for the current pet IDs
    final rotationDoc = FirebaseFirestore.instance
        .collection('shop_rotations')
        .doc('pets');

    return StreamBuilder<DocumentSnapshot>(
      stream: rotationDoc.snapshots(),
      builder: (context, rotationSnapshot) {
        if (rotationSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (rotationSnapshot.hasError) {
          return Center(child: Text("Error: ${rotationSnapshot.error}"));
        }

        final rotationData =
            rotationSnapshot.data?.data() as Map<String, dynamic>? ?? {};
        final List<dynamic> currentRotation =
            rotationData['currentRotation'] ?? [];
        final Set<String> allowedIds =
        currentRotation.map((e) => e.toString()).toSet();

        if (allowedIds.isEmpty) {
          return const Center(child: Text("No pets in shop rotation."));
        }

        // Stream the pet_data collection and filter to only those in the rotation
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('pet_data').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text("Error: ${snapshot.error}"));
            }

            final docs = snapshot.data?.docs.where((doc) {
              return allowedIds.contains(doc.id);
            }).toList() ??
                [];

            if (docs.isEmpty) {
              return const Center(child: Text("No pets available in the shop."));
            }

            // Responsive grid layout
            return LayoutBuilder(
              builder: (context, constraints) {
                final gridWidth = constraints.maxWidth;
                const crossAxisCount = 3;
                final spacing = 16.0 * (crossAxisCount - 1);
                final usableWidth = gridWidth - spacing;
                final itemWidth = usableWidth / crossAxisCount;
                final itemHeight = itemWidth / 0.7;
                final childAspectRatio = itemWidth / itemHeight;

                return GridView.builder(
                  padding:
                  const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: docs.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: childAspectRatio,
                  ),
                  itemBuilder: (context, i) {
                    final doc = docs[i];
                    final raw = doc.data() as Map<String, dynamic>;
                    // Ensure the pet ID is included in the data map
                    final data = {...raw, 'id': doc.id};

                    return ShopGridCard(
                      data: data,
                      onTap: () => _showItemDialog(context, data),
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
