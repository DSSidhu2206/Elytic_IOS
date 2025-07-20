// lib/frontend/widgets/common/user_search_and_list_dialog.dart

import 'package:flutter/material.dart';
import 'user_search_and_list_widget.dart';
import 'package:elytic/backend/services/user_service.dart'; // Import UserDisplayInfo

class UserSearchAndListDialog extends StatelessWidget {
  final String currentUserId;
  final int? currentUserTier;
  final void Function(UserDisplayInfo user) onUserSelected; // PATCHED

  const UserSearchAndListDialog({
    Key? key,
    required this.currentUserId,
    this.currentUserTier,
    required this.onUserSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: SizedBox(
        width: 350,
        height: 420,
        child: UserSearchAndListWidget(
          currentUserId: currentUserId,
          currentUserTier: currentUserTier,
          onUserSelected: (user) {
            Navigator.pop(context);
            onUserSelected(user);
          },
        ),
      ),
    );
  }
}
