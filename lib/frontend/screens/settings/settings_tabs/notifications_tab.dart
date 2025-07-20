// lib/frontend/screens/settings/settings_tabs/notifications_tab.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../notifications/notification_center_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationsTab extends StatefulWidget {
  const NotificationsTab({Key? key}) : super(key: key);

  @override
  State<NotificationsTab> createState() => _NotificationsTabState();
}

class _NotificationsTabState extends State<NotificationsTab> {
  bool _notifMessages = true;
  bool _notifMentions = true;
  bool _notifFriendRequests = true;
  bool _notifEvent = true;
  bool _notifPush = true;
  bool _loading = true;

  late final String userId;

  @override
  void initState() {
    super.initState();
    userId = FirebaseAuth.instance.currentUser!.uid;
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _loading = true);

    final prefs = await SharedPreferences.getInstance();
    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('settings')
        .doc('notifications');
    try {
      final doc = await docRef.get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        setState(() {
          _notifMessages = data['messages'] ?? prefs.getBool('notif_messages') ?? true;
          _notifMentions = data['mentions'] ?? prefs.getBool('notif_mentions') ?? true;
          _notifFriendRequests = data['friendRequests'] ?? prefs.getBool('notif_friend_requests') ?? true;
          _notifEvent = data['event'] ?? prefs.getBool('notif_event') ?? true;
          _notifPush = data['push'] ?? prefs.getBool('notif_push') ?? true;
        });
        prefs.setBool('notif_messages', _notifMessages);
        prefs.setBool('notif_mentions', _notifMentions);
        prefs.setBool('notif_friend_requests', _notifFriendRequests);
        prefs.setBool('notif_event', _notifEvent);
        prefs.setBool('notif_push', _notifPush);
      } else {
        setState(() {
          _notifMessages = prefs.getBool('notif_messages') ?? true;
          _notifMentions = prefs.getBool('notif_mentions') ?? true;
          _notifFriendRequests = prefs.getBool('notif_friend_requests') ?? true;
          _notifEvent = prefs.getBool('notif_event') ?? true;
          _notifPush = prefs.getBool('notif_push') ?? true;
        });
        await _saveAllToFirestore();
      }
    } catch (e) {
      setState(() {
        _notifMessages = prefs.getBool('notif_messages') ?? true;
        _notifMentions = prefs.getBool('notif_mentions') ?? true;
        _notifFriendRequests = prefs.getBool('notif_friend_requests') ?? true;
        _notifEvent = prefs.getBool('notif_event') ?? true;
        _notifPush = prefs.getBool('notif_push') ?? true;
      });
    }
    setState(() => _loading = false);
  }

  Future<void> _saveSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool(key, value);

    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('settings')
        .doc('notifications');
    try {
      await docRef.set({
        'messages': key == 'notif_messages' ? value : _notifMessages,
        'mentions': key == 'notif_mentions' ? value : _notifMentions,
        'friendRequests': key == 'notif_friend_requests' ? value : _notifFriendRequests,
        'event': key == 'notif_event' ? value : _notifEvent,
        'push': key == 'notif_push' ? value : _notifPush,
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> _saveAllToFirestore() async {
    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('settings')
        .doc('notifications');
    await docRef.set({
      'messages': _notifMessages,
      'mentions': _notifMentions,
      'friendRequests': _notifFriendRequests,
      'event': _notifEvent,
      'push': _notifPush,
    });
  }

  @override
  Widget build(BuildContext context) {
    return _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
      padding: const EdgeInsets.all(20),
      children: [
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            elevation: 2,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.notifications),
          label: const Text("Visit Notification Centre", style: TextStyle(fontSize: 16)),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => NotificationCenterScreen(currentUserId: userId),
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.only(bottom: 18),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle(Icons.notifications_active, 'In-App Notifications', context),
                const SizedBox(height: 8),
                SwitchListTile(
                  value: _notifMessages,
                  onChanged: (v) {
                    setState(() => _notifMessages = v);
                    _saveSetting('notif_messages', v);
                  },
                  title: const Text('Message Notifications'),
                  subtitle: const Text('Get notified when you receive a new message'),
                ),
                SwitchListTile(
                  value: _notifFriendRequests,
                  onChanged: (v) {
                    setState(() => _notifFriendRequests = v);
                    _saveSetting('notif_friend_requests', v);
                  },
                  title: const Text('Friend Request Notifications'),
                  subtitle: const Text('Get notified for friend requests'),
                ),
                SwitchListTile(
                  value: _notifEvent,
                  onChanged: (v) {
                    setState(() => _notifEvent = v);
                    _saveSetting('notif_event', v);
                  },
                  title: const Text('Event Notifications'),
                  subtitle: const Text('Updates about special events, giveaways and more'),
                ),
                SwitchListTile(
                  value: _notifMentions,
                  onChanged: (_) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Mention notifications coming soon!'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  title: Row(
                    children: const [
                      Flexible(
                        child: Text(
                          'Mention Notifications',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.hourglass_empty, size: 16, color: Colors.orange),
                    ],
                  ),
                  subtitle: const Text('Get notified when someone mentions you'),
                ),
              ],
            ),
          ),
        ),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle(Icons.phone_android, 'Push Notifications', context),
                const SizedBox(height: 8),
                SwitchListTile(
                  value: _notifPush,
                  onChanged: (v) {
                    setState(() => _notifPush = v);
                    _saveSetting('notif_push', v);
                  },
                  title: const Text('Allow Push Notifications'),
                  subtitle: const Text('Get notifications on your device even when the app is closed'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(IconData icon, String title, BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 0.1,
          ),
        ),
      ],
    );
  }
}
