// lib/frontend/screens/vip/create_vip_room_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CreateVIPRoomScreen extends StatefulWidget {
  const CreateVIPRoomScreen({Key? key}) : super(key: key);

  @override
  State<CreateVIPRoomScreen> createState() => _CreateVIPRoomScreenState();
}

class _CreateVIPRoomScreenState extends State<CreateVIPRoomScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _inviteCodeController = TextEditingController();

  bool _inviteOnly = false;
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  Future<void> _createRoom() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isCreating = true);

    final firestore = FirebaseFirestore.instance;
    final currentUser = FirebaseAuth.instance.currentUser;
    final creatorUid = currentUser?.uid;
    final creatorUsername = currentUser?.displayName?.trim().isNotEmpty == true
        ? currentUser!.displayName
        : currentUser?.email ?? 'Unknown';

    final roomName = _nameController.text.trim();
    final desc = _descController.text.trim();
    final inviteCode = _inviteOnly ? _inviteCodeController.text.trim() : null;

    final vipRoomDoc = firestore.collection('vip_rooms').doc(); // Generate ID here
    final roomId = vipRoomDoc.id;

    final vipRoomData = {
      'name': roomName,
      'description': desc,
      'icon': 'assets/icons/vip_room_icon',
      'inviteOnly': _inviteOnly,
      'inviteCode': inviteCode,
      'creatorUid': creatorUid,
      'creatorUsername': creatorUsername,
      'maxMembers': 80,
      'createdAt': FieldValue.serverTimestamp(),
    };

    final roomData = {
      'name': roomName,
      'creatorId': creatorUid,
      'members': [creatorUid],
      'createdAt': FieldValue.serverTimestamp(),
      'isVIP': true,
    };

    try {
      await firestore.runTransaction((txn) async {
        txn.set(vipRoomDoc, vipRoomData);
        txn.set(firestore.collection('rooms').doc(roomId), roomData);
      });

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to create room: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final creatorName = user?.displayName ?? user?.email ?? "Unknown";

    const goldColor = Color(0xFFFFD700);
    const whiteTextStyle = TextStyle(color: Colors.white);

    InputDecoration _inputDecoration(String label, String? helperText) {
      return InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white),
        helperText: helperText,
        helperStyle: const TextStyle(color: Colors.white70),
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white10,
        hintStyle: const TextStyle(color: Colors.white54),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Create VIP Room"),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/icons/vip_room_icon.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.6)),
          ),
          Positioned.fill(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration("Room Name", "4–50 characters"),
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        final len = (v ?? '').trim().length;
                        if (len < 4) return "Room name must be at least 4 characters.";
                        if (len > 50) return "Room name must be at most 50 characters.";
                        return null;
                      },
                      enabled: !_isCreating,
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: _descController,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration("Room Description", "10–300 characters"),
                      minLines: 2,
                      maxLines: 4,
                      textInputAction: TextInputAction.done,
                      validator: (v) {
                        final len = (v ?? '').trim().length;
                        if (len < 10) return "Description must be at least 10 characters.";
                        if (len > 300) return "Description must be at most 300 characters.";
                        return null;
                      },
                      enabled: !_isCreating,
                    ),
                    const SizedBox(height: 18),
                    Theme(
                      data: Theme.of(context).copyWith(
                        unselectedWidgetColor: Colors.white70,
                      ),
                      child: SwitchListTile(
                        value: _inviteOnly,
                        activeColor: goldColor,
                        title: const Text("Invite Only Room", style: whiteTextStyle),
                        subtitle: const Text(
                          "Only users with the invite code can join",
                          style: TextStyle(color: Colors.white70),
                        ),
                        onChanged: _isCreating
                            ? null
                            : (val) {
                          setState(() {
                            _inviteOnly = val;
                            if (!val) _inviteCodeController.clear();
                          });
                        },
                      ),
                    ),
                    if (_inviteOnly)
                      Padding(
                        padding: const EdgeInsets.only(top: 10, bottom: 16),
                        child: TextFormField(
                          controller: _inviteCodeController,
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDecoration("6-Digit Invite Code", null).copyWith(
                            hintText: "e.g. 123456",
                          ),
                          maxLength: 6,
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (!_inviteOnly) return null;
                            if (v == null || !RegExp(r'^\d{6}$').hasMatch(v)) {
                              return "Enter a valid 6-digit code";
                            }
                            return null;
                          },
                          enabled: !_isCreating,
                        ),
                      ),
                    Row(
                      children: [
                        const Icon(Icons.person, size: 20, color: Colors.white),
                        const SizedBox(width: 8),
                        Text("Creator: ",
                            style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[300])),
                        Text(creatorName,
                            style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: const [
                        Icon(Icons.group, size: 20, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          "Max Members: ",
                          style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey),
                        ),
                        Text(
                          "80",
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                        )
                      ],
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isCreating ? null : _createRoom,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: goldColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: _isCreating
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text("Create VIP Room"),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
