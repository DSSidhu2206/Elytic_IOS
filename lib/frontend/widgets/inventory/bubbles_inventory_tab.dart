// lib/frontend/widgets/inventory/bubbles_inventory_tab.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../profile/bubble_preview_widget.dart';

class BubblesInventoryTab extends StatelessWidget {
  const BubblesInventoryTab({Key? key}) : super(key: key);

  void _showUseDialog(BuildContext context, String bubbleId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Use this Chat Bubble?"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: SizedBox(
                height: 55,
                child: bubblePreviewWidget(bubbleId),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              "Do you want to use $bubbleId as your chat bubble?",
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .set({'selectedChatBubbleId': bubbleId}, SetOptions(merge: true));
              }
              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Chat bubble $bubbleId set as active!')),
              );
            },
            child: const Text("Use"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text('Not signed in.'));

    // PATCHED: Now reads directly from chat_bubbles subcollection
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('chat_bubbles');

    return StreamBuilder<QuerySnapshot>(
      stream: ref.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || !(snapshot.data!.docs.isNotEmpty)) {
          return const Center(child: Text('No chat bubbles owned.'));
        }
        final data = snapshot.data!;
        final bubbles = data.docs.map((doc) => doc.id).toList();
        if (bubbles.isEmpty) {
          return const Center(child: Text('No chat bubbles owned.'));
        }
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 220,
            mainAxisSpacing: 20,
            crossAxisSpacing: 20,
            childAspectRatio: 0.85,
          ),
          itemCount: bubbles.length,
          itemBuilder: (context, i) {
            final bubbleId = bubbles[i];
            return InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _showUseDialog(context, bubbleId),
              child: Container(
                // Only this section is patched to ensure centering!
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center, // PATCH: Center horizontally
                  children: [
                    Expanded(
                      child: Center(
                        child: SizedBox(
                          height: 55,
                          child: bubblePreviewWidget(bubbleId),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      bubbleId,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
