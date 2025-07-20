// lib/frontend/screens/profile/change_email_page.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // ← added

class ChangeEmailPage extends StatefulWidget {
  const ChangeEmailPage({Key? key}) : super(key: key);

  @override
  State<ChangeEmailPage> createState() => _ChangeEmailPageState();
}

class _ChangeEmailPageState extends State<ChangeEmailPage> {
  final _formKey = GlobalKey<FormState>();

  final _currentEmailController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newEmailController = TextEditingController();
  final _confirmNewEmailController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _currentEmailController.dispose();
    _currentPasswordController.dispose();
    _newEmailController.dispose();
    _confirmNewEmailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _errorMessage = "No signed-in user.";
        _isLoading = false;
      });
      return;
    }

    final currentEmailInput = _currentEmailController.text.trim();
    final actualEmail = user.email ?? '';

    if (currentEmailInput != actualEmail) {
      setState(() {
        _errorMessage = "Current email does not match your account email.";
        _isLoading = false;
      });
      return;
    }

    final currentPassword = _currentPasswordController.text.trim();
    if (currentPassword.isEmpty) {
      setState(() {
        _errorMessage = "Please enter your current password to confirm.";
        _isLoading = false;
      });
      return;
    }

    try {
      final credential = EmailAuthProvider.credential(
        email: actualEmail,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      String message = "Re-authentication failed.";
      if (e.code == 'wrong-password') {
        message = "Current password is incorrect.";
      } else if (e.code == 'user-mismatch') {
        message = "User mismatch during reauthentication.";
      } else if (e.code == 'user-not-found') {
        message = "User not found.";
      }
      setState(() {
        _errorMessage = "$message (${e.code})";
        _isLoading = false;
      });
      return;
    } catch (e) {
      setState(() {
        _errorMessage = "Re-authentication error: ${e.toString()}";
        _isLoading = false;
      });
      return;
    }

    try {
      final newEmail = _newEmailController.text.trim();
      await user.verifyBeforeUpdateEmail(newEmail);

      // ← NEW: write the new email into Firestore so your sync-functions fire
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'email': newEmail});

      setState(() {
        _successMessage = "We have sent you an email verification link at your provided email. Please check it and click on the link to complete the process!";
        _isLoading = false;
      });
    } on FirebaseAuthException catch (e) {
      String message = "Failed to update email.";
      if (e.code == 'email-already-in-use') {
        message = "The new email address is already in use.";
      } else if (e.code == 'invalid-email') {
        message = "The new email address is invalid.";
      } else if (e.code == 'requires-recent-login') {
        message = "Please re-login and try again.";
      }
      setState(() {
        _errorMessage = "$message (${e.code})";
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Failed to update email: ${e.toString()}";
        _isLoading = false;
      });
    }
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return "Email cannot be empty";
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailRegex.hasMatch(value.trim())) return "Enter a valid email";
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change Email')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // User types current email
              TextFormField(
                controller: _currentEmailController,
                decoration: const InputDecoration(labelText: 'Current Email'),
                validator: _validateEmail,
                autofillHints: const [AutofillHints.email],
              ),
              const SizedBox(height: 20),
              // Current password input for re-authentication
              TextFormField(
                controller: _currentPasswordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Current Password'),
                validator: (val) =>
                val == null || val.trim().isEmpty ? "Enter your current password" : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _newEmailController,
                decoration: const InputDecoration(labelText: 'New Email'),
                validator: _validateEmail,
                autofillHints: const [AutofillHints.newUsername],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmNewEmailController,
                decoration: const InputDecoration(labelText: 'Confirm New Email'),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return "Please confirm your new email";
                  if (val.trim() != _newEmailController.text.trim()) return "Emails do not match";
                  return null;
                },
                autofillHints: const [AutofillHints.newUsername],
              ),
              const SizedBox(height: 24),
              if (_errorMessage != null)
                Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              if (_successMessage != null)
                Text(_successMessage!, style: const TextStyle(color: Colors.green)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
                    : const Text('Change Email'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
