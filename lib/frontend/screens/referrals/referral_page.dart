import 'package:flutter/material.dart';
import 'referral_actions.dart';
import 'package:provider/provider.dart'; // Use provider for ChangeNotifier (add to pubspec.yaml if not already)

class ReferralPage extends StatelessWidget {
  final String currentUsername;
  const ReferralPage({super.key, required this.currentUsername});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ReferralPageActions(),
      child: Consumer<ReferralPageActions>(
        builder: (context, actions, _) {
          // ERROR POPUP LOGIC
          if (actions.error != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(actions.error!),
                  backgroundColor: Colors.red[600],
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ),
              );
              actions.error = null; // Clear error after showing
            });
          }

          return Scaffold(
            appBar: AppBar(
              title: const Text('Referral Program', style: TextStyle(fontWeight: FontWeight.bold)),
              centerTitle: true,
              backgroundColor: Colors.white,
              elevation: 0,
            ),
            body: actions.isLoading
                ? const Center(child: CircularProgressIndicator())
                : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Top area: Code or Generate button
                    if (actions.referralCode == null)
                      ElevatedButton(
                        onPressed: actions.isLoading ? null : actions.generateReferralCode,
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          minimumSize: const Size(240, 48),
                        ),
                        child: const Text(
                          'Generate Referral Code',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                      )
                    else
                      Column(
                        children: [
                          const Text("Your Referral Code", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  actions.referralCode!,
                                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 2),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy_rounded),
                                  onPressed: actions.copyReferralCode,
                                  tooltip: "Copy Code",
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: () => actions.shareInvite(currentUsername),
                            icon: const Icon(Icons.ios_share),
                            label: const Text('Invite / Share', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              minimumSize: const Size(180, 44),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 32),

                    // Only show input if user hasn't used a referral code
                    if (actions.referredBy == null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text("Enter a referral code to get rewards after joining:",
                              style: TextStyle(fontSize: 15)),
                          const SizedBox(height: 12),
                          TextField(
                            controller: actions.referralCodeInput,
                            maxLength: 8,
                            textCapitalization: TextCapitalization.characters,
                            decoration: InputDecoration(
                              hintText: "8-letter Code",
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              counterText: "",
                              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: actions.isLoading ? null : actions.submitReferralCode,
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              minimumSize: const Size(160, 40),
                            ),
                            child: const Text("Submit Code", style: TextStyle(fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),

                    const SizedBox(height: 30),

                    // Referral stats
                    const Text(
                      "Successful Referrals",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "${actions.successfulReferrals}",
                        style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.green),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Status / Info message (only info)
                    if (actions.infoMessage != null)
                      Text(
                        actions.infoMessage!,
                        style: TextStyle(color: Colors.blue[700], fontWeight: FontWeight.w500),
                        textAlign: TextAlign.center,
                      ),
                    const SizedBox(height: 8),

                    // Refresh button
                    OutlinedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text("Refresh"),
                      onPressed: actions.isLoading ? null : actions.refresh,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(120, 36),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
