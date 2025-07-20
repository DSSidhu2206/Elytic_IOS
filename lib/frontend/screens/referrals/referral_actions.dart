import 'package:flutter/material.dart';
import '../../../backend/services/referral_service.dart';

class ReferralPageActions extends ChangeNotifier {
  final ReferralService _service = ReferralService();

  // UI State
  String? referralCode;
  String? referredBy;
  int successfulReferrals = 0;
  bool isLoading = false;
  String? error;
  String? infoMessage;

  TextEditingController referralCodeInput = TextEditingController();

  ReferralPageActions() {
    init();
  }

  Future<void> init() async {
    isLoading = true;
    notifyListeners();
    try {
      referralCode = await _service.getReferralCode();
      referredBy = await _service.getReferredBy();
      successfulReferrals = await _service.getSuccessfulReferralCount();
      error = null;
    } catch (e) {
      error = e.toString();
    }
    isLoading = false;
    notifyListeners();
  }

  Future<void> generateReferralCode() async {
    isLoading = true;
    error = null;
    infoMessage = null;
    notifyListeners();
    try {
      referralCode = await _service.generateReferralCode();
      infoMessage = "Referral code generated successfully!";
      await init(); // Refresh everything
    } catch (e) {
      error = e.toString().replaceAll('Exception:', '').trim();
    }
    isLoading = false;
    notifyListeners();
  }

  Future<void> copyReferralCode() async {
    if (referralCode == null) return;
    await _service.copyToClipboard(referralCode!);
    infoMessage = "Referral code copied to clipboard!";
    notifyListeners();
  }

  Future<void> submitReferralCode() async {
    isLoading = true;
    error = null;
    infoMessage = null;
    notifyListeners();
    final input = referralCodeInput.text.trim().toUpperCase();
    if (input.isEmpty || input.length != 8) {
      error = "Please enter a valid 8-character referral code.";
      isLoading = false;
      notifyListeners();
      return;
    }
    try {
      await _service.enterReferralCode(input);
      infoMessage = "Referral code submitted! You'll be rewarded after your first message.";
      referredBy = input;
      referralCodeInput.clear();
      await init(); // Refresh
    } catch (e) {
      error = e.toString().replaceAll('Exception:', '').trim();
    }
    isLoading = false;
    notifyListeners();
  }

  Future<void> shareInvite(String username) async {
    if (referralCode == null) {
      error = "No referral code found to share.";
      notifyListeners();
      return;
    }
    await _service.shareInviteMessage(username, referralCode!);
  }

  Future<void> refresh() async {
    await init();
  }

  @override
  void dispose() {
    referralCodeInput.dispose();
    super.dispose();
  }
}
