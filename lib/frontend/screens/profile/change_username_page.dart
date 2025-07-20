// lib/frontend/screens/profile/change_username_page.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:elytic/backend/services/user_service.dart'; // Import UserService

class ChangeUsernamePage extends StatefulWidget {
  const ChangeUsernamePage({Key? key}) : super(key: key);

  @override
  State<ChangeUsernamePage> createState() => _ChangeUsernamePageState();
}

class _ChangeUsernamePageState extends State<ChangeUsernamePage> {
  final _formKey = GlobalKey<FormState>();
  final _newUsernameController = TextEditingController();
  final _confirmUsernameController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  int _availableTokens = 0;
  bool _loadingTokens = true;

  @override
  void initState() {
    super.initState();
    _fetchAvailableTokens();
  }

  Future<void> _fetchAvailableTokens() async {
    try {
      final tokens = await UserService.fetchUsernameChangeTokens();
      if (mounted) {
        setState(() {
          _availableTokens = tokens;
          _loadingTokens = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _availableTokens = 0;
          _loadingTokens = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _newUsernameController.dispose();
    _confirmUsernameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final newUsername = _newUsernameController.text.trim();
    final confirmUsername = _confirmUsernameController.text.trim();

    if (newUsername != confirmUsername) {
      setState(() {
        _errorMessage = "New username and confirmation do not match.";
        _successMessage = null;
      });
      return;
    }

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

    try {
      // Call your cloud function that handles token check and username update atomically
      final callable = FirebaseFunctions.instance.httpsCallable('changeUsernameWithToken');
      final result = await callable.call(<String, dynamic>{
        'newUsername': newUsername,
      });

      if (result.data['success'] == true) {
        setState(() {
          _successMessage = result.data['message'] ?? "Username updated successfully!";
          _isLoading = false;
        });
        // Refresh tokens count after successful change
        await _fetchAvailableTokens();
      } else {
        setState(() {
          _errorMessage = "Failed to update username.";
          _isLoading = false;
        });
      }
    } on FirebaseFunctionsException catch (e) {
      setState(() {
        _errorMessage = e.message ?? "Failed to update username: ${e.code}";
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Failed to update username: $e";
        _isLoading = false;
      });
    }
  }

  String? _validateUsername(String? value) {
    if (value == null || value.trim().isEmpty) return "Username cannot be empty";
    if (value.trim().length < 3) return "Username must be at least 3 characters";
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change Username')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_loadingTokens)
              const Center(child: CircularProgressIndicator())
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  "Available Username Change Tokens: $_availableTokens",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _newUsernameController,
                    decoration: const InputDecoration(labelText: 'New Username'),
                    validator: _validateUsername,
                    autofillHints: const [AutofillHints.username],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmUsernameController,
                    decoration: const InputDecoration(labelText: 'Confirm New Username'),
                    validator: _validateUsername,
                    autofillHints: const [AutofillHints.username],
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
                        : const Text('Change Username'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
