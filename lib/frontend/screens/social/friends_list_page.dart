// lib/frontend/screens/social/friends_list_page.dart

import 'package:flutter/material.dart';
import 'package:elytic/backend/services/user_service.dart';
import 'package:elytic/frontend/widgets/common/user_search_and_list_widget.dart';

/// Shows a list of the user's friends with navigation to profile on tap.
/// Uses [UserDisplayInfo] for type safety and efficient caching.
class FriendsListPage extends StatelessWidget {
  final String currentUserId;
  final int currentUserTier;

  const FriendsListPage({
    Key? key,
    required this.currentUserId,
    required this.currentUserTier,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return UserSearchAndListWidget(
      currentUserId: currentUserId,
      currentUserTier: currentUserTier,
      showRemoveFriend: true,
      // PATCH: Use UserDisplayInfo, not Map
      onUserSelected: (user) {
        if (user.userId == currentUserId) return; // Prevent opening your own profile
        Navigator.pushNamed(
          context,
          '/user_profile',
          arguments: {
            'userId': user.userId,
            'currentUserId': currentUserId,
            'currentUserTier': currentUserTier,
          },
        );
      },
    );
  }
}
