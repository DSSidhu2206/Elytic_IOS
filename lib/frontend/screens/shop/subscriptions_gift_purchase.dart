import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:elytic/backend/services/friend_service.dart' show UserFriend;
import 'package:elytic/backend/services/search_usernames.dart' as user_search;
import 'dart:async';

class SubscriptionGiftPurchase {
  static void showGiftDialog({
    required BuildContext context,
    required Map<String, dynamic> sub,
    required Color accent,
    required List<UserFriend> friends,
    required bool friendsLoading,
    required Map<String, ProductDetails> productDetailsMap,
    required User? currentUser,
  }) {
    final TextEditingController _usernameController = TextEditingController();
    Timer? _debounce;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        String searchQuery = "";
        UserFriend? selectedFriend;
        Map<String, dynamic>? selectedUser;
        List<Map<String, dynamic>> _searchResults = [];
        bool _validTarget = false;
        bool _checkingUsername = false;
        String _usernameError = '';
        bool _isPurchasing = false;
        String? _purchaseError;

        Future<void> _searchUser(String term, void Function(void Function()) setDialogState) async {
          setDialogState(() => _checkingUsername = true);
          _usernameError = '';
          _validTarget = false;
          selectedUser = null;
          try {
            if (term.isEmpty) {
              _searchResults = [];
              setDialogState(() => _checkingUsername = false);
              return;
            }
            _searchResults = await user_search.searchUsernames(term, limit: 5);
            if (_searchResults.isEmpty) {
              _usernameError = "No user found.";
            }
          } catch (_) {
            _usernameError = "Error searching. Try again.";
          }
          setDialogState(() => _checkingUsername = false);
        }

        return StatefulBuilder(
          builder: (statefulContext, setDialogState) {
            void onSearchChanged(String value) {
              setDialogState(() {
                searchQuery = value;
                selectedFriend = null;
                _validTarget = false;
                _usernameError = '';
                selectedUser = null;
                _searchResults = [];
              });
              if (_debounce?.isActive ?? false) _debounce!.cancel();
              _debounce = Timer(const Duration(milliseconds: 500), () {
                _searchUser(value.trim(), setDialogState);
              });
            }

            List<UserFriend> filteredFriends = searchQuery.isEmpty
                ? friends
                : friends
                .where((f) =>
                f.username.toLowerCase().contains(searchQuery.toLowerCase()))
                .toList();

            Widget? selectedUserWidget;
            if (selectedUser != null &&
                selectedUser?['username'] != null &&
                selectedUser?['avatarUrl'] != null) {
              selectedUserWidget = Row(
                children: [
                  CircleAvatar(
                    backgroundImage: NetworkImage(selectedUser!['avatarUrl']),
                    radius: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    selectedUser!['username'],
                    style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  )
                ],
              );
            }

            Widget friendChip(UserFriend friend, bool isSelected) => GestureDetector(
              onTap: _isPurchasing
                  ? null
                  : () {
                setDialogState(() {
                  selectedFriend = friend;
                  _usernameController.text = friend.username;
                  searchQuery = friend.username;
                  selectedUser = {
                    'username': friend.username,
                    'id': friend.userId,
                    'avatarUrl': friend.avatarUrl,
                  };
                  _validTarget = true;
                  _usernameError = '';
                  _searchResults = [];
                });
              },
              child: Chip(
                avatar: friend.avatarUrl != null
                    ? CircleAvatar(
                  backgroundImage: NetworkImage(friend.avatarUrl!),
                  radius: 14,
                )
                    : null,
                label: Text(friend.username),
                backgroundColor: isSelected ? Colors.blue[100] : Colors.grey[200],
                shape: isSelected
                    ? const StadiumBorder(
                    side: BorderSide(color: Colors.blueAccent, width: 2))
                    : null,
              ),
            );

            return AlertDialog(
              shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Gift ${sub['name']}"),
                  if (sub.containsKey("duration"))
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        "${sub["duration"]}".toUpperCase(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: accent.withAlpha(170),
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 12),
                      if (selectedUserWidget != null) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: selectedUserWidget,
                        ),
                      ],
                      if (friendsLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: CircularProgressIndicator(),
                        ),
                      if (!friendsLoading && filteredFriends.isNotEmpty) ...[
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "Friends:",
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 48,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: filteredFriends.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (_, idx) {
                              final friend = filteredFriends[idx];
                              final isSelected =
                                  selectedFriend?.username == friend.username;
                              return friendChip(friend, isSelected);
                            },
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Autocomplete<Map<String, dynamic>>(
                        optionsBuilder:
                            (TextEditingValue textEditingValue) async {
                          if (textEditingValue.text.isEmpty) return const Iterable.empty();
                          return _searchResults;
                        },
                        displayStringForOption: (option) => option['username'] ?? "",
                        fieldViewBuilder:
                            (context, controller, focusNode, onEditingComplete) {
                          _usernameController.text = controller.text;
                          return TextField(
                            controller: controller,
                            focusNode: focusNode,
                            enabled: !_isPurchasing,
                            decoration: InputDecoration(
                              labelText: "Enter username",
                              border: const OutlineInputBorder(),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                              errorText:
                              _usernameError.isNotEmpty ? _usernameError : null,
                            ),
                            onChanged: onSearchChanged,
                            onSubmitted: (_) => onEditingComplete(),
                          );
                        },
                        onSelected: (option) {
                          setDialogState(() {
                            _usernameController.text = option['username'];
                            searchQuery = option['username'];
                            selectedUser = option;
                            _validTarget = true;
                            _usernameError = '';
                            selectedFriend = null;
                          });
                        },
                        optionsViewBuilder: (context, onSelected, options) {
                          return Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              elevation: 4.0,
                              child: SizedBox(
                                width: 300,
                                child: ListView(
                                  padding: EdgeInsets.zero,
                                  shrinkWrap: true,
                                  children: options
                                      .map((opt) => ListTile(
                                    leading: opt['avatarUrl'] != null
                                        ? CircleAvatar(
                                      backgroundImage:
                                      NetworkImage(opt['avatarUrl']),
                                      radius: 18,
                                    )
                                        : null,
                                    title: Text(opt['username'] ?? ""),
                                    onTap: () => onSelected(opt),
                                  ))
                                      .toList(),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      if (_checkingUsername) ...[
                        const SizedBox(height: 10),
                        const CircularProgressIndicator(strokeWidth: 2),
                      ],
                      if (_purchaseError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12.0),
                          child: Text(
                            _purchaseError!,
                            style: const TextStyle(
                                color: Colors.red, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _isPurchasing
                      ? null
                      : () {
                    Navigator.pop(statefulContext);
                  },
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: !_isPurchasing &&
                      productDetailsMap.containsKey(sub['id']) &&
                      _validTarget &&
                      selectedUser != null
                      ? () async {
                    setDialogState(() {
                      _isPurchasing = true;
                      _purchaseError = null;
                    });

                    final localNavigator =
                    Navigator.of(statefulContext, rootNavigator: true);
                    final localScaffold = ScaffoldMessenger.of(statefulContext);

                    final bool available =
                    await InAppPurchase.instance.isAvailable();
                    if (!available) {
                      setDialogState(() {
                        _isPurchasing = false;
                        _purchaseError = "Store unavailable.";
                      });
                      if (localNavigator.canPop()) localNavigator.pop();
                      localScaffold.showSnackBar(
                        const SnackBar(
                          content: Text(
                              "In-app purchases are not available right now."),
                        ),
                      );
                      return;
                    }

                    // ✅ Ensure user is authenticated and token is refreshed
                    User? user = FirebaseAuth.instance.currentUser ?? await FirebaseAuth.instance.authStateChanges().firstWhere((u) => u != null, orElse: () => null);
                    if (user == null) {
                      setDialogState(() {
                        _isPurchasing = false;
                        _purchaseError = "Authentication required.";
                      });
                      return;
                    }
                    await user.getIdToken(true);


                    final productDetails = productDetailsMap[sub['id']];
                    if (productDetails == null) return;

                    final PurchaseParam purchaseParam = PurchaseParam(
                      productDetails: productDetails,
                      applicationUserName:
                      "${user.uid}|gift|${selectedUser!['id']}|${selectedUser!['username']}|${sub["plan"]}",
                    );

                    await InAppPurchase.instance.buyConsumable(
                      purchaseParam: purchaseParam,
                      autoConsume: false,
                    );
                    if (localNavigator.canPop()) localNavigator.pop();
                  }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    textStyle:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  child: _isPurchasing
                      ? const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                          height: 20,
                          width: 20,
                          child:
                          CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                      SizedBox(width: 12),
                      Text("Sending Gift...")
                    ],
                  )
                      : Builder(
                    builder: (context) {
                      final productDetails = productDetailsMap[sub['id']];
                      return productDetails != null
                          ? Text("Gift (${productDetails.price})")
                          : const Text("Gift");
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
