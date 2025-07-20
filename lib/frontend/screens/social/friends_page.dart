// lib/frontend/screens/social/friends_page.dart

import 'package:flutter/material.dart';
import 'package:elytic/frontend/screens/social/friends_list_page.dart';
import 'package:elytic/frontend/screens/social/friends_request_page.dart';
import 'package:elytic/frontend/widgets/common/notification_badge.dart';

class FriendsPage extends StatefulWidget {
  final String currentUserId;
  final int currentUserTier;

  const FriendsPage({
    Key? key,
    required this.currentUserId,
    required this.currentUserTier,
  }) : super(key: key);

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  int _requestsCount = 0;

  void _onRequestsCountChanged(int count) {
    setState(() {
      _requestsCount = count;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Friends")),
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            TabBar(
              tabs: [
                const Tab(icon: Icon(Icons.people), text: "Friends"),
                Tab(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.person_add),
                          SizedBox(width: 4),
                          Text("Requests"),
                        ],
                      ),
                      if (_requestsCount > 0)
                        Positioned(
                          right: -12,
                          top: -4,
                          child: NotificationBadge(count: _requestsCount, size: 18),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  FriendsListPage(
                    currentUserId: widget.currentUserId,
                    currentUserTier: widget.currentUserTier,
                  ),
                  FriendsRequestPage(
                    currentUserId: widget.currentUserId,
                    currentUserTier: widget.currentUserTier,
                    onRequestCountChanged: _onRequestsCountChanged,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

