import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:elytic/frontend/widgets/common/elytic_loader.dart';
import 'package:elytic/frontend/utils/rarity_color.dart';
import 'package:elytic/backend/services/user_service.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // <-- PATCH: Needed for Timestamp

class DailyTab extends StatefulWidget {
  const DailyTab({Key? key}) : super(key: key);

  @override
  State<DailyTab> createState() => _DailyTabState();
}

class _DailyTabState extends State<DailyTab> {
  late Future<Map<String, dynamic>> _userDailyFuture;
  bool _isClaimingBoxes = false;
  bool _isClaimingCoins = false;

  // Local flags for optimistic UI updates
  bool _hasClaimedCoinsLocally = false;
  bool _hasClaimedBoxesLocally = false;

  @override
  void initState() {
    super.initState();
    _userDailyFuture = UserService.fetchUserDailyData(forceNetwork: true);
  }

  // --- Checks if a given Firestore Timestamp is already claimed today (UTC) ---
  bool _isTodayClaimed(dynamic ts) {
    if (ts == null) return false;
    DateTime? date;

    if (ts is DateTime) {
      date = ts.toUtc();
    } else if (ts is Timestamp) { // PATCH: Support Firestore Timestamp
      date = ts.toDate().toUtc();
    } else if (ts is String) {
      date = DateTime.tryParse(ts)?.toUtc();
    } else if (ts is Map && ts.containsKey('_seconds')) {
      final int? seconds = ts['_seconds'] as int?;
      if (seconds != null) date = DateTime.fromMillisecondsSinceEpoch(seconds * 1000).toUtc();
    } else {
      return false;
    }

    if (date == null) return false;
    final now = DateTime.now().toUtc();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  Future<void> _claimCoins() async {
    setState(() => _isClaimingCoins = true);
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('claimDailyCoins');
      final result = await callable();
      final int coins = result.data['coins'] as int? ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Claimed $coins coins!')),
      );

      // Optimistic update: mark coins claimed locally
      setState(() {
        _hasClaimedCoinsLocally = true;
      });

      // Delay then refresh and reset flag
      Future.delayed(const Duration(seconds: 2), () async {
        if (!mounted) return;
        final userId = FirebaseAuth.instance.currentUser?.uid;
        if (userId == null) return;

        UserService.invalidateDailyCache(userId);
        final freshData = await UserService.fetchUserDailyData(forceNetwork: true);

        if (!mounted) return;
        setState(() {
          _userDailyFuture = Future.value(freshData);
          _hasClaimedCoinsLocally = false; // reset after refresh
        });
      });
    } on FirebaseFunctionsException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Claim coins failed.')),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Claim coins failed. Please try again.')),
      );
    } finally {
      setState(() => _isClaimingCoins = false);
    }
  }

  Future<void> _claimBoxes() async {
    setState(() => _isClaimingBoxes = true);
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('claimDailyMysteryBoxes');
      await callable();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mystery boxes claimed!')),
      );

      // Optimistic update: mark boxes claimed locally
      setState(() {
        _hasClaimedBoxesLocally = true;
      });

      // Delay then refresh and reset flag
      Future.delayed(const Duration(seconds: 2), () async {
        if (!mounted) return;
        final userId = FirebaseAuth.instance.currentUser?.uid;
        if (userId != null) {
          UserService.invalidateDailyCache(userId);
        }
        final freshData = await UserService.fetchUserDailyData(forceNetwork: true);

        if (!mounted) return;
        setState(() {
          _userDailyFuture = Future.value(freshData);
          _hasClaimedBoxesLocally = false; // reset after refresh
        });
      });
    } on FirebaseFunctionsException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Claim failed.')),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Claim failed. Please try again.')),
      );
    } finally {
      setState(() => _isClaimingBoxes = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _userDailyFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const ElyticLoader();
        }

        final data = snapshot.data!;
        final int tier = data['tier'] as int? ?? 0;
        final bool firstTimeClaim = data['lastClaimed'] == null;

        // --- Coins Claim Logic ---
        final dynamic lastCoinsClaimed =
            data['lastCoinsClaimed'] ?? (data['daily']?['lastCoinsClaimed']);
        final bool coinsClaimedToday = _isTodayClaimed(lastCoinsClaimed);
        final bool showClaimedCoins = coinsClaimedToday || _hasClaimedCoinsLocally;

        // --- Boxes Claim Logic ---
        final dynamic lastBoxClaimed = data['lastBoxClaimed'];
        final bool boxesClaimedToday = _isTodayClaimed(lastBoxClaimed);
        final bool showClaimedBoxes = boxesClaimedToday || _hasClaimedBoxesLocally;

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _DailyHeader(tier: tier),
                const SizedBox(height: 30),

                // --- Daily Coins ---
                showClaimedCoins
                    ? _AlreadyClaimedCoinsCard()
                    : _DailyCoinsDisplay(
                  tier: tier,
                  isClaiming: _isClaimingCoins,
                  onClaim: _claimCoins,
                ),
                const SizedBox(height: 20),

                // --- Mystery Boxes ---
                showClaimedBoxes
                    ? _AlreadyClaimedCard()
                    : _DailyBoxPlaceholder(
                  tier: tier,
                  isClaiming: _isClaimingBoxes,
                  onClaim: _claimBoxes,
                ),

                const SizedBox(height: 32),
                _DailyInfoCard(tier: tier),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DailyBoxPlaceholder extends StatelessWidget {
  final int tier;
  final bool isClaiming;
  final VoidCallback onClaim;

  const _DailyBoxPlaceholder({
    required this.tier,
    required this.isClaiming,
    required this.onClaim,
  });

  String get boxSummary {
    if (tier >= 3) return "2 Rare, 1 Epic, and 1 Legendary Mystery Boxes";
    if (tier == 2) return "2 Rare and 1 Epic Mystery Box";
    if (tier == 1) return "2 Rare Mystery Boxes";
    return "1 Rare Mystery Box";
  }

  Color get _tierColor {
    if (tier >= 3) return rarityColor('legendary');
    if (tier == 2) return rarityColor('epic');
    return rarityColor('rare');
  }

  @override
  Widget build(BuildContext context) {
    final buttonColor = _tierColor;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        child: Column(
          children: [
            Text(
              "Today's Mystery Boxes:",
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 18),
            Text(
              boxSummary,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: isClaiming
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor:
                      AlwaysStoppedAnimation<Color>(Colors.white)),
                )
                    : const Icon(Icons.card_giftcard_rounded, size: 22),
                label: Text(isClaiming ? "Claiming..." : "Claim Now"),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  textStyle:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  backgroundColor: buttonColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                ),
                onPressed: isClaiming ? null : onClaim,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyHeader extends StatelessWidget {
  final int tier;
  const _DailyHeader({required this.tier});

  String get _tierName {
    switch (tier) {
      case 1:
        return 'Basic';
      case 2:
        return 'Basic Plus';
      default:
        return tier >= 3 ? 'Royalty' : 'Base';
    }
  }

  Color get _tierColor {
    switch (tier) {
      case 1:
        return rarityColor('rare');
      case 2:
        return rarityColor('epic');
      default:
        return rarityColor('legendary');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Daily Rewards',
          style: Theme.of(context)
              .textTheme
              .headlineMedium
              ?.copyWith(fontWeight: FontWeight.w900, letterSpacing: 1.0),
        ),
        const SizedBox(height: 8),
        Chip(
          label: Text(
            'Your Tier: $_tierName',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: _tierColor,
          labelPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          elevation: 1,
        ),
      ],
    );
  }
}

class _DailyCoinsDisplay extends StatelessWidget {
  final int tier;
  final bool isClaiming;
  final VoidCallback onClaim;

  const _DailyCoinsDisplay({
    required this.tier,
    required this.isClaiming,
    required this.onClaim,
  });

  Color get _tierColor {
    if (tier >= 3) return rarityColor('legendary');
    if (tier == 2) return rarityColor('epic');
    return rarityColor('rare');
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        child: Row(
          children: [
            Icon(Icons.monetization_on, color: _tierColor, size: 36),
            const SizedBox(width: 16),
            const Expanded(
              child: Text(
                'Daily Coins',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            ElevatedButton(
              onPressed: isClaiming ? null : onClaim,
              style: ElevatedButton.styleFrom(
                backgroundColor: _tierColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              ),
              child: isClaiming
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
              )
                  : const Text(
                'Claim',
                style: TextStyle(
                    color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlreadyClaimedCoinsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      color: Colors.green.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 18),
        child: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.green.shade400, size: 32),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "You’ve already claimed today's coins!",
                    style: TextStyle(
                        color: Colors.green.shade800,
                        fontSize: 16,
                        fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Come back tomorrow for more coins.",
                    style: TextStyle(color: Colors.green.shade700, fontSize: 13.5),
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

class _AlreadyClaimedCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      color: Colors.green.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        child: Column(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.green.shade400, size: 46),
            const SizedBox(height: 18),
            Text(
              "You’ve already claimed today’s boxes!",
              style: TextStyle(color: Colors.green.shade800, fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              "Come back tomorrow for new rewards.",
              style: TextStyle(color: Colors.green.shade700, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyInfoCard extends StatelessWidget {
  final int tier;
  const _DailyInfoCard({required this.tier});

  String get infoText {
    switch (tier) {
      case 1:
        return "As a Basic subscriber, you receive **2 Rare Mystery Boxes** every day. Don’t forget to claim them!";
      case 2:
        return "As a Basic Plus subscriber, you receive **2 Rare and 1 Epic Mystery Box** daily. Keep your streak!";
      default:
        return tier >= 3
            ? "As a Royalty subscriber, you receive **2 Rare, 1 Epic, and 1 Legendary Mystery Boxes** daily. Enjoy exclusive rewards!"
            : "Claim your **Rare Mystery Box** every day for free. Upgrade to VIP for even better rewards!";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade300, width: 1.1),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: Colors.deepPurple, size: 28),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              infoText,
              style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
