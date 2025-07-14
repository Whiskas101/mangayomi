import 'package:flutter/material.dart';
import 'package:mangayomi/modules/manga/archive_reader/models/models.dart';
import 'package:mangayomi/src/rust/api/tokenizer_wrapper.dart';

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

  // for the dictionary look up
  OverlayEntry? _popupEntry;

  void showPopup(
    BuildContext context,
    BoxConstraints constraints,
    position,
    Widget child,
  ) {
    // in case its already shown
    hidePopup();
    final overlay = Overlay.of(context);

    final width = constraints.maxWidth;
    final height = constraints.maxHeight;

    // adjust for the height and width of the box
    final mX = width - 300.0;
    final mY = height - 200.0;

    // clamp the possible locations
    final pos = Offset(position.dx.clamp(0, mX), position.dy.clamp(0, mY));

    _popupEntry = OverlayEntry(
      builder:
          (context) => Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTapDown: (details) {
                    hidePopup();
                    print("Hiding popup");
                  },
                ),
              ),
              Positioned(
                left: pos.dx,
                top: pos.dy,
                child: Material(
                  elevation: 4.0,
                  borderRadius: BorderRadius.circular(12),
                  child: child,
                ),
              ),
            ],
          ),
    );

    overlay.insert(_popupEntry!);
  }

  void hidePopup() {
    _popupEntry?.remove();
    _popupEntry = null;
  }

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
    return LayoutBuilder(
      builder: (context, constraints) {
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
              showPopup(
                context,
                constraints,
                details.localPosition,
                LookUpBox(sentence: tapped.word),
              );
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
      },
    );
  }
}

// The box that shows up when double tapping a OCR'rd line
class LookUpBox extends StatefulWidget {
  final String sentence;
  const LookUpBox({required this.sentence, super.key});

  @override
  State<LookUpBox> createState() => _LookUpBoxState();
}

class _LookUpBoxState extends State<LookUpBox> {
  List<ResultToken> resultTokens = [];
  Future<void> getDictionaryLookup(String sentence) async {
    final List<ResultToken> _resultTokens = await lookupSentence(
      input: sentence,
    );
    // // for (final ResultToken token in _resultTokens) {
    // //   print("Item: ${token.dictionaryForm}");
    // //   print("Found ${token.glosses.length} meanings");
    // //   for (final x in token.glosses) {
    // //     print(x);
    // //   }
    // }

    setState(() {
      resultTokens = _resultTokens;
    });
  }

  @override
  void initState() {
    super.initState();
    getDictionaryLookup(widget.sentence);
  }

  @override
  Widget build(BuildContext context) {
    if (resultTokens.isEmpty) {
      return Container();
    }
    return Container(
      height: 200.0,
      width: 300.0,
      padding: EdgeInsets.fromLTRB(0, 4.0, 0, 0),
      decoration: BoxDecoration(color: Colors.white24),

      child: ListView.builder(
        itemCount: resultTokens.length,
        itemBuilder: (context, index) {
          final ResultToken token = resultTokens[index];
          // return ListTile(
          //   title: Column(
          //     crossAxisAlignment: CrossAxisAlignment.start,
          //     children: [
          //       Text("${token.dictionaryForm}"),
          //       Text("${token.readingForm}"),
          //     ],
          //   ),
          // );

          final POSSTRINGS = token.pos.join(" ");

          return ExpansionTile(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  token.dictionaryForm,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                token.isOov
                    ? Container(width: 5, height: 5, color: Colors.red)
                    : Container(),
              ],
            ),
            subtitle: Text("${token.readingForm} | $POSSTRINGS"),
            children:
                token.glosses
                    .map((gloss) => ListTile(title: Text(gloss), dense: true))
                    .toList(),
          );
        },
      ),
    );
  }
}
