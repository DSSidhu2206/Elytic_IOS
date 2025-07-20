// lib/widgets/chat_bubbles/comic_chat_bubble.dart

import 'package:flutter/material.dart';

class ComicChatBubble extends StatelessWidget {
  final String text;
  final String backgroundImageAsset;
  final Color wordBackgroundColor;
  final Color borderColor;
  final TextStyle? textStyle;
  final double horizontalPadding;
  final double verticalPadding;
  final EdgeInsets outerPadding;
  final double skewAngle;
  final double wordVerticalOverflow; // how much the parallelograms poke out

  const ComicChatBubble({
    Key? key,
    required this.text,
    this.backgroundImageAsset = 'assets/chat_bubble_assets/comic_bubble_bg.png',
    this.wordBackgroundColor = const Color(0xFFFFEB3B),
    this.borderColor = Colors.black,
    this.textStyle,
    this.horizontalPadding = 24,
    this.verticalPadding = 12,
    this.outerPadding = const EdgeInsets.all(10),
    this.skewAngle = -0.32,
    this.wordVerticalOverflow = 6, // adjust as needed
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final words = text.split(' ').where((w) => w.trim().isNotEmpty).toList();

    final defaultTextStyle = textStyle ??
        TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 18,
          color: borderColor,
          letterSpacing: 0.3,
          fontFamily: "Arial",
          shadows: const [
            Shadow(
              offset: Offset(1, 2),
              blurRadius: 2,
              color: Colors.black38,
            )
          ],
        );

    return Padding(
      padding: outerPadding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // --- Dynamically layout to figure out rows ---
          // Simulate a Wrap layout to assign row indices to each word
          List<List<int>> rows = [];
          double maxWidth = constraints.maxWidth - horizontalPadding * 2;
          double spacing = -3;
          List<int> currentRow = [];
          double rowWidth = 0;

          for (int i = 0; i < words.length; i++) {
            final textSpan = TextSpan(text: words[i], style: defaultTextStyle);
            final tp = TextPainter(
              text: textSpan,
              textDirection: TextDirection.ltr,
            )..layout();
            final wordWidth = tp.width + 16; // Approximates container paddings

            double effectiveWidth = wordWidth;
            if (currentRow.isNotEmpty) effectiveWidth += spacing;

            if (rowWidth + effectiveWidth > maxWidth && currentRow.isNotEmpty) {
              rows.add(currentRow);
              currentRow = [i];
              rowWidth = wordWidth;
            } else {
              currentRow.add(i);
              rowWidth += effectiveWidth;
            }
          }
          if (currentRow.isNotEmpty) rows.add(currentRow);

          // Now, for each word, know which row it is in:
          Map<int, int> wordRowMap = {};
          for (int row = 0; row < rows.length; row++) {
            for (final idx in rows[row]) {
              wordRowMap[idx] = row;
            }
          }

          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // The dotted background
              Positioned(
                top: wordVerticalOverflow,
                bottom: wordVerticalOverflow,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: verticalPadding,
                  ),
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage(backgroundImageAsset),
                      fit: BoxFit.cover,
                    ),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: borderColor, width: 5),
                  ),
                ),
              ),
              // The parallelogram words (with vertical overflow)
              Padding(
                // Prevent horizontal overflow from padding
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: -3,
                  runSpacing: -wordVerticalOverflow * 2.4, // <-- Key change
                  children: List.generate(words.length, (i) {
                    int row = wordRowMap[i]!;
                    double yOffset = 0;
                    if (row == 0) {
                      yOffset = -wordVerticalOverflow; // Top row
                    } else if (row == rows.length - 1) {
                      yOffset = wordVerticalOverflow; // Bottom row
                    }
                    return Transform.translate(
                      offset: Offset(0, yOffset),
                      child: _ParallelogramWord(
                        text: words[i],
                        backgroundColor: wordBackgroundColor,
                        borderColor: borderColor,
                        textStyle: defaultTextStyle,
                        skewAngle: skewAngle,
                      ),
                    );
                  }),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ParallelogramWord extends StatelessWidget {
  final String text;
  final Color backgroundColor;
  final Color borderColor;
  final TextStyle textStyle;
  final double skewAngle;

  const _ParallelogramWord({
    Key? key,
    required this.text,
    required this.backgroundColor,
    required this.borderColor,
    required this.textStyle,
    required this.skewAngle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final containerSkewMatrix = Matrix4.identity()..setEntry(0, 1, skewAngle);
    final textSkewMatrix = Matrix4.identity()..setEntry(0, 1, -skewAngle);

    return Transform(
      transform: containerSkewMatrix,
      origin: const Offset(10, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border.all(color: borderColor, width: 4),
          borderRadius: BorderRadius.circular(7),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.17),
              offset: const Offset(2, 3),
              blurRadius: 3,
            ),
          ],
        ),
        child: Transform(
          transform: textSkewMatrix,
          child: Text(
            text,
            style: textStyle,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
