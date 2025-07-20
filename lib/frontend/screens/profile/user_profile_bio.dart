import 'package:flutter/material.dart';
import 'package:elytic/frontend/helpers/avatar_helper.dart';

class UserProfileBioSection extends StatelessWidget {
  final Map<String, dynamic> data;
  const UserProfileBioSection({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final avatar = data['avatarPath'] as String? ?? 'assets/avatars/default.png';
    final bio = (data['bio'] as String?)?.trim() ?? '';

    return Column(
      children: [
        CircleAvatar(
          radius: 60,
          backgroundImage: getAvatarImageProvider(avatar),
        ),
        const SizedBox(height: 16),
        Text(
          bio.isNotEmpty ? bio : 'User hasn\'t written a bio yet.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
        ),
      ],
    );
  }
}
