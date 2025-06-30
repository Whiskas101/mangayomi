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
  // for compensating for any warping or transformations
  // applied to the image being rendered, so the text boxes
  // must be aligned exactly as they were to the image if it was
  // raw and untransformed

  final Size renderedSize;
  final Size originalSize;

  final List<WordBox> wordBoxes;

  List<WordBox> transformWordBoxes(List<WordBox> wordBoxes) {
    final List<WordBox> transformedBoxes = [];

    // If there's no transformation, just return original
    if (renderedSize == originalSize) {
      return wordBoxes;
    }

    // Use uniform scaling to preserve aspect ratio
    final double scale =
        (renderedSize.width / originalSize.width)
                    .clamp(0.0, double.infinity)
                    .compareTo(renderedSize.height / originalSize.height) <
                0
            ? renderedSize.width / originalSize.width
            : renderedSize.height / originalSize.height;

    final double imageDisplayWidth = originalSize.width * scale;
    final double imageDisplayHeight = originalSize.height * scale;

    final double offsetX = (renderedSize.width - imageDisplayWidth) / 2;
    final double offsetY = (renderedSize.height - imageDisplayHeight) / 2;

    // print(
    //   "Scale: $scale, offsetX: $offsetX, offsetY: $offsetY, "
    //   "originalSize: $originalSize, renderedSize: $renderedSize",
    // );

    for (final box in wordBoxes) {
      final Rect b = box.boundingBox;

      final Rect transformedRect = Rect.fromLTWH(
        offsetX + b.left * scale,
        offsetY + b.top * scale,
        b.width * scale,
        b.height * scale,
      );

      transformedBoxes.add(
        WordBox(word: box.word, boundingBox: transformedRect),
      );
    }

    return transformedBoxes;
  }

  final void Function(String word)? onWordTap;

  const WordBoxOverlay({
    super.key,
    required this.wordBoxes,
    required this.renderedSize,
    required this.originalSize,
    this.onWordTap,
  });

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
    return GestureDetector(
      onDoubleTapDown: (details) {
        // print(" this shit tapped");

        final tapped = findTappedWordBox(
          widget.transformWordBoxes(widget.wordBoxes),
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
        painter: WordBoxPainter(
          widget.transformWordBoxes(widget.wordBoxes),
          selectedBox,
        ),
        size: Size.infinite,
      ),
    );
  }
}
