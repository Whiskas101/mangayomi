import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:extended_image/extended_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mangayomi/models/page.dart';

/// A wrapper widget for ExtendedImage using the Composition Pattern.
///
/// This provides a simplified, stable interface for consuming ExtendedImage
/// while adding custom layering functionality (the 'overlay') without
/// exposing every single parameter of the underlying ExtendedImage.
class OverlayExtendedImage extends StatefulWidget {
  // Core parameters from ExtendedImage that are essential for the Reader/Viewer
  final ImageProvider image;
  final BoxFit? fit;
  final FilterQuality filterQuality;
  final bool enableLoadState;
  final bool handleLoadingProgress;
  final LoadStateChanged? loadStateChanged;
  final PageUrl? pageUrl;

  final BlendMode? colorBlendMode;
  final Color? color;

  OverlayExtendedImage({
    super.key,
    required this.pageUrl,
    required this.image,
    this.colorBlendMode,
    this.color,
    this.fit,
    this.filterQuality =
        FilterQuality.medium, // Not sure whether to expose this fully
    this.enableLoadState = true,
    this.handleLoadingProgress = true,
    this.loadStateChanged,
  });

  @override
  State<OverlayExtendedImage> createState() => _OverlayExtendedImageState();
}

class _OverlayExtendedImageState extends State<OverlayExtendedImage> {
  List<dynamic>? _rawOcrData;
  bool _isLoadingOcr = false;

  @override
  void initState() {
    super.initState();
    _fetchOcr();
  }

  @override
  void didUpdateWidget(covariant OverlayExtendedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // only re-fetch if the URL actually changed
    if (oldWidget.pageUrl?.url != widget.pageUrl?.url) {
      _rawOcrData = null;
      _fetchOcr();
    }
  }

  Future<void> _fetchOcr() async {
    final url = ocrUrl(widget.pageUrl);
    if (url == null) return;
    if (!mounted) return;
    setState(() {
      _isLoadingOcr = true;
    });

    try {
      final response = await get(url);
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        // print("Decoded: $decoded");
        if (mounted) {
          setState(() {
            _rawOcrData = decoded['ocr_data'];
            _isLoadingOcr = false;
          });
        }
      }
    } catch (e) {
      print("Err fetching ocr: ${e}");
      if (mounted)
        setState(() {
          _isLoadingOcr = false;
        });
    }
  }

  Uri? ocrUrl(PageUrl? pageUrl) {
    if (pageUrl == null) return null;
    final Uri originalUri = Uri.parse(pageUrl.url);
    final List<String> segments = originalUri.pathSegments.toList();

    if (segments.isEmpty) {
      return null;
    }

    List<String> newSegments = segments.where((s) => s.isNotEmpty).toList();
    if (newSegments.isNotEmpty) {
      newSegments = newSegments.sublist(0, newSegments.length - 1);
    }
    newSegments.add("ocr");
    final Uri newUri = originalUri.replace(pathSegments: newSegments);
    return newUri;
  }

  @override
  Widget build(BuildContext context) {
    // print(
    //   "OverlayExtendedImage built with pageUrl: ${ocrUrl(widget.pageUrl!)}",
    // );
    final extendedImageWidget = ExtendedImage(
      image: widget.image,
      colorBlendMode: widget.colorBlendMode,
      color: widget.color,
      filterQuality: widget.filterQuality,
      fit: widget.fit,
      enableLoadState: widget.enableLoadState,
      handleLoadingProgress: widget.handleLoadingProgress,
      loadStateChanged: (state) {
        if (widget.loadStateChanged != null) {
          final customWidgetFromUser = widget.loadStateChanged!.call(state);
          if (customWidgetFromUser != null) {
            return customWidgetFromUser;
          }
        }

        if (state.extendedImageLoadState == LoadState.completed) {
          final imageInfo = state.extendedImageInfo;
          List<Word> parsedWords = [];

          if (_rawOcrData != null && imageInfo != null) {
            final Size originalSize = Size(
              imageInfo.image.width.toDouble(),
              imageInfo.image.height.toDouble(),
            );

            parsedWords = _rawOcrData!.map((e) {
              return Word.fromJson(e, originalSize);
            }).toList();
          }
          return Stack(
            fit: StackFit.passthrough,
            alignment: Alignment.center,
            children: [
              state.completedWidget,
              if (parsedWords.isNotEmpty)
                OcrOverlay(
                  words: parsedWords,
                  onWordTap: (word) {
                    print("Word: ${word} conf: ${word.confidence}");
                  },
                ),
              // Positioned.fill(child: Overlay()),
            ],
          );
        }
      },

      // Non-exposed parameters set to defaults or reasonable values.
      alignment: Alignment.center,
      repeat: ImageRepeat.noRepeat,
      matchTextDirection: false,
      gaplessPlayback: false,
      clipBehavior: Clip.antiAlias,
      mode: ExtendedImageMode
          .none, // Assuming gesture/editor modes aren't needed here
      isAntiAlias: false,
    );

    return extendedImageWidget;
  }
}

class OcrOverlay extends StatelessWidget {
  final List<Word> words;
  final Function(Word)? onWordTap;

  const OcrOverlay({super.key, required this.words, this.onWordTap});

  Rect _toPixelCoord(Rect normalizedRect, Size layerSize) {
    return Rect.fromLTRB(
      normalizedRect.left * layerSize.width,
      normalizedRect.top * layerSize.height,
      normalizedRect.right * layerSize.width,
      normalizedRect.bottom * layerSize.height,
    );
  }

  // TODO: Implement this for improving ocr text versions
  // Future<Uint8List?> _cropWordFromImage(ui.Image sourceImage, Word word) {
  //   final Size sourceImageSize = Size(
  //     sourceImage.width.toDouble(),
  //     sourceImage.height.toDouble(),
  //   );
  //   final Rect sourceRect = _toPixelCoord(word.normalizedRect, sourceImageSize);
  //
  //   final Rect paddedRect = sourceRect
  //       .inflate(10.0)
  //       .intersect(
  //         Rect.fromLTWH(0, 0, sourceImageSize.width, sourceImageSize.height),
  //       );
  // }

  void _handleTap(Offset tapPosition, Size layerSize) {
    if (onWordTap == null) return;

    for (final word in words.reversed) {
      final pixelRect = _toPixelCoord(word.normalizedRect, layerSize);

      if (pixelRect.inflate(4.0).contains(tapPosition)) {
        onWordTap!(word);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (words.isEmpty) return const SizedBox.shrink();

    // can't put positioned fills inside each other naively, learned that the painful way
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final Size size = Size(constraints.maxWidth, constraints.maxHeight);
          return Listener(
            behavior: HitTestBehavior.translucent,
            onPointerUp: (details) => _handleTap(details.localPosition, size),

            child: CustomPaint(
              size: size,
              painter: WordBoxPainter(words: words),
            ),
          );
        },
      ),
    );
  }
}

class WordBoxPainter extends CustomPainter {
  final List<Word> words;

  WordBoxPainter({required this.words});

  @override
  void paint(Canvas canvas, Size size) {
    for (final word in words) {
      Color baseColor;

      if (word.confidence >= 0.9) {
        // Very high confidence
        baseColor = Colors.green;
      } else if (word.confidence >= 0.8) {
        // "Maybe" range (80-89%)
        baseColor = Colors.blue;
      } else if (word.confidence > 0.5) {
        // Low confidence - Redder
        baseColor = Colors.orange;
      } else {
        baseColor = Colors.red;
      }

      final Paint borderPaint = Paint()
        ..color = baseColor.withOpacity(0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0; // Made slightly thicker to see color better

      // Fill: Low opacity so you can read the text underneath
      final Paint fillPaint = Paint()
        ..color = baseColor.withOpacity(0.2)
        ..style = PaintingStyle.fill;

      final rect = Rect.fromLTRB(
        word.normalizedRect.left * size.width,
        word.normalizedRect.top * size.height,
        word.normalizedRect.right * size.width,
        word.normalizedRect.bottom * size.height,
      );

      canvas.drawRect(rect, fillPaint);
      canvas.drawRect(rect, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant WordBoxPainter oldDelegate) {
    return oldDelegate.words != words;
  }
}

class Word {
  late Rect normalizedRect;
  late String text;
  late double confidence;

  @override
  String toString() {
    return text;
  }

  Word.fromJson(Map<String, dynamic> json, Size originalSize) {
    text = json['text'] ?? "";
    confidence = (json['confidence'] as num?)?.toDouble() ?? 0.0;

    List<dynamic> boxPoints = json['box'] ?? [];
    if (boxPoints.isNotEmpty &&
        originalSize.width > 0 &&
        originalSize.height > 0) {
      double minX = (boxPoints[0][0] as num).toDouble();
      double minY = (boxPoints[0][1] as num).toDouble();
      double maxX = minX;
      double maxY = minY;

      for (var point in boxPoints) {
        double x = (point[0] as num).toDouble();
        double y = (point[1] as num).toDouble();

        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }

      normalizedRect = Rect.fromLTRB(minX, minY, maxX, maxY);
      // print(normalizedRect);
    } else {
      normalizedRect = Rect.zero;
      print("ZEROED SHIT");
    }
  }
}
