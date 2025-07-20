// lib/frontend/screens/settings/room_background_update_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../../../backend/services/room_service.dart'; // Import RoomService

// Real room names provided by user, IDs mapped sequentially
const List<Map<String, dynamic>> localRooms = [
  {'id': 'room1',  'name': 'General'},
  {'id': 'room2',  'name': 'Teen'},
  {'id': 'room3',  'name': 'Love & Dating'},
  {'id': 'room4',  'name': 'Pokemon'},
  {'id': 'room5',  'name': 'America'},
  {'id': 'room6',  'name': 'UK'},
  {'id': 'room7',  'name': 'Spanish'},
  {'id': 'room8',  'name': 'India'},
  {'id': 'room9',  'name': 'Anime & Manga'},
  {'id': 'room10', 'name': 'Tech & Gadgets'},
  {'id': 'room11', 'name': 'Gaming Hub'},
  {'id': 'room12', 'name': 'Music Lounge'},
  {'id': 'room13', 'name': 'Movies & TV'},
  {'id': 'room14', 'name': 'Sports Zone'},
  {'id': 'room15', 'name': 'Education & Learning'},
  {'id': 'room16', 'name': 'Furry Fandom'},
  {'id': 'room17', 'name': 'Health & Wellness'},
  {'id': 'room18', 'name': 'Travel & Adventure'},
  {'id': 'room19', 'name': 'Foodies'},
  {'id': 'room20', 'name': 'Fashion & Style'},
  {'id': 'room21', 'name': 'Art & Design'},
  {'id': 'room22', 'name': 'Photography'},
  {'id': 'room23', 'name': 'Memes & Humor'},
  {'id': 'room24', 'name': 'Science & Space'},
  {'id': 'room25', 'name': 'Finance & Crypto'},
  {'id': 'room26', 'name': 'History & Culture'},
  {'id': 'room27', 'name': 'Fitness & Yoga'},
  {'id': 'room28', 'name': 'Self Improvement'},
  {'id': 'room29', 'name': 'K-Pop'},
  {'id': 'room30', 'name': 'Movies & Netflix'},
];

class RoomBackgroundUpdatePage extends StatefulWidget {
  const RoomBackgroundUpdatePage({Key? key}) : super(key: key);

  @override
  State<RoomBackgroundUpdatePage> createState() => _RoomBackgroundUpdatePageState();
}

class _RoomBackgroundUpdatePageState extends State<RoomBackgroundUpdatePage> {
  Map<String, String?> backgrounds = {};
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadBackgrounds();
  }

  Future<void> _loadBackgrounds() async {
    setState(() => loading = true);

    await RoomService().loadAllRoomBackgrounds();
    final Map<String, String?> loadedBackgrounds = {};

    for (final room in localRooms) {
      final name = room['name'] as String;
      loadedBackgrounds[name] = RoomService().getRoomBackground(name);
    }

    setState(() {
      backgrounds = loadedBackgrounds;
      loading = false;
    });
  }

  Future<void> _updateBackground(String roomName, String downloadUrl) async {
    RoomService().clearCache();
    await RoomService().loadAllRoomBackgrounds();
    setState(() {
      backgrounds[roomName] = downloadUrl;
    });
  }

  Future<void> _removeBackground(String roomName) async {
    RoomService().clearCache();
    await RoomService().loadAllRoomBackgrounds();
    setState(() {
      backgrounds[roomName] = null;
    });
  }

  Future<void> _showRoomDialog(BuildContext context, Map<String, dynamic> room) async {
    final roomName = room['name'] as String;
    String? imageUrl = backgrounds[roomName];

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setState) {
          return AlertDialog(
            title: Text('Room: $roomName'),
            content: SizedBox(
              width: 300,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  imageUrl != null
                      ? Image.network(imageUrl!, height: 120, fit: BoxFit.cover)
                      : const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'No background uploaded.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.upload),
                    label: Text(imageUrl == null ? "Upload Background" : "Update Background"),
                    onPressed: () async {
                      final picker = ImagePicker();
                      final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
                      if (picked != null) {
                        final String path = picked.path;
                        final storageRef = FirebaseStorage.instance
                            .ref('room_backgrounds/$roomName/background.jpg');
                        await storageRef.putFile(File(path));
                        final downloadUrl = await storageRef.getDownloadURL();

                        await FirebaseFirestore.instance
                            .collection('room_backgrounds')
                            .doc(roomName)
                            .set({'imageUrl': downloadUrl});

                        setState(() {
                          imageUrl = downloadUrl;
                          backgrounds[roomName] = downloadUrl;
                        });

                        await _updateBackground(roomName, downloadUrl);

                        Navigator.of(ctx).pop();
                        _showRoomDialog(context, room);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  if (imageUrl != null)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.delete),
                      label: const Text("Remove Background"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      onPressed: () async {
                        final storageRef = FirebaseStorage.instance
                            .ref('room_backgrounds/$roomName/background.jpg');
                        await storageRef.delete();
                        await FirebaseFirestore.instance
                            .collection('room_backgrounds')
                            .doc(roomName)
                            .delete();

                        setState(() {
                          imageUrl = null;
                          backgrounds[roomName] = null;
                        });

                        await _removeBackground(roomName);

                        Navigator.of(ctx).pop();
                        _showRoomDialog(context, room);
                      },
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                child: const Text('Close'),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text("Upload/Edit Room Background"),
      ),
      body: ListView.separated(
        itemCount: localRooms.length,
        separatorBuilder: (_, __) => const Divider(),
        itemBuilder: (context, index) {
          final room = localRooms[index];
          final roomName = room['name'] as String;
          return ListTile(
            leading: const Icon(Icons.meeting_room),
            title: Text(roomName),
            subtitle: backgrounds[roomName] != null
                ? const Text("Background uploaded")
                : const Text("No background"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showRoomDialog(context, room),
          );
        },
      ),
    );
  }
}
