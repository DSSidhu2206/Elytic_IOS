// lib/frontend/widgets/common/user_search_and_list_widget.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elytic/frontend/helpers/avatar_helper.dart';
import 'package:elytic/frontend/widgets/common/elytic_loader.dart';
import 'package:elytic/backend/services/user_service.dart';

class UserSearchAndListWidget extends StatefulWidget {
  final String currentUserId;
  final int? currentUserTier;
  final void Function(UserDisplayInfo user)? onUserSelected;
  final bool showRemoveFriend;
  final bool showOnlyFriends;

  const UserSearchAndListWidget({
    Key? key,
    required this.currentUserId,
    this.currentUserTier,
    this.onUserSelected,
    this.showRemoveFriend = false,
    this.showOnlyFriends = false,
  }) : super(key: key);

  @override
  State<UserSearchAndListWidget> createState() => _UserSearchAndListWidgetState();
}

class _UserSearchAndListWidgetState extends State<UserSearchAndListWidget> {
  final TextEditingController _searchController = TextEditingController();
  String _searchTerm = '';
  bool _searchLoading = false;
  List<UserDisplayInfo> _searchResults = [];

  Map<String, UserDisplayInfo> _friendsCache = {};
  List<String> _lastFriendIds = [];

  Future<void> _preFetchFriendProfiles(List<String> friendIds) async {
    if (friendIds.isEmpty) return;

    // Only fetch if friend IDs list has changed
    if (_listEquals(friendIds, _lastFriendIds)) return;
    _lastFriendIds = friendIds;

    // Use UserService batching and cache
    final fetched = await UserService.fetchMultipleProfileInfos(friendIds);

    bool changed = false;
    fetched.forEach((key, value) {
      if (!_friendsCache.containsKey(key) ||
          _friendsCache[key]?.username != value.username ||
          _friendsCache[key]?.avatarUrl != value.avatarUrl) {
        changed = true;
      }
    });

    if (changed) {
      setState(() {
        _friendsCache = {..._friendsCache, ...fetched};
      });
    }
  }

  Stream<List<UserDisplayInfo>> _friendsStream(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('friends')
        .snapshots()
        .asyncMap((snap) async {
      final friendIds = snap.docs.map((doc) => doc.id).toList();
      await _preFetchFriendProfiles(friendIds);

      return friendIds
          .map((id) => _friendsCache[id] ?? UserDisplayInfo.fromMap(id, null))
          .toList();
    });
  }

  Future<void> _runUserSearch(String term) async {
    if (term.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _searchLoading = false;
      });
      return;
    }
    setState(() {
      _searchLoading = true;
    });

    final q = term.trim().toLowerCase();
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .orderBy('username_lowercase')
        .startAt([q])
        .endAt([q + '\uf8ff'])
        .limit(50)
        .get();

    final ids = snap.docs.map((doc) => doc.id).toList();
    final fetched = await UserService.fetchMultipleProfileInfos(ids);

    setState(() {
      _searchResults = ids.map((id) => fetched[id] ?? UserDisplayInfo.fromMap(id, null)).toList();
      _searchLoading = false;
    });
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      final nextTerm = _searchController.text.trim();
      if (_searchTerm != nextTerm) {
        setState(() {
          _searchTerm = nextTerm;
        });
        _runUserSearch(nextTerm);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = widget.currentUserId;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: "Search for any user...",
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
              isDense: true,
            ),
          ),
        ),
        Expanded(
          child: _searchTerm.isNotEmpty
              ? _searchLoading
              ? const Center(child: ElyticLoader())
              : _buildSearchResults(context, uid)
              : StreamBuilder<List<UserDisplayInfo>>(
            stream: _friendsStream(uid),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: ElyticLoader());
              }
              final friends = snap.data!;
              if (friends.isEmpty) return const Center(child: Text('No friends yet.'));
              return ListView.builder(
                itemCount: friends.length,
                itemBuilder: (ctx, i) {
                  final f = friends[i];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: getAvatarImageProvider(f.avatarUrl),
                    ),
                    title: Text(f.username),
                    trailing: widget.showRemoveFriend
                        ? IconButton(
                      icon: const Icon(Icons.remove_circle, color: Colors.red),
                      onPressed: () {
                        // Add your remove logic here, or expose a callback!
                      },
                    )
                        : null,
                    onTap: () => widget.onUserSelected?.call(f),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResults(BuildContext context, String uid) {
    return Builder(
      builder: (_) {
        if (!_searchLoading && _searchResults.isEmpty && _searchTerm.isNotEmpty) {
          return const Center(child: Text('No users found.'));
        }

        return ListView.builder(
          itemCount: _searchResults.length,
          itemBuilder: (ctx, i) {
            final user = _searchResults[i];
            final isMe = user.userId == uid;
            // For friends check, use _friendsCache
            final isFriend = _friendsCache.containsKey(user.userId);
            return ListTile(
              leading: CircleAvatar(
                backgroundImage: getAvatarImageProvider(user.avatarUrl),
              ),
              title: Text(user.username),
              subtitle: isMe
                  ? const Text('This is you', style: TextStyle(color: Colors.grey))
                  : isFriend
                  ? const Text('Friend', style: TextStyle(color: Colors.green))
                  : null,
              onTap: isMe ? null : () => widget.onUserSelected?.call(user),
            );
          },
        );
      },
    );
  }
}
