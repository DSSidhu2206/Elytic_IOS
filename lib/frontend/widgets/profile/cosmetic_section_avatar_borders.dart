// lib/frontend/widgets/profile/cosmetic_section_avatar_borders.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/cosmetic_meta.dart';
import 'cosmetic_previews.dart';
// PATCH: import PresenceService (not needed in Option 2) - removed

class CosmeticSectionAvatarBorders extends StatefulWidget {
  // PATCH: Remove all extra required fields, no args needed now
  const CosmeticSectionAvatarBorders({
    Key? key,
  }) : super(key: key);

  @override
  State<CosmeticSectionAvatarBorders> createState() => _CosmeticSectionAvatarBordersState();
}

class _CosmeticSectionAvatarBordersState extends State<CosmeticSectionAvatarBorders> {
  List<AvatarBorderMeta> borderMetas = [];
  Set<String> ownedBorders = {};
  String? selectedAvatarBorderId;
  bool loading = true;
  bool saving = false;
  final String userId = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    loadBorderData();
  }

  Future<void> loadBorderData() async {
    setState(() => loading = true);

    final metaSnap = await FirebaseFirestore.instance.collection(
        'avatar_border_data').get();
    final allMetas = metaSnap.docs.map((doc) =>
        AvatarBorderMeta.fromFirestore(doc.data())).toList();

    final invSnap = await FirebaseFirestore.instance
        .collection('users').doc(userId)
        .collection('inventory').doc('avatar_borders')
        .collection('avatar_border_inventory').get();

    final ownedSet = invSnap.docs.map((doc) =>
    doc.data()['avatar_border_id'] as String).toSet();

    String? selected;
    final settingsSnap = await FirebaseFirestore.instance
        .collection('users').doc(userId)
        .collection('settings').doc('cosmetics').get();
    if (settingsSnap.exists) {
      selected = settingsSnap.data()!['selectedAvatarBorderId'] as String?;
    }
    if (selected == null && ownedSet.isNotEmpty) selected = ownedSet.first;

    setState(() {
      borderMetas =
      allMetas..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
      ownedBorders = ownedSet;
      selectedAvatarBorderId = selected;
      loading = false;
    });
  }

  Future<void> saveSelectedAvatarBorder(String borderId) async {
    setState(() {
      saving = true;
      selectedAvatarBorderId = borderId;
    });
    await FirebaseFirestore.instance
        .collection('users').doc(userId)
        .collection('settings').doc('cosmetics')
        .set({'selectedAvatarBorderId': borderId}, SetOptions(merge: true));

    // PATCH: Remove RTDB presence update, not needed in Option 2

    setState(() => saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Avatar border updated!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Avatar Border",
            style: Theme
                .of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        borderMetas.isEmpty
            ? Text(
            "No avatar borders available.", style: TextStyle(color: Colors.red))
            : SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: borderMetas.length,
            separatorBuilder: (_, __) => SizedBox(width: 18),
            itemBuilder: (context, i) {
              final meta = borderMetas[i];
              final isOwned = ownedBorders.contains(meta.id);
              final isSelected = isOwned && meta.id == selectedAvatarBorderId;
              return Opacity(
                opacity: isOwned ? 1 : 0.4,
                child: GestureDetector(
                  onTap: isOwned && !saving
                      ? () async => await saveSelectedAvatarBorder(meta.id)
                      : null,
                  child: Container(
                    decoration: BoxDecoration(
                      border: isSelected
                          ? Border.all(color: Colors.blueAccent, width: 3)
                          : null,
                      borderRadius: BorderRadius.circular(100),
                      boxShadow: isSelected
                          ? [
                        BoxShadow(color: Colors.blueAccent.withOpacity(0.08),
                            blurRadius: 4)
                      ]
                          : [],
                    ),
                    width: 75,
                    height: 75,
                    padding: const EdgeInsets.all(4),
                    child: avatarBorderPreviewImage(meta.imageUrl),
                  ),
                ),
              );
            },
          ),
        ),
        if (saving)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}
