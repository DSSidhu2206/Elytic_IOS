// lib/frontend/screens/shop/cosmetics/profile_tab.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'cosmetics_data.dart';
import 'cosmetic_item_tile.dart';
import '../../profile/buy_username_change_token_page.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({Key? key}) : super(key: key);

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> with AutomaticKeepAliveClientMixin<ProfileTab> {
  // Owned item ID sets for live ownership tracking
  Set<String> ownedBorders = {};
  Set<String> ownedBubbles = {};
  Set<String> ownedBadges = {};
  Set<String> ownedProfiles = {};

  // Current user ID shortcut
  String get userId => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _setupOwnedListeners();
  }

  void _setupOwnedListeners() {
    if (userId.isEmpty) return;

    FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('avatar_borders')
        .snapshots()
        .listen((snapshot) {
      setState(() {
        ownedBorders =
            snapshot.docs.map((doc) => doc['avatar_border_id'] as String).toSet();
      });
    });

    FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('chat_bubbles')
        .snapshots()
        .listen((snapshot) {
      setState(() {
        ownedBubbles =
            snapshot.docs.map((doc) => doc['chat_bubble_id'] as String).toSet();
      });
    });

    FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('badges')
        .snapshots()
        .listen((snapshot) {
      setState(() {
        ownedBadges = snapshot.docs.map((doc) => doc['badge_id'] as String).toSet();
      });
    });

    FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('profiles')
        .snapshots()
        .listen((snapshot) {
      setState(() {
        ownedProfiles =
            snapshot.docs.map((doc) => doc['profile_id'] as String).toSet();
      });
    });
  }

  Future<Map<String, List<String>>> _fetchRotationIds() async {
    const docKeys = {
      'avatar_borders': 'avatar_borders',
      'chat_bubbles': 'chat_bubbles',
      'badges': 'badges',
      'profiles': 'profiles',
    };
    final Map<String, List<String>> out = {};
    for (final entry in docKeys.entries) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('shop_rotations')
            .doc(entry.value)
            .get();
        final arr = (doc.data()?['currentRotation'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
            [];
        out[entry.key] = arr;
      } catch (e) {
        out[entry.key] = [];
      }
    }
    return out;
  }

  Widget _buildSectionResponsive(
      String title, List<CosmeticItem> items, String emptyMessage, Set<String> ownedSet) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(emptyMessage),
            const SizedBox(height: 24),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: items.length,
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 160,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.9,
          ),
          itemBuilder: (_, i) => CosmeticItemTile(
            item: items[i],
            owned: ownedSet.contains(items[i].id),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // required for AutomaticKeepAliveClientMixin

    return FutureBuilder<Map<String, List<String>>>(
      future: _fetchRotationIds(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text("Error: ${snap.error}"));
        }
        final rotationIds = snap.data ?? {};
        final borderIds = rotationIds['avatar_borders'] ?? [];
        final bubbleIds = rotationIds['chat_bubbles'] ?? [];
        final badgeIds = rotationIds['badges'] ?? [];
        final profileIds = rotationIds['profiles'] ?? [];

        if (borderIds.isEmpty &&
            bubbleIds.isEmpty &&
            badgeIds.isEmpty &&
            profileIds.isEmpty) {
          return const Center(child: Text("No cosmetics in shop rotation."));
        }

        return StreamBuilder<List<CosmeticItem>>(
          stream: CosmeticsData.streamItemsByIds(
              category: 'avatar_borders', ids: borderIds),
          builder: (context, borderSnap) {
            final avatarBorders = borderSnap.data ?? [];
            return StreamBuilder<List<CosmeticItem>>(
              stream: CosmeticsData.streamItemsByIds(
                  category: 'chat_bubbles', ids: bubbleIds),
              builder: (context, bubbleSnap) {
                final chatBubbles = bubbleSnap.data ?? [];
                return StreamBuilder<List<CosmeticItem>>(
                  stream: CosmeticsData.streamItemsByIds(
                      category: 'badges', ids: badgeIds),
                  builder: (context, badgeSnap) {
                    return StreamBuilder<List<CosmeticItem>>(
                      stream: CosmeticsData.streamItemsByIds(
                          category: 'profiles', ids: profileIds),
                      builder: (context, profileSnap) {
                        final profiles = profileSnap.data ?? [];
                        return SingleChildScrollView(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionResponsive("Avatar Borders", avatarBorders,
                                  "No avatar borders in shop right now.", ownedBorders),
                              _buildSectionResponsive("Chat Bubbles", chatBubbles,
                                  "No chat bubbles in shop right now.", ownedBubbles),
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.token),
                                  label: const Text("Buy Username Change Tokens"),
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => const BuyUsernameChangeTokenPage(),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              if (profiles.isNotEmpty) ...[
                                const Text(
                                  "Profiles",
                                  style: TextStyle(
                                      fontSize: 20, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                GridView.builder(
                                  physics: const NeverScrollableScrollPhysics(),
                                  shrinkWrap: true,
                                  itemCount: profiles.length,
                                  gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 160,
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 16,
                                    childAspectRatio: 0.9,
                                  ),
                                  itemBuilder: (_, i) => CosmeticItemTile(
                                    item: profiles[i],
                                    owned: ownedProfiles.contains(profiles[i].id),
                                  ),
                                ),
                              ],
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

  @override
  bool get wantKeepAlive => true;
}
