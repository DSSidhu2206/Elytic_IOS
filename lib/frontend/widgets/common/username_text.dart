// lib/frontend/widgets/common/username_text.dart

import 'package:flutter/material.dart';

class UsernameText extends StatelessWidget {
  final String username;
  final TextStyle? style;
  final TextAlign? textAlign;

  const UsernameText({
    Key? key,
    required this.username,
    this.style,
    this.textAlign,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Text(
      username,
      style: style,
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
      textAlign: textAlign,
    );
  }
}
