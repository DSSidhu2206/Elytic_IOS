import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../backend/services/chat_service.dart';

class StickerInventoryTab extends StatefulWidget {
  const StickerInventoryTab({Key? key}) : super(key: key);

  @override
  State<StickerInventoryTab> createState() => _StickerInventoryTabState();
}

class _StickerInventoryTabState extends State<StickerInventoryTab> {
  late final Future<List<Map<String, dynamic>>> _stickerPacksFuture;

  @override
  void initState() {
    super.initState();
    // Only called once, uses prefs if already set
    _stickerPacksFuture = ChatService.getStickerPackMetadata();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _stickerPacksFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final packs = snapshot.data ?? [];
        if (packs.isEmpty) {
          return const Center(child: Text('No sticker packs available.'));
        }

        return Padding(
          padding: const EdgeInsets.all(12),
          child: GridView.builder(
            itemCount: packs.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            itemBuilder: (context, index) {
              final data = packs[index];
              final name = data['name'] ?? 'Unknown';
              final desc = data['description'] ?? '';
              final coverUrl = data['coverUrl'] ?? '';

              return GestureDetector(
                onTap: () => _showPackDetails(context, name, desc, coverUrl),
                child: Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 3,
                  child: Column(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12)),
                          child: coverUrl.isNotEmpty
                              ? CachedNetworkImage(
                            imageUrl: coverUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            placeholder: (c, u) =>
                            const Center(child: CircularProgressIndicator()),
                            errorWidget: (c, u, e) =>
                            const Center(child: Icon(Icons.image_not_supported)),
                          )
                              : const Center(
                              child: Icon(Icons.image,
                                  size: 60, color: Colors.grey)),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 6, horizontal: 8),
                        child: Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _showPackDetails(
      BuildContext context, String name, String description, String coverUrl) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape:
      const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => Padding(
        padding: MediaQuery.of(context).viewInsets,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: coverUrl.isNotEmpty
                    ? CachedNetworkImage(
                  imageUrl: coverUrl,
                  width: MediaQuery.of(context).size.width * 0.9,
                  fit: BoxFit.contain,
                  placeholder: (c, u) => const Center(child: CircularProgressIndicator()),
                  errorWidget: (c, u, e) =>
                  const Icon(Icons.image_not_supported, size: 100),
                )
                    : const Icon(Icons.image, size: 100, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              Text(name,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: SingleChildScrollView(
                  child: Text(description,
                      textAlign: TextAlign.center, style: const TextStyle(fontSize: 14)),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))
            ]),
          ),
        ),
      ),
    );
  }
}
