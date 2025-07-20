// lib/frontend/widgets/shop/buy_gift_button.dart

import 'package:flutter/material.dart';
import 'package:elytic/frontend/utils/rarity_color.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BuyGiftButton extends StatefulWidget {
  final Map<String, dynamic> petData;

  const BuyGiftButton({Key? key, required this.petData}) : super(key: key);

  @override
  State<BuyGiftButton> createState() => _BuyGiftButtonState();
}

class _BuyGiftButtonState extends State<BuyGiftButton> {
  bool _owned = false;
  bool _loading = true;
  int? _coinPrice;
  double? _realMoneyPrice;

  @override
  void initState() {
    super.initState();
    _checkOwned();
    _fetchShopPrice();
  }

  Future<void> _checkOwned() async {
    final petId = (widget.petData['id'] ?? widget.petData['petId'] ?? widget.petData['item_id'] ?? "").toString();
    if (petId.isEmpty) {
      setState(() { _owned = false; _loading = false; });
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() { _owned = false; _loading = false; });
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('pets')
          .doc(petId)
          .get();

      setState(() {
        _owned = doc.exists;
        _loading = false;
      });
    } catch (_) {
      setState(() { _owned = false; _loading = false; });
    }
  }

  Future<void> _fetchShopPrice() async {
    final petId = (widget.petData['id'] ?? widget.petData['petId'] ?? widget.petData['item_id'] ?? "").toString();
    if (petId.isEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('shopItems').doc(petId).get();
      final data = doc.data() ?? {};
      setState(() {
        _coinPrice = (data['coinPrice'] is int)
            ? data['coinPrice']
            : int.tryParse(data['coinPrice']?.toString() ?? '') ?? null;
        _realMoneyPrice = (data['realMoneyPrice'] is num)
            ? (data['realMoneyPrice'] as num).toDouble()
            : double.tryParse(data['realMoneyPrice']?.toString() ?? '') ?? 0.99;
      });
    } catch (_) {
      setState(() {
        _coinPrice = null;
        _realMoneyPrice = 0.99;
      });
    }
  }

  void _showBuyDialog(BuildContext context) {
    final String rarity = widget.petData['rarity'] ?? "Common";
    final Color textColor = rarityColor(rarity);
    final String name = widget.petData['name'] ?? "Unknown";
    final String coinPrice = _coinPrice?.toString() ?? widget.petData['coinPrice']?.toString() ?? "???";
    final String realMoneyPrice = (_realMoneyPrice ?? 0.99).toStringAsFixed(2);

    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: SizedBox(
          width: 320,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Buy $name",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  icon: Icon(Icons.monetization_on, color: textColor),
                  label: Text('Buy for $coinPrice Coins', style: TextStyle(color: textColor)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: BorderSide(color: textColor.withOpacity(0.2)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    foregroundColor: textColor,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Purchased $name for $coinPrice coins!')),
                    );
                  },
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  icon: Icon(Icons.credit_card, color: textColor),
                  label: Text('Buy for \$$realMoneyPrice', style: TextStyle(color: textColor)),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: BorderSide(color: textColor.withOpacity(0.2)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    foregroundColor: textColor,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Real money purchase (\$$realMoneyPrice) is coming soon!')),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showGiftDialog(BuildContext context) async {
    final String rarity = widget.petData['rarity'] ?? "Common";
    final Color textColor = rarityColor(rarity);
    final String name = widget.petData['name'] ?? "Unknown";
    final String coinPrice = _coinPrice?.toString() ?? widget.petData['coinPrice']?.toString() ?? "???";
    final String realMoneyPrice = (_realMoneyPrice ?? 0.99).toStringAsFixed(2);

    bool success = await showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: SizedBox(
          width: 320,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Gift $name",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  icon: Icon(Icons.monetization_on, color: textColor),
                  label: Text('Gift for $coinPrice Coins', style: TextStyle(color: textColor)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: BorderSide(color: textColor.withOpacity(0.2)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    foregroundColor: textColor,
                  ),
                  onPressed: () => Navigator.pop(context, true),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  icon: Icon(Icons.credit_card, color: textColor),
                  label: Text('Gift for \$$realMoneyPrice', style: TextStyle(color: textColor)),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: BorderSide(color: textColor.withOpacity(0.2)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    foregroundColor: textColor,
                  ),
                  onPressed: () => Navigator.pop(context, true),
                ),
              ],
            ),
          ),
        ),
      ),
    ) ?? false;

    if (success) {
      final selectedUser = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => _UserSearchDialog(rarity: rarity),
      );
      if (selectedUser != null && selectedUser['username'] != null) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Confirm Gift'),
            content: Text('Do you want to give $name to ${selectedUser['username']}?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Confirm'),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gifted $name to ${selectedUser['username']}!')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String rarity = widget.petData['rarity'] ?? "Common";
    final Color textColor = rarityColor(rarity);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            icon: Icon(Icons.shopping_cart_checkout, size: 16, color: textColor),
            label: Text(_owned ? 'Owned' : 'Buy', style: TextStyle(color: textColor)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              minimumSize: const Size(0, 38),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
              side: BorderSide(color: textColor.withOpacity(0.3)),
              foregroundColor: textColor,
            ),
            onPressed: _owned ? null : () => _showBuyDialog(context),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            icon: Icon(Icons.card_giftcard, size: 16, color: textColor),
            label: Text('Gift', style: TextStyle(color: textColor)),
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              minimumSize: const Size(0, 38),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              side: BorderSide(color: textColor.withOpacity(0.3)),
              foregroundColor: textColor,
            ),
            onPressed: () => _showGiftDialog(context),
          ),
        ),
      ],
    );
  }
}

// --- User Search Dialog using Firestore (friends by default, live search for anyone) --- //

class _UserSearchDialog extends StatefulWidget {
  final String rarity;
  const _UserSearchDialog({Key? key, required this.rarity}) : super(key: key);

  @override
  State<_UserSearchDialog> createState() => _UserSearchDialogState();
}

class _UserSearchDialogState extends State<_UserSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _loading = false;
  bool _searched = false;
  String _searchTerm = '';

  String get _currentUserId => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _loadFriends();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final term = _searchController.text.trim();
    if (term.isEmpty) {
      _loadFriends();
    } else {
      _runUserSearch(term);
    }
  }

  Future<void> _loadFriends() async {
    setState(() {
      _loading = true;
      _searched = false;
      _searchTerm = '';
    });

    final friendsSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUserId)
        .collection('friends')
        .where('status', isEqualTo: 'accepted')
        .get();

    final friendIds = friendsSnap.docs.map((doc) => doc.id).toList();
    if (friendIds.isEmpty) {
      setState(() {
        _searchResults = [];
        _loading = false;
        _searched = false;
      });
      return;
    }
    final usersSnap = await FirebaseFirestore.instance
        .collection('users')
        .where(FieldPath.documentId, whereIn: friendIds)
        .get();

    setState(() {
      _searchResults = usersSnap.docs
          .map((doc) => {...doc.data(), 'id': doc.id})
          .where((user) => user['id'] != _currentUserId)
          .toList();
      _loading = false;
      _searched = false;
    });
  }

  Future<void> _runUserSearch(String term) async {
    setState(() {
      _loading = true;
      _searched = true;
      _searchTerm = term.trim();
    });

    final q = term.trim().toLowerCase();
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .orderBy('username_lowercase')
        .startAt([q])
        .endAt([q + '\uf8ff'])
        .limit(20)
        .get();

    setState(() {
      _searchResults = snap.docs
          .map((doc) => {...doc.data(), 'id': doc.id})
          .where((user) => user['id'] != _currentUserId)
          .toList();
      _loading = false;
      _searched = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final Color textColor = rarityColor(widget.rarity);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: SizedBox(
        width: 340,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Select recipient', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
              const SizedBox(height: 10),
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search username...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else
                SizedBox(
                  height: 180,
                  child: _searchResults.isEmpty
                      ? Center(
                    child: Text(
                      _searched && _searchTerm.isNotEmpty
                          ? "No users found."
                          : "No friends found.",
                      style: const TextStyle(color: Colors.grey),
                    ),
                  )
                      : ListView.builder(
                    itemCount: _searchResults.length,
                    itemBuilder: (ctx, i) {
                      final user = _searchResults[i];
                      return ListTile(
                        leading: user['avatarPath'] != null
                            ? CircleAvatar(
                          backgroundImage: AssetImage(user['avatarPath']),
                        )
                            : const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(user['username'] ?? user['email'] ?? 'Unknown'),
                        onTap: () => Navigator.pop(context, user),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
