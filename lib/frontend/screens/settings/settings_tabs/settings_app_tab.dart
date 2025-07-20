// lib/frontend/screens/settings/settings_tabs/settings_app_tab.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../theme/app_theme.dart';
import 'package:elytic/frontend/screens/shop/create_mystery_box_page.dart';
import 'package:elytic/frontend/screens/shop/add_badge_page.dart';
import 'package:firebase_auth/firebase_auth.dart';

// NEW import for report bug page (create this file separately)
import 'package:elytic/frontend/screens/settings/report_a_bug_page.dart';
// Import for room background update
import 'package:elytic/frontend/screens/settings/room_background_update_page.dart';
// Import for sticker upload page
import 'package:elytic/frontend/screens/settings/sticker_upload_page.dart';

class SettingsAppTab extends StatelessWidget {
  const SettingsAppTab({Key? key}) : super(key: key);

  Future<int?> _fetchUserTier() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final snap = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    return snap.data()?['tier'] as int?;
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.themeMode == ThemeMode.dark;

    return FutureBuilder<int?>(      // this fetches the user's tier
      future: _fetchUserTier(),
      builder: (context, snapshot) {
        final userTier = snapshot.data ?? 0;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: SwitchListTile(
                value: isDarkMode,
                onChanged: (val) {
                  themeNotifier.setDarkMode(val);
                },
                title: const Text('Dark Mode'),
              ),
            ),
            const SizedBox(height: 18),

            // Add the Report a Bug button - visible to all tiers
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: const Icon(Icons.bug_report),
                title: const Text('Report a Bug'),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ReportABugPage()),
                  );
                },
              ),
            ),

            // Upload/Edit Room Background button - tier 6 only
            if (userTier == 6)
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: const Icon(Icons.wallpaper),
                  title: const Text('Upload/Edit Room Background'),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const RoomBackgroundUpdatePage()),
                    );
                  },
                ),
              ),

            // Create Mystery Box button, tier 6 only
            if (userTier == 6)
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: const Icon(Icons.card_giftcard),
                  title: const Text('Create Mystery Box'),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CreateMysteryBoxPage()),
                    );
                  },
                ),
              ),

            if (userTier == 6)
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: const Icon(Icons.verified),
                  title: const Text('Add Badge'),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AddBadgePage()),
                    );
                  },
                ),
              ),

            // NEW: Upload Sticker Pack button - tier 6 only
            if (userTier == 6)
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: const Icon(Icons.sticky_note_2),
                  title: const Text('Upload Sticker Pack'),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const StickerUploadPage()),
                    );
                  },
                ),
              ),

            // Add more app-specific settings here
          ],
        );
      },
    );
  }
}
