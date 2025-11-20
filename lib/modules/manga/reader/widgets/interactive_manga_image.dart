import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:photo_view/photo_view.dart';

class InteractiveMangaImage extends StatelessWidget {
  final List<WordBox> wordBoxes;
  final Function(WordBox box)? onWordTap;
  final bool isOcrEnabled;

  final ImageProvider image;
  final BoxFit? fit;
  final ExtendedImageMode mode;
  final InitGestureConfigHandler? initGestureConfigHandler;
  final LoadStateChanged? loadStateChanged;
  final DoubleTap? onDoubleTap;
  final BlendMode? colorBlendMode;
  final Color? color;
  final bool handleLoadingProgress;
  final FilterQuality filterQuality;
  bool enableLoadState;

  InteractiveMangaImage({
    super.key,
    this.wordBoxes = const [],
    this.onWordTap,
    this.isOcrEnabled = true,

    /// For adapter compatilbility with [ExtendedImage]
    required this.image,
    this.fit = BoxFit.contain,
    this.mode = ExtendedImageMode.gesture,
    this.initGestureConfigHandler,
    this.loadStateChanged,
    this.onDoubleTap,
    this.colorBlendMode,
    this.color,
    this.handleLoadingProgress = false,
    this.filterQuality = FilterQuality.medium,
    this.enableLoadState = false,
  });

  @override
  Widget build(BuildContext context) {
    return ExtendedImage(
      image: image,
      fit: fit,
      mode: mode,
      initGestureConfigHandler: initGestureConfigHandler,
      onDoubleTap: onDoubleTap,
      color: color,
      colorBlendMode: colorBlendMode,
      handleLoadingProgress: handleLoadingProgress,
      filterQuality: filterQuality,

      loadStateChanged: (ExtendedImageState state) {
        Widget? customWidget;

        if (loadStateChanged != null) {
          customWidget = loadStateChanged!(state);
        }

        // if (customWidget != null) {
        //   return customWidget;
        // }

        if (state.extendedImageLoadState == LoadState.completed &&
            isOcrEnabled) {
          return _buildImageWithOverlay(state);
        }

        return customWidget;
      },
    );
  }

  Rect _getDestinationRect({
    required Rect rect,
    required Size inputSize,
    required BoxFit fit,
  }) {
    final FittedSizes fittedSizes = applyBoxFit(fit, inputSize, rect.size);
    final Size destinationSize = fittedSizes.destination;
    final double dx = rect.left + (rect.width - destinationSize.width) / 2.0;
    final double dy = rect.top + (rect.height - destinationSize.height) / 2.0;
    return Rect.fromLTWH(dx, dy, destinationSize.width, destinationSize.height);
  }

  Widget _buildImageWithOverlay(ExtendedImageState state) {
    print("running _buildImageWithOverlay");
    final imageInfo = state.extendedImageInfo!;
    final imageSize = Size(
      imageInfo.image.width.toDouble(),
      imageInfo.image.height.toDouble(),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenSize = Size(constraints.maxWidth, constraints.maxHeight);

        final destinationRect = _getDestinationRect(
          rect: Offset.zero & screenSize,
          inputSize: imageSize,
          fit: fit ?? BoxFit.contain,
        );

        return Stack(
          fit: StackFit.expand,
          children: [
            ExtendedRawImage(
              image: imageInfo.image,
              scale: imageInfo.scale,
              fit: fit,
              colorBlendMode: colorBlendMode,
              filterQuality: filterQuality,
            ),

            Positioned.fromRect(
              rect: destinationRect,
              child: InteractiveMangaImageOverlay(
                wordBoxes: wordBoxes,
                onWordTap: onWordTap ?? (_) {},
              ),
            ),
          ],
        );
      },
    );
  }
}

class InteractiveMangaImageOverlay extends StatelessWidget {
  final List<WordBox> wordBoxes;

  final Function(WordBox box) onWordTap;

  const InteractiveMangaImageOverlay({
    super.key,
    required this.wordBoxes,
    required this.onWordTap,
  });

  List<WordBox> _transformBoxes(List<WordBox> wb, Size currentSize) {
    return wb.map((box) {
      final scaledRect = Rect.fromLTWH(
        box.normalizedRect.left * currentSize.width,
        box.normalizedRect.top * currentSize.height,
        box.normalizedRect.width * currentSize.width,
        box.normalizedRect.height * currentSize.height,
      );
      return WordBox(
        word: box.word,
        rawRect: scaledRect,
        normalizedRect: box.normalizedRect,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final currentSize = Size(constraints.maxWidth, constraints.maxHeight);
        final transformedBoxes = _transformBoxes(wordBoxes, currentSize);
        final transformedBoxRects = transformedBoxes
            .map((item) => item.rawRect)
            .toList();
        return SmartHitTestOverlay(
          interactiveRects: transformedBoxes.map((e) => e.rawRect).toList(),
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapUp: (details) {
              for (final box in transformedBoxes) {
                if (box.rawRect.contains(details.localPosition)) {
                  onWordTap(box);
                  break;
                }
              }
            },
            child: CustomPaint(
              size: currentSize,
              painter: WordBoxPainter(
                screenRects: transformedBoxRects,
                borderColor: Colors.red,
              ),
            ),
          ),
        );
      },
    );
  }
}

class WordBox {
  final String word;
  final Rect rawRect;
  final Rect normalizedRect;

  const WordBox({
    required this.word,
    required this.rawRect,
    required this.normalizedRect,
  });

  factory WordBox.fromPixels({
    required String word,
    required Rect rect,
    required Size originalImageSize,
  }) {
    return WordBox(
      word: word,
      rawRect: rect,
      normalizedRect: Rect.fromLTWH(
        rect.left / originalImageSize.width,
        rect.top / originalImageSize.height,
        rect.width / originalImageSize.width,
        rect.height / originalImageSize.height,
      ),
    );
  }

  factory WordBox.fromNormalized({
    required String word,
    required Rect rect,
    required Size originalImageSize,
  }) {
    return WordBox(
      word: word,
      normalizedRect: rect,
      rawRect: Rect.fromLTWH(
        rect.left * originalImageSize.width,
        rect.top * originalImageSize.height,
        rect.width * originalImageSize.width,
        rect.height * originalImageSize.height,
      ),
    );
  }

  factory WordBox.fromJson(Map<String, dynamic> json, Size originalImageSize) {
    final rect = Rect.fromLTWH(
      (json['x'] as num).toDouble(),
      (json['y'] as num).toDouble(),
      (json['w'] as num).toDouble(),
      (json['h'] as num).toDouble(),
    );

    return WordBox.fromPixels(
      word: json['word'],
      rect: rect,
      originalImageSize: originalImageSize,
    );
  }
}

class WordBoxPainter extends CustomPainter {
  final List<Rect> screenRects;
  final Color boxColor;
  final Color borderColor;

  WordBoxPainter({
    required this.screenRects,
    this.boxColor = const Color.fromRGBO(66, 145, 245, 0.3),
    this.borderColor = const Color.fromRGBO(33, 150, 243, 0.8),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint fillPaint = Paint()
      ..color = boxColor
      ..style = PaintingStyle.fill;

    final Paint borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (final rect in screenRects) {
      canvas.drawRect(rect, fillPaint);
      canvas.drawRect(rect, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant WordBoxPainter oldDelegate) {
    return oldDelegate.screenRects != screenRects;
  }
}

class SmartHitTestOverlay extends SingleChildRenderObjectWidget {
  final List<Rect> interactiveRects;
  final VoidCallback? onEmptySpaceTap;

  const SmartHitTestOverlay({
    super.key,
    required Widget child,
    required this.interactiveRects,
    this.onEmptySpaceTap,
  }) : super(child: child);

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderSmartHitTestOverlay(interactiveRects);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSmartHitTestOverlay renderObject,
  ) {
    renderObject.interactiveRects = interactiveRects;
  }
}

// Just a clean way to say "if the tap is inside a box, let the custom widget handle it",
// otherwise, propagate it down.
class _RenderSmartHitTestOverlay extends RenderProxyBox {
  List<Rect> interactiveRects;

  _RenderSmartHitTestOverlay(this.interactiveRects);

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    bool hitInsideBox = interactiveRects.any((rect) => rect.contains(position));
    if (hitInsideBox) {
      return super.hitTest(result, position: position);
    }
    return false;
  }
}
