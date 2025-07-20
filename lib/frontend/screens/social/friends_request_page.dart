// lib/frontend/screens/social/friends_request_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:elytic/frontend/helpers/avatar_helper.dart';
import 'package:elytic/backend/services/user_service.dart';

class FriendRequestInfo {
  final String senderId;
  final String displayStatus;
  FriendRequestInfo({required this.senderId, required this.displayStatus});
}

class FriendsRequestPage extends StatefulWidget {
  final String currentUserId;
  final int currentUserTier;
  final ValueChanged<int>? onRequestCountChanged;

  const FriendsRequestPage({
    Key? key,
    required this.currentUserId,
    required this.currentUserTier,
    this.onRequestCountChanged,
  }) : super(key: key);

  @override
  State<FriendsRequestPage> createState() => _FriendsRequestPageState();
}

class _FriendsRequestPageState extends State<FriendsRequestPage> {
  final Set<String> _optimisticallyAccepted = {};
  List<UserDisplayInfo> _userInfos = [];
  List<FriendRequestInfo> _requestsInfo = [];
  List<String> _lastIds = [];
  bool _loading = false;

  int? _lastRequestCount;

  Stream<List<FriendRequestInfo>> _pendingRequestsStream(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('friendRequests')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) {
      final incomingDocs = snap.docs.where((doc) {
        final data = doc.data();
        final displayStatus = data['displayStatus'] ?? data['status'] ?? '';
        // Exclude requests with displayStatus 'sent'
        return (data['requestType'] == null || data['requestType'] == 'received') && displayStatus != 'sent';
      }).toList();

      final incomingCount = incomingDocs.length;

      return incomingDocs.map((doc) {
        final data = doc.data();
        return FriendRequestInfo(
          senderId: doc.id,
          displayStatus: data['displayStatus'] ?? data['status'] ?? 'pending',
        );
      }).toList();
    });
  }

  Future<void> _fetchRequesters(List<String> ids) async {
    setState(() => _loading = true);
    if (ids.isEmpty) {
      setState(() {
        _userInfos = [];
        _requestsInfo = [];
        _loading = false;
      });
      return;
    }
    final infos = await UserService.fetchMultipleProfileInfos(ids);
    setState(() {
      _userInfos = ids.map((id) => infos[id]!).toList();
      _loading = false;
    });
  }

  Future<void> _acceptRequest(String senderId) async {
    setState(() {
      _optimisticallyAccepted.add(senderId);
    });
    final functions = FirebaseFunctions.instance;
    final callable = functions.httpsCallable('acceptFriendRequest');
    try {
      await callable.call(<String, dynamic>{
        'senderId': senderId,
      });
    } catch (e) {
      setState(() {
        _optimisticallyAccepted.remove(senderId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to accept request. Please try again.')),
      );
    }
  }

  Future<void> _declineRequest(String senderId) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.currentUserId)
        .collection('friendRequests')
        .doc(senderId)
        .delete();
  }

  @override
  Widget build(BuildContext context) {
    final uid = widget.currentUserId;
    return StreamBuilder<List<FriendRequestInfo>>(
      stream: _pendingRequestsStream(uid),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final allRequests = (snap.data ?? [])
            .where((req) => !_optimisticallyAccepted.contains(req.senderId))
            .toList();

        // Filter for incoming requests (displayStatus == 'pending') only for badge count
        final incomingRequests = allRequests.where((req) => req.displayStatus == 'pending').toList();

        final incomingIds = incomingRequests.map((e) => e.senderId).toList();

        // Notify parent only if count changes
        if (_lastRequestCount != incomingIds.length) {
          _lastRequestCount = incomingIds.length;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.onRequestCountChanged?.call(incomingIds.length);
          });
        }

        if (allRequests.isEmpty) {
          return const Center(child: Text('No friend requests.'));
        }

        final ids = allRequests.map((e) => e.senderId).toList();

        // Defer fetch to after build to avoid setState during build
        if (_lastIds.length != ids.length || !_lastIds.toSet().containsAll(ids)) {
          _lastIds = List.from(ids);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _fetchRequesters(ids);
          });
          return const Center(child: CircularProgressIndicator());
        }

        if (_loading) {
          return const Center(child: CircularProgressIndicator());
        }

        return ListView.builder(
          itemCount: _userInfos.length,
          itemBuilder: (ctx, i) {
            final user = _userInfos[i];
            final requestInfo = allRequests.firstWhere((r) => r.senderId == user.userId);

            return ListTile(
              leading: CircleAvatar(
                backgroundImage: getAvatarImageProvider(user.avatarUrl),
              ),
              title: Text(user.username),
              subtitle: Text(requestInfo.displayStatus), // Show displayStatus here
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check_circle, color: Colors.green),
                    onPressed: () async {
                      await _acceptRequest(user.userId);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel, color: Colors.red),
                    onPressed: () async {
                      await _declineRequest(user.userId);
                    },
                  ),
                ],
              ),
              onTap: () {
                if (user.userId == uid) return;
                Navigator.pushNamed(
                  context,
                  '/user_profile',
                  arguments: {
                    'userId': user.userId,
                    'currentUserId': uid,
                    'currentUserTier': widget.currentUserTier,
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

