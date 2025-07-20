// lib/frontend/widgets/moderation/admin_actions_popup.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // <-- Needed for user ID

class AdminActionsPopup extends StatefulWidget {
  final String targetUserId;
  final String targetUsername;

  // You need to pass current admin username and avatar here for gifter info
  final String currentAdminUsername;
  final String currentAdminAvatar;

  const AdminActionsPopup({
    super.key,
    required this.targetUserId,
    required this.targetUsername,
    required this.currentAdminUsername,
    required this.currentAdminAvatar,
  });

  @override
  State<AdminActionsPopup> createState() => _AdminActionsPopupState();
}

class _AdminActionsPopupState extends State<AdminActionsPopup> {
  int selectedTier = 0;
  String selectedDuration = '1 month';

  static const Map<int, String> tierLabels = {
    0: "none",
    1: "basic",
    2: "plus",
    3: "royalty",
    4: "junior mod",
    5: "senior mod",
    // 6 removed (admin should not be settable)
  };

  static const Map<String, int> durationToMonths = {
    "1 month": 1,
    "3 months": 3,
    "6 months": 6,
    "12 months": 12,
  };

  static const List<String> durationOptions = [
    "1 month",
    "3 months",
    "6 months",
    "12 months",
  ];

  Future<void> _setTier(
      BuildContext context, int newTier, String durationLabel) async {
    final now = DateTime.now();
    int months = durationToMonths[durationLabel] ?? 1;
    final expiry = now.add(Duration(days: 30 * months));
    final tierLabel = tierLabels[newTier] ?? "custom";
    final productId =
        "admin_grant_${tierLabel}_${durationLabel.replaceAll(' ', '').replaceAll('months', 'month')}";

    final navigator = Navigator.of(context);

    // Always close popup before updating Firestore
    if (mounted && navigator.canPop()) {
      navigator.pop();
    }

    // Firestore update with all 6 parameters included
    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.targetUserId)
        .update({
      'tier': newTier,
      'subscriptionExpiry':
      (newTier > 0 && newTier <= 3) ? expiry.millisecondsSinceEpoch : null,
      'subscriptionProductId':
      (newTier > 0 && newTier <= 3) ? productId : null,
      'lastTierGifterId': FirebaseAuth.instance.currentUser!.uid, // <-- PATCHED LINE
      'lastTierGifterUsername': widget.currentAdminUsername,
      'lastTierGifterAvatar': widget.currentAdminAvatar,
      'lastTierUpgradeDuration':
      (newTier > 0 && newTier <= 3) ? durationLabel : null,
    });

    if (!mounted) return;

    // Confirmation dialog
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Success'),
        content: Text(
            "${widget.targetUsername}'s tier set to $newTier (${tierLabel == "none" ? "No tier" : tierLabel})"
                "${(newTier > 0 && newTier <= 3) ? "\nDuration: $durationLabel\nProduct ID: $productId\nExpires: ${expiry.toLocal()}" : ""}"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.targetUserId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const AlertDialog(
            title: Text('Admin Options'),
            content: Center(child: CircularProgressIndicator()),
          );
        }
        final userData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final int currentTier = userData['tier'] ?? 0;

        // Only show tiers 0-5
        final List<int> selectableTiers = [0, 1, 2, 3, 4, 5];

        return AlertDialog(
          title: Text('Admin Options for ${widget.targetUsername}'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Current Tier: $currentTier"
                    " (${tierLabels[currentTier]?[0].toUpperCase() ?? ""}${tierLabels[currentTier]?.substring(1) ?? ""})",
                    style: TextStyle(
                        color: Colors.blueGrey[700],
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                ...selectableTiers.map((index) {
                  return ListTile(
                    title: Text(
                        'Set Tier $index'
                            '${tierLabels.containsKey(index) ? " (${tierLabels[index]![0].toUpperCase() + tierLabels[index]!.substring(1)})" : ""}'),
                    trailing: (selectedTier == index)
                        ? const Icon(Icons.check, color: Colors.green)
                        : (currentTier == index)
                        ? const Text("Current",
                        style: TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold))
                        : null,
                    onTap: () {
                      setState(() {
                        selectedTier = index;
                      });
                    },
                  );
                }).toList(),
                if (selectedTier > 0 && selectedTier <= 3) ...[
                  const Divider(height: 24),
                  const Text("Select Duration:",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...durationOptions.map((d) => RadioListTile<String>(
                    title: Text(d),
                    value: d,
                    groupValue: selectedDuration,
                    onChanged: (val) {
                      if (val != null) setState(() => selectedDuration = val);
                    },
                  )),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () {
                if (selectedTier == 0) {
                  _setTier(context, selectedTier, selectedDuration);
                } else if (selectedTier > 0 && selectedTier <= 3) {
                  _setTier(context, selectedTier, selectedDuration);
                } else if (selectedTier > 3 && selectedTier <= 5) {
                  // Mod tiers: no duration needed
                  _setTier(context, selectedTier, "");
                }
              },
              child: const Text('Set Tier'),
            ),
          ],
        );
      },
    );
  }
}
