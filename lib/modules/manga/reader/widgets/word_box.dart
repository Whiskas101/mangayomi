import 'package:flutter/material.dart';
import 'package:mangayomi/modules/manga/archive_reader/models/models.dart';

class WordBoxPainter extends CustomPainter {
  final List<WordBox> wordBoxes;
  final WordBox? selectedBox;

  WordBoxPainter(this.wordBoxes, this.selectedBox);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint defaultPaint =
        Paint()
          ..color = Colors.blue.withOpacity(0.3)
          ..style = PaintingStyle.fill;

    final Paint selectedPaint =
        Paint()
          ..color = Colors.red.withOpacity(0.4)
          ..style = PaintingStyle.fill;

    for (final box in wordBoxes) {
      canvas.drawRect(
        box.boundingBox,
        box == selectedBox ? selectedPaint : defaultPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant WordBoxPainter oldDelegate) {
    return oldDelegate.wordBoxes != wordBoxes ||
        oldDelegate.selectedBox != selectedBox;
  }
}

class WordBoxOverlay extends StatefulWidget {
  final List<WordBox> wordBoxes;
  final void Function(String word)? onWordTap;

  const WordBoxOverlay({super.key, required this.wordBoxes, this.onWordTap});
  @override
  State<WordBoxOverlay> createState() => _WordBoxOverlayState();
}

class _WordBoxOverlayState extends State<WordBoxOverlay> {
  WordBox? selectedBox;

  WordBox? findTappedWordBox(List<WordBox> boxes, Offset tapPosition) {
    for (final box in boxes) {
      if (box.boundingBox.contains(tapPosition)) {
        return box;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    print("widget size: ${widget.imageSize}");
    return GestureDetector(
      onTapDown: (details) {
        // print(" this shit tapped");

        final tapped = findTappedWordBox(
          widget.wordBoxes,
          details.localPosition,
        );

        if (tapped != null) {
          setState(() {
            selectedBox = tapped;
          });
          widget.onWordTap?.call(tapped.word);
        }
      },
      child: CustomPaint(
        painter: WordBoxPainter(widget.wordBoxes, selectedBox),
        size: Size.infinite,
      ),
    );
  }
}
