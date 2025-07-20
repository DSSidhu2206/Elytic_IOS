// lib/frontend/screens/home/room_list_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:elytic/backend/services/chat_service.dart';
import 'package:elytic/backend/services/presence_service.dart';
import 'package:elytic/backend/services/user_service.dart'; // <-- PATCH: import new service
import 'package:elytic/frontend/widgets/common/elytic_loader.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Added for sessionId fetch

class RoomListScreen extends StatefulWidget {
  final String category;
  static const int roomCapacity = 40;
  static const int roomPreOpenThreshold = 30;

  const RoomListScreen({Key? key, required this.category}) : super(key: key);

  @override
  State<RoomListScreen> createState() => _RoomListScreenState();
}

class _RoomListScreenState extends State<RoomListScreen> {
  bool _isLoading = false;

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _fetchRooms() async {
    final query = await FirebaseFirestore.instance
        .collection('rooms')
        .where('category', isEqualTo: widget.category.toLowerCase())
        .orderBy('number')
        .get();
    return query.docs;
  }

  Future<String?> _getCurrentRoomId() async {
    // Optionally track current room ID in shared prefs or app state
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('currentRoomId');
  }

  Future<void> _setCurrentRoomId(String roomId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currentRoomId', roomId);
  }

  Future<void> _leaveCurrentRoomIfAny(String newRoomId, String userId) async {
    final currentRoomId = await _getCurrentRoomId();
    if (currentRoomId != null && currentRoomId != newRoomId) {
      try {
        await PresenceService.clearRoomPresence(userId, currentRoomId);
      } catch (_) {
        // Ignore errors here; presence leave best effort
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(title: Text('${widget.category} Rooms')),
          body: FutureBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
            future: _fetchRooms(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final rooms = snapshot.data!;
              final nextRoomNumber =
              rooms.isNotEmpty ? (rooms.last['number'] as int) + 1 : 1;
              final isLastRoomCrowded = rooms.isNotEmpty &&
                  (rooms.last['participantsCount'] ?? 0) >=
                      RoomListScreen.roomPreOpenThreshold;

              final List<Map<String, dynamic>> displayRooms = [
                ...rooms.map((doc) => {
                  'id': doc.id,
                  ...doc.data(),
                }),
                if (rooms.isEmpty || isLastRoomCrowded)
                  {
                    'id': null,
                    'number': rooms.isEmpty ? 1 : nextRoomNumber,
                    'participantsCount': 0,
                    'category': widget.category.toLowerCase(),
                    'capacity': RoomListScreen.roomCapacity,
                    'newRoom': true,
                  }
              ];

              return ListView.separated(
                itemCount: displayRooms.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final room = displayRooms[index];
                  final roomName = '${widget.category} ${room['number']}';
                  final isFull = (room['participantsCount'] ?? 0) >=
                      (room['capacity'] ?? RoomListScreen.roomCapacity);
                  final canJoin = !isFull;

                  return ListTile(
                    title: Text(roomName),
                    subtitle: Text(
                      'Users: ${room['participantsCount'] ?? 0} / '
                          '${room['capacity'] ?? RoomListScreen.roomCapacity}'
                          '${room['newRoom'] == true ? " (New)" : ""}',
                    ),
                    trailing: canJoin
                        ? ElevatedButton(
                      child: const Text("Join"),
                      onPressed: () async {
                        setState(() => _isLoading = true);

                        try {
                          String roomId;
                          if (room['id'] != null) {
                            roomId = room['id'];
                          } else {
                            final deterministicId =
                                '${widget.category.toLowerCase()}${room['number']}';
                            final newRoomDoc = FirebaseFirestore.instance
                                .collection('rooms')
                                .doc(deterministicId);
                            await newRoomDoc.set({
                              'category': widget.category.toLowerCase(),
                              'number': room['number'],
                              'participantsCount': 0,
                              'capacity': RoomListScreen.roomCapacity,
                              'title': roomName,
                            }, SetOptions(merge: true));
                            roomId = deterministicId;
                          }

                          final user = FirebaseAuth.instance.currentUser;
                          if (user == null) {
                            Navigator.of(context).pushReplacementNamed('/login');
                            return;
                          }

                          // PATCH: Leave old room presence before joining new one
                          await _leaveCurrentRoomIfAny(roomId, user.uid);

                          await ChatService.joinRoom(roomId);

                          // Fetch local session ID from SharedPreferences
                          final prefs = await SharedPreferences.getInstance();
                          final sessionId = prefs.getString('sessionId') ?? '';

                          final userInfo = await UserService.fetchDisplayInfo(user.uid);

                          if (userInfo.username == 'Unknown' ||
                              userInfo.avatarUrl.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Missing profile info. Please complete your profile.',
                                ),
                              ),
                            );
                            return;
                          }

                          await PresenceService.setupRoomPresence(
                            userId: user.uid,
                            roomId: roomId,
                            userName: userInfo.username,
                            avatarUrl: userInfo.avatarUrl,
                            userAvatarBorderUrl: userInfo.currentBorderUrl,
                            tier: userInfo.tier,
                          );

                          // Save new current room ID locally
                          await _setCurrentRoomId(roomId);

                          Navigator.pushNamed(
                            context,
                            '/chat',
                            arguments: {
                              'roomId': roomId,
                              'displayName': roomName,
                              'userName': userInfo.username,
                              'userImageUrl': userInfo.avatarUrl,
                              'currentUserId': user.uid,
                              'currentUserTier': userInfo.tier,
                            },
                          );
                        } catch (e, st) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        } finally {
                          if (mounted) setState(() => _isLoading = false);
                        }
                      },
                    )
                        : const Text("Full",
                        style: TextStyle(color: Colors.red)),
                  );
                },
              );
            },
          ),
        ),
        if (_isLoading) const ElyticLoader(text: "Joining room..."),
      ],
    );
  }
}
