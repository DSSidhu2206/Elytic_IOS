// lib/frontend/screens/profile/settings_account_tab.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../../widgets/shop/admin_shop_item_button.dart';
import '../../settings/blocked_users_page.dart'; // <-- Import the new page here
import '../../settings/preferences_page.dart';    // <-- ADD THIS IMPORT

// Import the two new separate pages
import '../../profile/change_email_page.dart';
import '../../profile/change_password_page.dart';
// Import the new ChangeUsernamePage
import '../../profile/change_username_page.dart';

// NEW: Import your referral page here!
import '../../referrals/referral_page.dart'; // <-- Update path as needed

class SettingsAccountTab extends StatefulWidget {
  const SettingsAccountTab({super.key});

  @override
  State<SettingsAccountTab> createState() => _SettingsAccountTabState();
}

class _SettingsAccountTabState extends State<SettingsAccountTab> {
  late final String userId;
  int? _userTier;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    userId = FirebaseAuth.instance.currentUser!.uid;
    _fetchUserTier();
  }

  Future<void> _fetchUserTier() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      setState(() {
        _userTier = _parseTier(snap.data()?['tier']);
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _userTier = 0;
        _loading = false;
      });
    }
  }

  int _parseTier(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  Future<void> _handleLogout() async {
    final db = FirebaseDatabase.instance;
    try {
      final presenceSnapshot = await db.ref('presence').get();
      if (presenceSnapshot.exists) {
        final roomsMap = presenceSnapshot.value as Map<dynamic, dynamic>;
        for (final roomId in roomsMap.keys) {
          final usersMap = roomsMap[roomId] as Map<dynamic, dynamic>?;
          if (usersMap != null && usersMap.containsKey(userId)) {
            await db.ref('presence/$roomId/$userId').remove();
          }
        }
      }
    } catch (e) {}
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context)
          .pushNamedAndRemoveUntil('/landing', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.email),
                title: const Text('Change Email'),
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const ChangeEmailPage(),
                  ));
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.lock),
                title: const Text('Change Password'),
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const ChangePasswordPage(),
                  ));
                },
              ),
              const Divider(height: 1),

              // NEW: Change Username Button
              ListTile(
                leading: const Icon(Icons.person),
                title: const Text('Change Username'),
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const ChangeUsernamePage(),
                  ));
                },
              ),
              const Divider(height: 1),

              // <-- NEW BLOCKED USERS BUTTON HERE -->
              ListTile(
                leading: const Icon(Icons.block),
                title: const Text('Blocked Users'),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const BlockedUsersPage(),
                    ),
                  );
                },
              ),
              const Divider(height: 1),

              // --- PREFERENCES BUTTON ADDED BELOW ---
              ListTile(
                leading: const Icon(Icons.tune),
                title: const Text('Preferences'),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PreferencesPage(),
                    ),
                  );
                },
              ),
              const Divider(height: 1),

              // --- REFERRALS BUTTON ADDED BELOW ---
              ListTile(
                leading: const Icon(Icons.card_giftcard),
                title: const Text('Referrals'),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ReferralPage(currentUsername: ''), // <-- pass username if needed
                    ),
                  );
                },
              ),
              const Divider(height: 1),

              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Logout'),
                onTap: _handleLogout,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete Account'),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Coming soon!')),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (_userTier == 6)
          Column(
            children: [
              AddAdminShopItemButton(shopTab: "pets", currentUserTier: _userTier!),
              const SizedBox(height: 8),
              AddAdminShopItemButton(shopTab: "items", currentUserTier: _userTier!),
              const SizedBox(height: 8),
              // NEW: Avatar Border upload for Admins
              AddAdminShopItemButton(shopTab: "avatar_borders", currentUserTier: _userTier!),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.sync),
                label: const Text("Shop Rotation"),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.of(context).pushNamed(
                    '/shop_rotation',
                    arguments: {
                      'currentUserId': userId,
                      'currentUserTier': _userTier,
                    },
                  );
                },
              ),
            ],
          ),
      ],
    );
  }
}
