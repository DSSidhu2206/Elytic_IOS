import 'package:flutter/material.dart';

class UserProfileActionButtons extends StatelessWidget {
  final bool isLoading;
  final String? friendStatus; // deprecated, not used in logic anymore
  final VoidCallback? onAddFriend;
  final VoidCallback onUnfriend;
  final VoidCallback onBlock;
  final VoidCallback? onMessageUser;
  final String currentUserId;
  final String targetUserId;
  final Map<String, dynamic> profileData;
  final bool isBlocked;
  final List<String> friendsList; // IDs of currentUser's friends
  final List<String> sentFriendRequests; // IDs of users currentUser has sent friend requests to

  const UserProfileActionButtons({
    super.key,
    required this.isLoading,
    this.friendStatus,
    required this.onAddFriend,
    required this.onUnfriend,
    required this.onBlock,
    this.onMessageUser,
    required this.currentUserId,
    required this.targetUserId,
    required this.profileData,
    required this.isBlocked,
    required this.friendsList,
    required this.sentFriendRequests,
  });

  @override
  Widget build(BuildContext context) {
    final double buttonWidth = 180;
    final double buttonHeight = 44;
    final BorderRadius buttonRadius = BorderRadius.circular(24);

    final ButtonStyle greenButtonStyle = ElevatedButton.styleFrom(
      backgroundColor: Colors.green,
      foregroundColor: Colors.white,
      minimumSize: Size(buttonWidth, buttonHeight),
      shape: RoundedRectangleBorder(borderRadius: buttonRadius),
      textStyle: const TextStyle(fontWeight: FontWeight.bold),
      elevation: 0,
    );

    final ButtonStyle redButtonStyle = ElevatedButton.styleFrom(
      backgroundColor: Colors.red,
      foregroundColor: Colors.white,
      minimumSize: Size(buttonWidth, buttonHeight),
      shape: RoundedRectangleBorder(borderRadius: buttonRadius),
      textStyle: const TextStyle(fontWeight: FontWeight.bold),
      elevation: 0,
    );

    final ButtonStyle blackButtonStyle = ElevatedButton.styleFrom(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      minimumSize: Size(buttonWidth, buttonHeight),
      shape: RoundedRectangleBorder(borderRadius: buttonRadius),
      textStyle: const TextStyle(fontWeight: FontWeight.bold),
      elevation: 0,
    );

    // Decide friend button based on friendsList and sentFriendRequests
    Widget friendButton;
    if (friendsList.contains(targetUserId)) {
      // User is a friend
      friendButton = ElevatedButton(
        onPressed: isLoading ? null : onUnfriend,
        style: redButtonStyle,
        child: const Text('Unfriend'),
      );
    } else if (sentFriendRequests.contains(targetUserId)) {
      // Friend request sent and pending
      friendButton = ElevatedButton(
        onPressed: null,
        style: greenButtonStyle,
        child: const Text('Request Sent'),
      );
    } else {
      // Neither friend nor request sent
      friendButton = ElevatedButton(
        onPressed: isLoading ? null : onAddFriend,
        style: greenButtonStyle,
        child: const Text('Add Friend'),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton.icon(
          onPressed: isLoading ? null : onMessageUser,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            minimumSize: Size(buttonWidth, buttonHeight),
            shape: RoundedRectangleBorder(borderRadius: buttonRadius),
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
            elevation: 0,
          ),
          icon: const Icon(Icons.message),
          label: const Text('Message User'),
        ),
        const SizedBox(height: 12),

        ElevatedButton(
          onPressed: isLoading
              ? null
              : () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Gift sent (placeholder)!")),
            );
          },
          style: greenButtonStyle,
          child: const Text('Gift'),
        ),
        const SizedBox(height: 12),

        friendButton,
        const SizedBox(height: 12),

        ElevatedButton(
          onPressed: isLoading ? null : onBlock,
          style: redButtonStyle,
          child: Text(isBlocked ? 'Unblock' : 'Block'),
        ),
        const SizedBox(height: 12),

        ElevatedButton(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("More actions coming soon!")),
            );
          },
          style: blackButtonStyle,
          child: const Text('More'),
        ),
      ],
    );
  }
}
