// lib/frontend/screens/home/vip_room_tab.dart

import 'package:flutter/material.dart';
import 'package:elytic/backend/services/user_service.dart';
import 'package:elytic/backend/services/user_service.dart' show VIPRoomInfo;

class VIPRoomTab extends StatefulWidget {
  const VIPRoomTab({Key? key}) : super(key: key);

  @override
  State<VIPRoomTab> createState() => _VIPRoomTabState();
}

class _VIPRoomTabState extends State<VIPRoomTab> {
  late Future<List<VIPRoomInfo>> _vipRoomsFuture;
  int? _currentUserTier;

  @override
  void initState() {
    super.initState();
    _vipRoomsFuture = UserService.fetchVIPRooms();
    _fetchUserTier();
  }

  Future<void> _fetchUserTier() async {
    final tier = await UserService.fetchCurrentUserTier();
    if (mounted) {
      setState(() {
        _currentUserTier = tier;
      });
    }
  }

  void _showAccessDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Access Denied'),
        content: const Text('Only users with Basic Plus and Royalty can use custom VIP rooms.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber[700],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pushNamed(context, '/subscriptions');
            },
            child: const Text('Buy Now'),
          ),
        ],
      ),
    );
  }

  void _joinRoom(VIPRoomInfo room) async {
    final tier = _currentUserTier ?? 0;

    // Show error message if tier is not 2,3,4,5 or 6
    if (!(tier == 2 || tier == 3 || (tier >= 4 && tier <= 6))) {
      _showAccessDeniedDialog();
      return; // Do not proceed
    }

    if (room.inviteOnly) {
      if (tier == 2 || tier == 3) {
        // Prompt for code
        final codeController = TextEditingController();
        final result = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Enter Invite Code'),
            content: TextField(
              controller: codeController,
              decoration: const InputDecoration(
                hintText: 'Enter code here',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false), // Cancel
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  final enteredCode = codeController.text.trim();
                  if (enteredCode.isEmpty) return;
                  Navigator.of(context).pop(true); // Confirm
                },
                child: const Text('Join'),
              ),
            ],
          ),
        );

        if (result != true) {
          // User cancelled or didn't enter code
          return;
        }

        // TODO: Validate the entered code here if needed before joining

        Navigator.pushNamed(
          context,
          '/room',
          arguments: {
            'roomId': room.id,
            'roomName': room.name,
            'isVIP': true,
          },
        );
        return;
      }

      if (tier >= 4) {
        // Tier 4,5,6 - allow joining without code
        Navigator.pushNamed(
          context,
          '/room',
          arguments: {
            'roomId': room.id,
            'roomName': room.name,
            'isVIP': true,
          },
        );
        return;
      }
    } else {
      // Room not invite-only - allow join for tier >= 2 users
      Navigator.pushNamed(
        context,
        '/room',
        arguments: {
          'roomId': room.id,
          'roomName': room.name,
          'isVIP': true,
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserTier == null) {
      // Show loading indicator while fetching tier
      return const Center(child: CircularProgressIndicator(color: Colors.amber));
    }

    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/icons/vip_room_page_background.jpg',
            fit: BoxFit.cover,
          ),
        ),
        Positioned.fill(
          child: Container(
            color: Colors.black.withOpacity(0.45),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'VIP Rooms',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                          color: Colors.white,
                        ),
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Create VIP Room'),
                        onPressed: () async {
                          final tier = _currentUserTier ?? 0;
                          if (!(tier == 2 || tier == 3 || (tier >= 4 && tier <= 6))) {
                            _showAccessDeniedDialog();
                            return;
                          }

                          final result = await Navigator.pushNamed(context, '/create_vip_room');
                          if (result == true) {
                            setState(() {
                              _vipRoomsFuture = UserService.fetchVIPRooms(forceRefresh: true);
                            });
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber[800],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 3,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: FutureBuilder<List<VIPRoomInfo>>(
                    future: _vipRoomsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(color: Colors.amber),
                        );
                      }
                      if (snapshot.hasError) {
                        return const Center(
                          child: Text(
                            'Error loading VIP Rooms',
                            style: TextStyle(color: Colors.redAccent, fontSize: 16),
                          ),
                        );
                      }
                      final vipRooms = snapshot.data ?? [];
                      if (vipRooms.isEmpty) {
                        return const Center(
                          child: Text(
                            "No VIP Rooms yet.",
                            style: TextStyle(color: Colors.white70, fontSize: 18),
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: vipRooms.length,
                        itemBuilder: (context, index) {
                          final room = vipRooms[index];
                          return Card(
                            color: Colors.white.withOpacity(0.92),
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            elevation: 4,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.asset(
                                      'assets/icons/vip_room_icon.jpg',
                                      width: 44,
                                      height: 44,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        width: 44,
                                        height: 44,
                                        color: Colors.grey[200],
                                        child: const Icon(Icons.star, color: Colors.amber, size: 32),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                room.name,
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.bold, fontSize: 16),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Text(
                                              '${room.members}/80',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w600, fontSize: 14),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          room.description,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          'Created by ${room.creator}',
                                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                                        ),
                                        if (room.inviteOnly)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 4.0),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.red[100],
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: const Text(
                                                'Invite Only',
                                                style: TextStyle(
                                                  color: Colors.red,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      ElevatedButton(
                                        onPressed: () => _joinRoom(room),
                                        style: ElevatedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 8),
                                          textStyle: const TextStyle(
                                              fontSize: 13, fontWeight: FontWeight.bold),
                                          backgroundColor: Colors.amber,
                                          foregroundColor: Colors.black,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                        child: const Text("Join"),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
