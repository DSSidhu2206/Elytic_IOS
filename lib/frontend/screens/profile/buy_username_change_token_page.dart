// lib/frontend/screens/profile/buy_username_change_token_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../backend/services/user_service.dart';  // Import UserService

class BuyUsernameChangeTokenPage extends StatefulWidget {
  const BuyUsernameChangeTokenPage({Key? key}) : super(key: key);

  @override
  State<BuyUsernameChangeTokenPage> createState() => _BuyUsernameChangeTokenPageState();
}

class _BuyUsernameChangeTokenPageState extends State<BuyUsernameChangeTokenPage> {
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  int _coins = 0;
  int _tokensOwned = 0;
  int _tokensBought = 0;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final HttpsCallable _purchaseTokenCallable =
  FirebaseFunctions.instance.httpsCallable('purchaseUsernameChangeToken');

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Use UserService methods for data fetching
      final userId = user.uid;
      final coins = await UserService.fetchUserCoins(userId);
      final tokensOwned = await UserService.fetchUsernameChangeTokensOwned(userId);
      final tokensBought = await UserService.fetchUsernameChangeTokensBought(userId);

      if (!mounted) return;
      setState(() {
        _coins = coins;
        _tokensOwned = tokensOwned;
        _tokensBought = tokensBought;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Failed to load user data.";
      });
    }
  }

  int get currentTokenPrice => 100 + (50 * _tokensBought);

  Future<void> _buyToken() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final result = await _purchaseTokenCallable.call();
      final data = result.data as Map<String, dynamic>? ?? {};

      // Optionally refresh user data from service after purchase to sync
      await _loadUserData();

      setState(() {
        _successMessage = 'Token purchased for ${data['pricePaid']} coins!';
      });
    } on FirebaseFunctionsException catch (e) {
      setState(() {
        _errorMessage = e.message ?? 'Purchase failed.';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Unexpected error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildInfoRow(String label, int value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(value.toString()),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buy Username Change Token')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildInfoRow('Your Coins', _coins),
            _buildInfoRow('Tokens Owned', _tokensOwned),
            _buildInfoRow('Tokens Bought', _tokensBought),
            const SizedBox(height: 16),
            Text('Current Token Price: $currentTokenPrice coins',
                style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 24),
            if (_errorMessage != null)
              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            if (_successMessage != null)
              Text(_successMessage!, style: const TextStyle(color: Colors.green)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _buyToken,
              child: _isLoading
                  ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
                  : const Text('Buy Token'),
            ),
          ],
        ),
      ),
    );
  }
}
