// lib/frontend/screens/settings/settings_screen.dart

import 'package:flutter/material.dart';
import 'settings_tabs/notifications_tab.dart';
import 'settings_tabs/settings_app_tab.dart';
import 'settings_tabs/settings_account_tab.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.notifications), text: 'Notifications'),
              Tab(icon: Icon(Icons.tune), text: 'App'),
              Tab(icon: Icon(Icons.person), text: 'Account'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            NotificationsTab(),
            SettingsAppTab(),
            SettingsAccountTab(),
          ],
        ),
      ),
    );
  }
}
