// lib/frontend/widgets/common/online_status_dot.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';

class OnlineStatusDot extends StatefulWidget {
  final String userId;
  final double size; // default 30px

  const OnlineStatusDot({
    Key? key,
    required this.userId,
    this.size = 30.0,
  }) : super(key: key);

  @override
  State<OnlineStatusDot> createState() => _OnlineStatusDotState();
}

class _OnlineStatusDotState extends State<OnlineStatusDot> {
  bool? onlineStatusVisible;
  bool? isOnline;

  @override
  void initState() {
    super.initState();
    _fetchOnlineStatusVisible();
  }

  Future<void> _fetchOnlineStatusVisible() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('settings')
          .doc('preferences')
          .get();

      final data = doc.data();
      setState(() {
        // PATCH: Assume visible=true if field is missing
        onlineStatusVisible = data == null || !data.containsKey('onlineStatusVisible')
            ? true
            : data['onlineStatusVisible'] == true;
      });

      if (onlineStatusVisible == true) {
        _checkUserPresence();
      } else {
        setState(() {
          isOnline = false;
        });
      }
    } catch (e) {
      setState(() {
        onlineStatusVisible = true; // PATCH: Default to visible on error
        isOnline = false;
      });
    }
  }

  Future<void> _checkUserPresence() async {
    try {
      final dbRef = FirebaseDatabase.instance.ref("presence");
      final snapshot = await dbRef.get();
      bool found = false;

      if (snapshot.exists) {
        for (final roomEntry in snapshot.children) {
          // roomEntry: /presence/{roomId}
          final userSnap = roomEntry.child(widget.userId);
          if (userSnap.exists) {
            final state = userSnap.child('state').value;
            if (state == 'online') {
              found = true;
              break;
            }
          }
        }
      }

      setState(() {
        isOnline = found;
      });
    } catch (e) {
      setState(() {
        isOnline = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final showDot = onlineStatusVisible != null && isOnline != null;

    Color dotColor = Colors.grey;
    if (onlineStatusVisible == true && isOnline == true) {
      dotColor = Colors.green;
    }

    return AnimatedOpacity(
      opacity: showDot ? 1 : 0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: dotColor,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: 2.2,
          ),
        ),
      ),
    );
  }
}
