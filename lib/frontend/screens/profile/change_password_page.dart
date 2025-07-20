// lib/frontend/screens/profile/change_password_page.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({Key? key}) : super(key: key);

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();

  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmNewPasswordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmNewPasswordController.dispose();
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

    final currentPassword = _currentPasswordController.text.trim();
    if (currentPassword.isEmpty) {
      setState(() {
        _errorMessage = "Please enter your current password for verification.";
        _isLoading = false;
      });
      return;
    }

    try {
      final cred = EmailAuthProvider.credential(
          email: user.email ?? '', password: currentPassword);
      await user.reauthenticateWithCredential(cred);
    } catch (e) {
      setState(() {
        _errorMessage = "Current password is incorrect.";
        _isLoading = false;
      });
      return;
    }

    try {
      final newPassword = _newPasswordController.text.trim();
      await user.updatePassword(newPassword);
      setState(() {
        _successMessage = "Password updated successfully.";
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Failed to update password: ${e.toString()}";
        _isLoading = false;
      });
    }
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return "Password cannot be empty";
    if (value.length < 6) return "Password must be at least 6 characters";
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change Password')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _currentPasswordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Current Password'),
                validator: _validatePassword,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _newPasswordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New Password'),
                validator: _validatePassword,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmNewPasswordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirm New Password'),
                validator: (val) {
                  if (val == null || val.isEmpty) return "Please confirm your new password";
                  if (val != _newPasswordController.text.trim()) return "Passwords do not match";
                  return null;
                },
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
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Change Password'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
