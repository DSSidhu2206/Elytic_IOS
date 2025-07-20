// lib/frontend/screens/settings/blocked_users_page.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:elytic/frontend/helpers/avatar_helper.dart'; // <-- import the helper

import 'package:elytic/backend/services/friend_service.dart'; // PATCH: Use FriendService now
import 'package:elytic/backend/services/user_service.dart';

class BlockedUsersPage extends StatefulWidget {
  const BlockedUsersPage({Key? key}) : super(key: key);

  @override
  State<BlockedUsersPage> createState() => _BlockedUsersPageState();
}

class _BlockedUsersPageState extends State<BlockedUsersPage> {
  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Blocked Users'),
      ),
      body: FutureBuilder<List<UserDisplayInfo>>(
        future: FriendService.fetchBlockedUsers(currentUserId), // PATCHED
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading blocked users'));
          }

          final blockedUsers = snapshot.data ?? [];

          if (blockedUsers.isEmpty) {
            return const Center(child: Text('You have not blocked any users.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: blockedUsers.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final userInfo = blockedUsers[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: getAvatarImageProvider(userInfo.avatarUrl),
                ),
                title: Text(userInfo.username),
                trailing: ElevatedButton(
                  onPressed: () async {
                    await _unblockUser(userInfo.userId);
                    setState(() {}); // Reload after unblock
                  },
                  child: const Text('Unblock'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _unblockUser(String blockedUserId) async {
    try {
      await FriendService.unblockUser(currentUserId, blockedUserId); // PATCHED
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User unblocked successfully')),
      );
      UserService.invalidateCache(blockedUserId);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to unblock user: $e')),
      );
    }
  }
}
