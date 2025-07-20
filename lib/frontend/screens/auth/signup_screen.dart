// lib/frontend/screens/auth/signup_screen.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:elytic/backend/services/auth_service.dart';
import 'package:elytic/backend/services/chat_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:elytic/backend/services/presence_service.dart';
import 'package:elytic/backend/services/user_service.dart';
import 'package:elytic/frontend/widgets/common/elytic_loader.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({Key? key}) : super(key: key);

  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  DateTime? _birthday;
  String? _selectedAvatar;
  bool _termsAccepted = false;
  String? _usernameError;
  String? _emailError;
  bool _checkingUsername = false;
  bool _checkingEmail = false;

  Timer? _debounceUsername;
  Timer? _debounceEmail;

  final DatabaseReference _rtdb = FirebaseDatabase.instance.reference();

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(_onUsernameChanged);
    _emailController.addListener(_onEmailChanged);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _debounceUsername?.cancel();
    _debounceEmail?.cancel();
    super.dispose();
  }

  void _onUsernameChanged() {
    _debounceUsername?.cancel();
    _debounceUsername = Timer(const Duration(milliseconds: 500), () async {
      final username = _usernameController.text.trim();
      if (username.isEmpty) {
        setState(() {
          _usernameError = null;
          _checkingUsername = false;
        });
        return;
      }
      setState(() => _checkingUsername = true);
      try {
        final available = await UserService.checkUsernameAvailable(username);
        setState(() {
          _usernameError = available ? null : 'Username already taken';
          _checkingUsername = false;
        });
      } catch (e) {
        setState(() {
          _usernameError = 'Error checking username';
          _checkingUsername = false;
        });
      }
    });
  }

  void _onEmailChanged() {
    _debounceEmail?.cancel();
    _debounceEmail = Timer(const Duration(milliseconds: 500), () async {
      final email = _emailController.text.trim();
      if (email.isEmpty || !email.contains('@')) {
        setState(() {
          _emailError = null;
          _checkingEmail = false;
        });
        return;
      }
      setState(() => _checkingEmail = true);
      try {
        final available = await UserService.checkEmailAvailable(email);
        setState(() {
          _emailError = available ? null : 'Email already registered';
          _checkingEmail = false;
        });
      } catch (e) {
        setState(() {
          _emailError = 'Error checking email';
          _checkingEmail = false;
        });
      }
    });
  }

  Future<void> _selectBirthday(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _birthday = picked);
  }

  Future<void> _selectAvatarDialog() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Avatar'),
        content: Wrap(
          spacing: 10,
          children: List.generate(10, (index) {
            String avatarPath = 'assets/avatars/avatar_${index + 1}.png';
            return GestureDetector(
              onTap: () => Navigator.pop(context, avatarPath),
              child: CircleAvatar(
                backgroundImage: AssetImage(avatarPath),
                radius: 30,
              ),
            );
          }),
        ),
      ),
    );
    if (selected != null) setState(() => _selectedAvatar = selected);
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate() ||
        !_termsAccepted ||
        _selectedAvatar == null ||
        _birthday == null ||
        _birthday!.isAfter(DateTime.now().subtract(const Duration(days: 365 * 16)))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all fields, select an avatar and birthday, be at least 16 years old, and accept terms.')),
      );
      return;
    }

    if (_usernameError != null || _emailError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please resolve all input errors.')),
      );
      return;
    }

    if (_checkingUsername || _checkingEmail) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait for username/email check to finish.')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ElyticLoader(text: "Signing up..."),
    );

    bool success = false;
    String? uid;
    String? usernameTrimmed = _usernameController.text.trim();
    String? usernameLower = usernameTrimmed.toLowerCase();

    try {
      UserCredential cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      uid = cred.user?.uid;

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'username': usernameTrimmed,
        'username_lowercase': usernameLower,
        'avatarPath': _selectedAvatar,
        'tier': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'email': _emailController.text.trim(),
      });

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('private')
          .doc('profile')
          .set({
        'birthday': _birthday,
      });

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('settings')
          .doc('preferences')
          .set({
        'dmPreference': 'open',
        'onlineStatusVisible': true,
      });

      await _rtdb.child('username_checks/$usernameTrimmed').set({
        'reserved': true,
        'userId': uid,
        'createdAt': ServerValue.timestamp,
      });

      final safeEmail = _emailController.text.trim().replaceAll('.', ',');
      await _rtdb.child('email_checks/$safeEmail').set({
        'reserved': true,
        'userId': uid,
        'createdAt': ServerValue.timestamp,
      });

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final userData = userDoc.data() ?? {};
      final userName = userData['username'] ?? '';
      final userImageUrl = userData['avatarPath'] ?? userData['avatarUrl'] ?? '';

      if (userName == '' || userImageUrl == '') {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User info missing. Please edit your profile.')),
        );
        return;
      }

      success = true;
    } catch (e) {
      success = false;
    }

    if (!success || uid == null) {
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registration failed')),
      );
      return;
    }

    final userDisplayInfo = await UserService.fetchDisplayInfo(uid);

    if (userDisplayInfo.username.isEmpty || userDisplayInfo.avatarUrl.isEmpty) {
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User info missing. Please edit your profile.')),
      );
      return;
    }

    String roomId = 'general1';
    int roomIndex = 1;
    while (await ChatService.isRoomFullCached(roomId)) {
      roomIndex++;
      roomId = 'general$roomIndex';
    }
    await ChatService.joinRoom(roomId);

    final prefs = await SharedPreferences.getInstance();
    String sessionId = const Uuid().v4();
    await prefs.setString('sessionId', sessionId);

    await PresenceService.setupRoomPresence(
      userId: uid,
      roomId: roomId,
      userName: userDisplayInfo.username,
      avatarUrl: userDisplayInfo.avatarUrl,
      userAvatarBorderUrl: userDisplayInfo.currentBorderUrl,
      tier: userDisplayInfo.tier,
    );

    final roomDoc = await FirebaseFirestore.instance.collection('rooms').doc(roomId).get();
    final displayName = roomDoc.data()?['displayName'] ?? roomId;

    Navigator.of(context, rootNavigator: true).pop();

    Navigator.of(context).pushReplacementNamed(
      '/chat',
      arguments: {
        'roomId': roomId,
        'displayName': displayName,
        'userName': userDisplayInfo.username,
        'userImageUrl': userDisplayInfo.avatarUrl,
        'currentUserId': uid,
        'currentUserTier': userDisplayInfo.tier,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: const Text('Sign Up')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Stack(
                children: [
                  TextFormField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      labelText: 'Username',
                      errorText: _usernameError,
                    ),
                    validator: (value) => value == null || value.isEmpty ? 'Please enter username' : null,
                  ),
                  if (_checkingUsername)
                    Positioned(
                      right: 10,
                      top: 15,
                      child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Stack(
                children: [
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      errorText: _emailError,
                    ),
                    validator: (value) => value != null && value.contains('@') ? null : 'Enter valid email',
                  ),
                  if (_checkingEmail)
                    Positioned(
                      right: 10,
                      top: 15,
                      child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                validator: (value) => value != null && value.length >= 6 ? null : 'Password must be 6+ characters',
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _confirmPasswordController,
                decoration: const InputDecoration(labelText: 'Confirm Password'),
                obscureText: true,
                validator: (value) => value != _passwordController.text ? 'Passwords do not match' : null,
              ),
              const SizedBox(height: 20),
              ListTile(
                title: Text(_birthday == null ? 'Select Birthday' : 'Birthday: ${_birthday!.toLocal()}'.split(' ')[0]),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _selectBirthday(context),
              ),
              const SizedBox(height: 10),
              ListTile(
                title: Text(_selectedAvatar == null ? 'Select Avatar' : 'Avatar Selected'),
                trailing: const Icon(Icons.person),
                onTap: _selectAvatarDialog,
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Checkbox(
                    value: _termsAccepted,
                    onChanged: (bool? value) => setState(() => _termsAccepted = value ?? false),
                  ),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        text: 'I accept the ',
                        style: DefaultTextStyle.of(context).style.copyWith(
                          color: Colors.black,
                          decoration: TextDecoration.none,
                          fontSize: 14,
                          fontWeight: FontWeight.normal,
                        ),
                        children: [
                          TextSpan(
                            text: 'Terms & Conditions',
                            style: DefaultTextStyle.of(context).style.copyWith(
                              color: Colors.black,
                              decoration: TextDecoration.none,
                              fontSize: 14,
                              fontWeight: FontWeight.normal,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () async {
                                final url = Uri.parse('https://elytic-2206.web.app/terms-and-conditions');
                                if (await canLaunchUrl(url)) {
                                  await launchUrl(url, mode: LaunchMode.externalApplication);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Could not open Terms & Conditions')),
                                  );
                                }
                              },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: (_checkingUsername || _checkingEmail) ? null : _signUp,
                child: _checkingUsername || _checkingEmail
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Text('Sign Up'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
