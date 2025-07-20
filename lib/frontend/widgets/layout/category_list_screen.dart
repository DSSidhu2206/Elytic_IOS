// lib/frontend/widgets/layout/category_list_screen.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart'; // <-- PATCH: import
import '../../screens/home/room_list_screen.dart';
import '../../../backend/services/room_service.dart';

class CategoryListScreen extends StatefulWidget {
  const CategoryListScreen({Key? key}) : super(key: key);

  static const _categories = [
    'General',
    'Teen',
    'Love & Dating',
    'Pokemon',
    'America',
    'UK',
    'Spanish',
    'India',
    'Anime & Manga',
    'Tech & Gadgets',
    'Gaming Hub',
    'Music Lounge',
    'Movies & TV',
    'Sports Zone',
    'Education & Learning',
    'Furry Fandom',
    'Health & Wellness',
    'Travel & Adventure',
    'Foodies',
    'Fashion & Style',
    'Art & Design',
    'Photography',
    'Memes & Humor',
    'Science & Space',
    'Finance & Crypto',
    'History & Culture',
    'Fitness & Yoga',
    'Self Improvement',
    'K-Pop',
    'Movies & Netflix',
  ];

  static Future<void>? _backgroundsFuture;

  @override
  State<CategoryListScreen> createState() => _CategoryListScreenState();
}

class _CategoryListScreenState extends State<CategoryListScreen> {
  @override
  void initState() {
    super.initState();
    CategoryListScreen._backgroundsFuture ??=
        RoomService().loadAllRoomBackgrounds(CategoryListScreen._categories);
  }

  @override
  Widget build(BuildContext context) {
    // Patched: Check for all backgrounds loaded, not just any
    if (RoomService().isLoadedFor(CategoryListScreen._categories)) {
      return _buildScaffold();
    }

    return Scaffold(
      body: FutureBuilder<void>(
        future: CategoryListScreen._backgroundsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return _buildScaffold();
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }

  Widget _buildScaffold() {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 1.0,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: CategoryListScreen._categories.length,
          itemBuilder: (context, index) {
            final category = CategoryListScreen._categories[index];
            final bgUrl = RoomService().getRoomBackground(category);
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RoomListScreen(category: category),
                  ),
                );
              },
              child: Card(
                clipBehavior: Clip.antiAlias,
                color: Colors.white,
                elevation: 2,
                child: Container(
                  decoration: bgUrl != null
                      ? BoxDecoration(
                    image: DecorationImage(
                      // PATCH: Use cached disk/memory provider!
                      image: CachedNetworkImageProvider(bgUrl),
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(
                        Colors.black.withOpacity(0.25),
                        BlendMode.darken,
                      ),
                    ),
                  )
                      : const BoxDecoration(
                    color: Colors.white,
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        category,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                          height: 1.2,
                          color: bgUrl != null ? Colors.white : Colors.black87,
                          shadows: bgUrl != null
                              ? [
                            Shadow(
                              offset: Offset(0, 1),
                              blurRadius: 2,
                              color: Colors.black54,
                            )
                          ]
                              : [],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
