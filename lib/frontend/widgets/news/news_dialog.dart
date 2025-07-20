import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/news_item.dart';
import '../../models/news_service.dart';

class NewsDialog extends StatelessWidget {
  final List<NewsItem> items;
  final String currentUserId;

  const NewsDialog({Key? key, required this.items, required this.currentUserId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Calculate responsive dialog constraints
    final screenSize = MediaQuery.of(context).size;
    final dialogMaxHeight = screenSize.height * 0.8;
    final dialogMaxWidth = screenSize.width * 0.9;

    // Text styles
    final headerStyle = GoogleFonts.bricolageGrotesque(
      fontSize: 32,
      fontWeight: FontWeight.bold,
      letterSpacing: 1.2,
    );
    final subHeaderStyle = GoogleFonts.bricolageGrotesque(
      fontSize: 26,
      fontWeight: FontWeight.bold,
    );
    final titleStyle = GoogleFonts.bricolageGrotesque(
      fontWeight: FontWeight.w700,
      fontSize: 22,
    );
    final bodyStyle = GoogleFonts.bricolageGrotesque(
      fontSize: 17,
      height: 1.5,
      fontWeight: FontWeight.w400,
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: dialogMaxHeight,
          maxWidth: dialogMaxWidth,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          image: const DecorationImage(
            image: AssetImage('assets/paper_texture_with_lines.png'),
            fit: BoxFit.cover,
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Main Heading with Icon
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/newspaper_icon.png',
                  width: 46,
                  height: 46,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Text(
                    "📰",
                    style: TextStyle(fontSize: 46),
                  ),
                ),
                const SizedBox(width: 12),
                // Responsive heading text
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.center,
                    child: Text(
                      "ELYTIC NEWS",
                      style: headerStyle,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(thickness: 2),
            const SizedBox(height: 10),
            // Subheader
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                "What's New",
                style: subHeaderStyle,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 6),
            const Divider(thickness: 1),
            const SizedBox(height: 16),
            // NEWS LIST
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 28),
                itemBuilder: (_, i) {
                  final n = items[i];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        n.title,
                        style: titleStyle,
                        textAlign: TextAlign.left,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        n.content,
                        style: bodyStyle,
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 18),
            // Action Buttons
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      "Close",
                      style: GoogleFonts.bricolageGrotesque(
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () async {
                      int maxVer = items.map((n) => n.version).reduce(max);
                      await NewsService.updateLastSeen(currentUserId, maxVer);
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      "Mark as read",
                      style: GoogleFonts.bricolageGrotesque(
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
