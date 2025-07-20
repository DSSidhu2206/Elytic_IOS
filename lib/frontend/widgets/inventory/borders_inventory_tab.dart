// lib/frontend/widgets/inventory/borders_inventory_tab.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:elytic/backend/services/presence_service.dart';

// PATCH: Added fields for presence update (current lounge info)
class BordersInventoryTab extends StatelessWidget {
  final String roomId;
  final String userName;
  final int tier;
  final double x;
  final double y;

  const BordersInventoryTab({
    Key? key,
    required this.roomId,
    required this.userName,
    required this.tier,
    required this.x,
    required this.y,
  }) : super(key: key);

  Future<List<Map<String, dynamic>>> _fetchBorderData(List<String> borderIds) async {
    final firestore = FirebaseFirestore.instance;
    final futures = borderIds.map((borderId) async {
      final doc = await firestore.collection('avatar_border_data').doc(borderId).get();
      if (!doc.exists) return null;
      final data = doc.data()!..['borderId'] = borderId;
      return data;
    }).toList();
    final results = await Future.wait(futures);
    return results.whereType<Map<String, dynamic>>().toList();
  }

  // PATCH: Save both border ID and border URL, update presence cache, update RTDB
  Future<void> _useBorder({
    required BuildContext context,
    required String borderId,
    required String? borderUrl,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    // Changed: Save directly under users/{userId}, not settings/cosmetics
    final userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

    // Save both ID and URL for robustness directly under user doc
    await userDocRef.set({
      'selectedAvatarBorderId': borderId,
      'selectedAvatarBorderUrl': borderUrl ?? '',
    }, SetOptions(merge: true));

    // Update cache immediately so UI/avatar updates
    if (borderUrl != null) {
      PresenceService.setCachedBorderUrl(user.uid, borderUrl);
    }

    // PATCH: Fetch up-to-date avatarUrl for RTDB update
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final currentAvatarUrl = userDoc.data()?['avatarUrl'] ?? '';

    // Instantly update RTDB lounge presence node!
    await PresenceService.updateUserPosition(
      userId: user.uid,
      roomId: roomId,
      userName: userName,
      avatarUrl: currentAvatarUrl,
      tier: tier,
      x: x,
      y: y,
      userAvatarBorderUrl: borderUrl,
    );
  }

  void _showUseDialog(BuildContext context, String borderId, String? imageUrl, String? name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Use this Avatar Border?"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            imageUrl != null
                ? ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                height: 82,
                width: 82,
                fit: BoxFit.cover,
                errorWidget: (c, e, s) => const Icon(Icons.broken_image, size: 82),
                placeholder: (c, s) => const SizedBox(
                  height: 82,
                  width: 82,
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              ),
            )
                : const Icon(Icons.panorama_fish_eye, size: 82),
            const SizedBox(height: 12),
            Text(
              name ?? borderId,
              style: const TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            const Text(
              "Do you want to use this border for your avatar?",
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              await _useBorder(context: context, borderId: borderId, borderUrl: imageUrl);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Border set as active!')),
              );
            },
            child: const Text("Use"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text('Not signed in.'));

    final userBordersRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('avatar_borders');

    return StreamBuilder<QuerySnapshot>(
      stream: userBordersRef.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No avatar borders owned.'));
        }
        final docs = snapshot.data!.docs;
        final borderIds = docs.map((doc) => doc.id).toList();
        if (borderIds.isEmpty) {
          return const Center(child: Text('No avatar borders owned.'));
        }

        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _fetchBorderData(borderIds),
          builder: (context, borderSnapshot) {
            if (borderSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final borderDataList = borderSnapshot.data ?? [];
            if (borderDataList.isEmpty) {
              return const Center(child: Text('No matching borders found.'));
            }
            return GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 160, // max width per card
                mainAxisSpacing: 24,
                crossAxisSpacing: 16,
                childAspectRatio: 0.7,
              ),
              itemCount: borderDataList.length,
              itemBuilder: (context, i) {
                final borderData = borderDataList[i];
                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _showUseDialog(
                    context,
                    borderData['borderId'] ?? '',
                    borderData['image_url'],
                    borderData['name'],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      borderData['image_url'] != null
                          ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: borderData['image_url'],
                          width: 82,
                          height: 82,
                          fit: BoxFit.cover,
                          errorWidget: (c, e, s) => const Icon(Icons.broken_image, size: 82),
                          placeholder: (c, s) => const SizedBox(
                            width: 82,
                            height: 82,
                            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          ),
                        ),
                      )
                          : const Icon(Icons.panorama_fish_eye, size: 82),
                      const SizedBox(height: 8),
                      Text(
                        borderData['name'] ?? borderData['borderId'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (borderData['rarity'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            borderData['rarity'],
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.deepPurple,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
  }
}
