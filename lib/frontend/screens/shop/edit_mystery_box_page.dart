// lib/frontend/screens/shop/edit_mystery_box_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

class EditMysteryBoxPage extends StatefulWidget {
  const EditMysteryBoxPage({Key? key}) : super(key: key);

  @override
  State<EditMysteryBoxPage> createState() => _EditMysteryBoxPageState();
}

class _EditMysteryBoxPageState extends State<EditMysteryBoxPage> {
  String? _selectedBoxId;
  Map<String, dynamic>? _boxData;

  final _formKey = GlobalKey<FormState>();
  String _name = '';
  String _description = '';
  String _selectedRarity = 'Rare';
  final Set<String> _selectedItemIds = {};
  bool _isActive = true;

  static const List<String> rarities = ['Legendary', 'Epic', 'Rare'];
  static const String mysteryBoxAsset = 'assets/mystery_box.png';

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _fetchItems() async {
    final snap = await FirebaseFirestore.instance
        .collection('item_data')
        .orderBy('rarity', descending: true)
        .get();
    return snap.docs;
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _fetchBoxes() async {
    final snap = await FirebaseFirestore.instance
        .collection('mystery_box_data')
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs;
  }

  void _loadBox(String boxId) async {
    final doc = await FirebaseFirestore.instance.collection('mystery_box_data').doc(boxId).get();
    if (!doc.exists) return;
    final data = doc.data()!;
    setState(() {
      _selectedBoxId = boxId;
      _boxData = data;
      _name = data['name'] ?? '';
      _description = data['description'] ?? '';
      _selectedRarity = data['rarity'] ?? 'Rare';
      _selectedItemIds.clear();
      if (data['items'] is List) {
        _selectedItemIds.addAll(List<String>.from(data['items']));
      }
      _isActive = data['isActive'] != false;
    });
  }

  void _saveBox() async {
    if (_selectedBoxId == null) return;
    if (!_formKey.currentState!.validate() || _selectedItemIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields and select at least 1 item.')),
      );
      return;
    }
    _formKey.currentState!.save();
    await FirebaseFirestore.instance.collection('mystery_box_data').doc(_selectedBoxId).update({
      'name': _name.trim(),
      'description': _description.trim(),
      'iconUrl': mysteryBoxAsset,
      'items': _selectedItemIds.toList(),
      'isActive': _isActive,
      'rarity': _selectedRarity,
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mystery box updated!')),
      );
    }
  }

  void _deleteBox() async {
    if (_selectedBoxId == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Mystery Box?"),
        content: const Text("This action cannot be undone. Are you sure?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      await FirebaseFirestore.instance.collection('mystery_box_data').doc(_selectedBoxId).delete();
      setState(() {
        _selectedBoxId = null;
        _boxData = null;
        _name = '';
        _description = '';
        _selectedItemIds.clear();
        _isActive = true;
        _selectedRarity = 'Rare';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mystery box deleted!')),
        );
      }
    }
  }

  Widget _buildBoxHeader() {
    if (_boxData == null) return const SizedBox.shrink();
    final id = _boxData?['mystery_box_id'] ?? _selectedBoxId ?? '';
    final name = _boxData?['name'] ?? '';
    final desc = (_boxData?['description'] as String?)?.trim() ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        color: Colors.deepPurple.shade50,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Editing Mystery Box: $id',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.deepPurple),
              ),
              if (name.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2.0),
                  child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 2.0),
                child: Text(
                  desc.isNotEmpty ? desc : 'No description.',
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Mystery Boxes')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const Text('Step 1: Select Mystery Box', style: TextStyle(fontWeight: FontWeight.bold)),
            FutureBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
              future: _fetchBoxes(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
                final boxes = snapshot.data!;
                if (boxes.isEmpty) return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('No mystery boxes created yet.')),
                );
                return DropdownButtonFormField<String>(
                  value: _selectedBoxId,
                  hint: const Text('Choose a mystery box to edit'),
                  items: boxes.map((doc) {
                    final d = doc.data();
                    final id = d['mystery_box_id'] ?? doc.id;
                    return DropdownMenuItem<String>(
                      value: doc.id,
                      child: Text('$id - ${d['name'] ?? doc.id}'),
                    );
                  }).toList(),
                  onChanged: (boxId) {
                    _loadBox(boxId!);
                  },
                );
              },
            ),
            const SizedBox(height: 24),

            // Header for selected box info
            if (_selectedBoxId != null && _boxData != null)
              _buildBoxHeader(),

            if (_selectedBoxId != null && _boxData != null)
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Mystery Box Icon', style: TextStyle(fontWeight: FontWeight.bold)),
                    Center(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.amber, width: 3),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 20, top: 8),
                        child: Image.asset(mysteryBoxAsset, height: 85, width: 85),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Rarity Dropdown
                    const Text('Mystery Box Rarity', style: TextStyle(fontWeight: FontWeight.bold)),
                    DropdownButtonFormField<String>(
                      value: _selectedRarity,
                      items: rarities.map((rarity) {
                        return DropdownMenuItem<String>(
                          value: rarity,
                          child: Text(rarity),
                        );
                      }).toList(),
                      onChanged: (v) {
                        setState(() {
                          _selectedRarity = v ?? 'Rare';
                        });
                      },
                      decoration: const InputDecoration(labelText: 'Select Rarity'),
                    ),
                    const SizedBox(height: 8),

                    const Text('Name & Description', style: TextStyle(fontWeight: FontWeight.bold)),
                    TextFormField(
                      initialValue: _name,
                      decoration: const InputDecoration(labelText: 'Mystery Box Name'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
                      onSaved: (v) => _name = v ?? '',
                    ),
                    TextFormField(
                      initialValue: _description,
                      decoration: const InputDecoration(labelText: 'Description'),
                      onSaved: (v) => _description = v ?? '',
                      maxLines: 2,
                    ),
                    const SizedBox(height: 18),

                    const Text('Items in Box', style: TextStyle(fontWeight: FontWeight.bold)),
                    FutureBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
                      future: _fetchItems(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Center(child: CircularProgressIndicator()),
                        );
                        final items = snapshot.data!;
                        return Column(
                          children: items.map((doc) {
                            final data = doc.data();
                            final name = data['name'] ?? doc.id;
                            final iconUrl = data['iconUrl'] ?? '';
                            final rarity = data['rarity'] ?? '';
                            Widget iconWidget;
                            if (iconUrl.isNotEmpty) {
                              if (iconUrl.toString().startsWith('http')) {
                                iconWidget = CachedNetworkImage(
                                  imageUrl: iconUrl,
                                  height: 32,
                                  width: 32,
                                  fit: BoxFit.cover,
                                  errorWidget: (c, e, s) => const Icon(Icons.broken_image, size: 32),
                                  placeholder: (c, s) => const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                                );
                              } else {
                                iconWidget = Image.asset(iconUrl, height: 32, width: 32, fit: BoxFit.cover);
                              }
                            } else {
                              iconWidget = const Icon(Icons.widgets, size: 32);
                            }
                            return CheckboxListTile(
                              value: _selectedItemIds.contains(doc.id),
                              onChanged: (checked) {
                                setState(() {
                                  if (checked == true) {
                                    _selectedItemIds.add(doc.id);
                                  } else {
                                    _selectedItemIds.remove(doc.id);
                                  }
                                });
                              },
                              title: Row(
                                children: [
                                  iconWidget,
                                  const SizedBox(width: 8),
                                  Text(name),
                                  const SizedBox(width: 8),
                                  if (rarity.isNotEmpty)
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.blueGrey.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      child: Text(rarity, style: const TextStyle(fontSize: 10)),
                                    ),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                    const SizedBox(height: 18),

                    SwitchListTile(
                      value: _isActive,
                      onChanged: (val) {
                        setState(() {
                          _isActive = val;
                        });
                      },
                      title: const Text('Show this box in Shop'),
                    ),

                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _saveBox,
                            child: const Text('Save Changes'),
                          ),
                        ),
                        const SizedBox(width: 24),
                        OutlinedButton(
                          onPressed: _deleteBox,
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                          child: const Text('Delete'),
                        ),
                      ],
                    )
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
