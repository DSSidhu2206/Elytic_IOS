// lib/frontend/screens/settings/preferences_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PreferencesPage extends StatefulWidget {
  const PreferencesPage({Key? key}) : super(key: key);

  @override
  State<PreferencesPage> createState() => _PreferencesPageState();
}

class _PreferencesPageState extends State<PreferencesPage> {
  bool _loading = true;
  String? _userId;

  String _dmPreference = 'open'; // open, friends, closed
  bool _onlineVisible = true;

  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser?.uid;
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    if (_userId == null) {
      setState(() => _loading = false);
      return;
    }
    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(_userId)
        .collection('settings')
        .doc('preferences');
    try {
      final doc = await docRef.get();
      if (doc.exists) {
        final data = doc.data() ?? {};
        setState(() {
          _dmPreference = data['dmPreference'] ?? 'open';
          _onlineVisible = (data['onlineStatusVisible'] ?? true) as bool;
          _loading = false;
        });
      } else {
        await docRef.set({
          'dmPreference': 'open',
          'onlineStatusVisible': true,
        });
        setState(() {
          _dmPreference = 'open';
          _onlineVisible = true;
          _loading = false;
        });
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load preferences: $e')),
        );
      }
    }
  }

  Future<void> _saveDmPreference(String newValue) async {
    if (_userId == null) {
      return;
    }
    setState(() => _dmPreference = newValue);
    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(_userId)
        .collection('settings')
        .doc('preferences');
    try {
      await docRef.set({
        'dmPreference': newValue,
        'onlineStatusVisible': _onlineVisible,
      }, SetOptions(merge: true));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save DM preference: $e')),
        );
      }
    }
  }

  Future<void> _saveOnlineStatus(bool visible) async {
    if (_userId == null) {
      return;
    }
    setState(() => _onlineVisible = visible);
    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(_userId)
        .collection('settings')
        .doc('preferences');
    try {
      await docRef.set({
        'dmPreference': _dmPreference,
        'onlineStatusVisible': visible,
      }, SetOptions(merge: true));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save online status: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Preferences'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.mail),
                  title: const Text('Direct Message Preference'),
                  subtitle: Text(_dmPreference == 'open'
                      ? 'Anyone can DM you'
                      : _dmPreference == 'friends'
                      ? 'Only friends can DM you'
                      : 'No one can DM you'),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: DropdownButtonFormField<String>(
                    value: _dmPreference,
                    items: const [
                      DropdownMenuItem(value: 'open', child: Text('Open')),
                      DropdownMenuItem(value: 'friends', child: Text('Friends Only')),
                      DropdownMenuItem(value: 'closed', child: Text('Closed')),
                    ],
                    onChanged: (val) {
                      if (val != null) _saveDmPreference(val);
                    },
                    decoration: const InputDecoration(
                      labelText: 'DM Preference',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.visibility),
                  title: const Text('Online Status'),
                  subtitle: Text(_onlineVisible ? 'Visible to others' : 'Not visible to others'),
                  trailing: Switch(
                    value: _onlineVisible,
                    onChanged: _saveOnlineStatus,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
