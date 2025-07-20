// lib/frontend/screens/auth/login_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elytic/backend/services/chat_service.dart';
import 'package:elytic/backend/services/presence_service.dart';
import 'package:elytic/backend/services/user_service.dart'; // PATCH: import optimized service
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  bool _showForgotPassword = false;

  // For Forgot Password UI
  final _forgotEmailController = TextEditingController();
  bool _isSendingReset = false;

  Future<String> _firstAvailableIn(String base) async {
    var idx = 1;
    while (true) {
      final id = '$base$idx';
      if (!await ChatService.isRoomFullCached(id)) return id;
      idx++;
    }
  }

  Future<void> saveSessionIdLocally(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sessionId', sessionId);
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      String identifier = _identifierController.text.trim();
      late UserCredential cred;

      if (identifier.contains('@')) {
        cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: identifier,
          password: _passwordController.text,
        );
      } else {
        final userSnap = await FirebaseFirestore.instance
            .collection('users')
            .where('username', isEqualTo: identifier)
            .limit(1)
            .get();

        if (userSnap.docs.isEmpty) {
          throw FirebaseAuthException(
              code: 'user-not-found', message: 'No user found with that username');
        }

        final email = userSnap.docs.first['email'];
        cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: _passwordController.text,
        );
      }

      final uid = cred.user!.uid;

      // --- PATCH: Generate and save unique sessionId ---
      final sessionId = const Uuid().v4();

      // Save sessionId locally first
      await saveSessionIdLocally(sessionId);

      // --- REMOVED user_sessions RTDB update ---

      // --- AUTO UPDATE FCM TOKEN ---
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null) {
        final tokensRef = FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('fcmTokens');
        await tokensRef.doc(fcmToken).set({
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // --- FETCH USER PROFILE DATA USING OPTIMIZED SERVICE ---
      final userInfo = await UserService.fetchDisplayInfo(uid);

      if (userInfo.username == 'Unknown' || userInfo.avatarUrl.isEmpty) {
        throw Exception('Missing username or avatar. Please complete your profile.');
      }

      final lastRoom = await ChatService.getLastActiveRoom(uid);

      String targetRoom;
      if (lastRoom == null) {
        targetRoom = await _firstAvailableIn('general');
      } else {
        if (await ChatService.isRoomFullCached(lastRoom)) {
          final m = RegExp(r'^([a-zA-Z]+)(\d+)\$').firstMatch(lastRoom);
          final base = m?.group(1) ?? 'general';
          targetRoom = await _firstAvailableIn(base);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Room $lastRoom is full. Redirecting to $targetRoom.'),
            ),
          );
        } else {
          targetRoom = lastRoom;
        }
      }

      Future<void> Function(String) joinRoomFn = ChatService.joinRoom;
      await joinRoomFn(targetRoom);

      // -------- PATCH: Write presence to Realtime Database (RTDB) --------
      await PresenceService.setupRoomPresence(
        userId: uid,
        roomId: targetRoom,
        userName: userInfo.username,
        avatarUrl: userInfo.avatarUrl,
        userAvatarBorderUrl: userInfo.currentBorderUrl, // PATCH: border!
        tier: userInfo.tier,
      );

      // Fetch the display name from Firestore before navigating
      final roomDoc = await FirebaseFirestore.instance.collection('rooms').doc(targetRoom).get();
      final displayName = roomDoc.data()?['displayName'] ?? targetRoom;

      // ----------- PASS ALL PARAMETERS -----------
      Navigator.of(context).pushReplacementNamed(
        '/chat',
        arguments: {
          'roomId': targetRoom,
          'displayName': displayName,
          'userName': userInfo.username,
          'userImageUrl': userInfo.avatarUrl,
          'currentUserId': uid,
          'currentUserTier': userInfo.tier,
        },
      );
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: ${e.message}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- Forgot Password UI handler ---
  Future<void> _sendPasswordResetEmail() async {
    final email = _forgotEmailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address')),
      );
      return;
    }
    setState(() => _isSendingReset = true);

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset email sent! Check your inbox.')),
      );
      setState(() => _showForgotPassword = false);
      _forgotEmailController.clear();
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send reset email: ${e.message}')),
      );
    } finally {
      if (mounted) setState(() => _isSendingReset = false);
    }
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    _forgotEmailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Login'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _showForgotPassword ? _buildForgotPassword() : _buildLoginForm(),
                  ),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _showForgotPassword = !_showForgotPassword;
                      });
                    },
                    child: Text(_showForgotPassword ? 'Back to Login' : 'Forgot Password?'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _identifierController,
            decoration: const InputDecoration(
              labelText: 'Username or Email',
              prefixIcon: Icon(Icons.person),
              border: OutlineInputBorder(),
            ),
            validator: (v) => v != null && v.isNotEmpty ? null : 'Enter your username or email',
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            decoration: const InputDecoration(
              labelText: 'Password',
              prefixIcon: Icon(Icons.lock),
              border: OutlineInputBorder(),
            ),
            obscureText: true,
            validator: (v) => v != null && v.length >= 6 ? null : 'Password too short',
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) {
              if (!_isLoading) _login();
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _login,
              child: _isLoading
                  ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
                  : const Text('Login', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForgotPassword() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Reset your password',
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _forgotEmailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email Address',
            prefixIcon: Icon(Icons.email),
            border: OutlineInputBorder(),
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) {
            if (!_isSendingReset) _sendPasswordResetEmail();
          },
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: _isSendingReset ? null : _sendPasswordResetEmail,
            child: _isSendingReset
                ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
                : const Text('Send Reset Email', style: TextStyle(fontSize: 16)),
          ),
        ),
      ],
    );
  }
}
