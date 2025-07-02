import 'dart:convert';

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:mangayomi/modules/manga/archive_reader/models/models.dart';
import 'package:mangayomi/modules/manga/reader/providers/reader_controller_provider.dart';
import 'package:mangayomi/modules/manga/reader/reader_view.dart';
import 'package:mangayomi/modules/manga/reader/widgets/color_filter_widget.dart';
import 'package:mangayomi/modules/manga/reader/widgets/word_box.dart';
import 'package:mangayomi/modules/more/settings/reader/providers/reader_state_provider.dart';
import 'package:mangayomi/utils/extensions/others.dart';

import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';

class ImageViewPaged extends ConsumerStatefulWidget {
  final UChapDataPreload data;
  final Function(UChapDataPreload data) onLongPressData;
  final Widget? Function(ExtendedImageState state) loadStateChanged;
  final Function(ExtendedImageGestureState state)? onDoubleTap;
  final GestureConfig Function(ExtendedImageState state)?
  initGestureConfigHandler;

  const ImageViewPaged({
    super.key,
    required this.data,
    required this.onLongPressData,
    required this.loadStateChanged,
    this.onDoubleTap,
    this.initGestureConfigHandler,
  });

  @override
  ConsumerState<ImageViewPaged> createState() => _ImageViewPagedState();
}

class _ImageViewPagedState extends ConsumerState<ImageViewPaged> {
  final GlobalKey _imageKey = GlobalKey();
  Size? _renderedSize;
  Size? _originalImageSize;
  List<WordBox>? _wordBoxes;

  Future<Size> getImageSizeFromBytes(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    return Size(image.width.toDouble(), image.height.toDouble());
  }

  Future<List<WordBox>> fetchBoundingBoxJson() async {
    // remove the ending section of the string .png etc and replace with
    // json to fetch metadata about wordboxes
    final uri = Uri.parse(widget.data.pageUrl!.url);
    final segments = [...uri.pathSegments];
    if (segments.isEmpty) return [];

    final last = segments.removeLast();
    final dotIndex = last.lastIndexOf('.');

    final newFileName =
        '${dotIndex == -1 ? last : last.substring(0, dotIndex)}.json';

    segments.add(newFileName);
    final newUri = uri.replace(pathSegments: segments);
    // print(newUri);

    final response = await http.get(newUri);
    if (response.statusCode == 200) {
      final List<dynamic> jsonArr = jsonDecode(response.body);
      final wordBoxes = jsonArr.map((e) => WordBox.fromJson(e)).toList();
      return wordBoxes;
    }

    return [];
  }

  @override
  void initState() {
    super.initState();

    widget.data.getImageBytes.then((bytes) {
      if (bytes != null) {
        getImageSizeFromBytes(bytes).then((size) {
          if (mounted) {
            setState(() {
              _originalImageSize = size;
            });
            debugPrint("Original image size: $size");
          }
        });
      }
    });

    var bytes;
    if (widget.data.localImage != null) {
      _wordBoxes = widget.data.localImage?.wordBoxes ?? [];
      print("Local Image present!");
    } else if (widget.data.pageUrl != null) {
      if (_wordBoxes == null) {
        fetchBoundingBoxJson().then((boxes) {
          setState(() {
            _wordBoxes = boxes;
          });
        });
      }
    }

    print('data in widget::: ${widget.data}');

    // Delay to after layout is complete
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   final context = _imageKey.currentContext;
    //   if (context != null && mounted) {
    //     final renderBox = context.findRenderObject() as RenderBox?;
    //     if (renderBox != null && renderBox.hasSize) {
    //       setState(() {
    //         _renderedSize = renderBox.size;
    //       });
    //       debugPrint("Rendered image size: $_renderedSize");
    //     }
    //   }
    // });
  }

  @override
  Widget build(BuildContext context) {
    final scaleType = ref.watch(scaleTypeStateProvider);
    final image = widget.data.getImageProvider(ref, true);

    final (colorBlendMode, color) = chapterColorFIlterValues(context, ref);

    return GestureDetector(
      onLongPress: () => widget.onLongPressData.call(widget.data),
      child: Stack(
        children: [
          MeasureSize(
            onSizeChanged: (size) {
              if (_renderedSize != size) {
                setState(() {
                  _renderedSize = size;
                  print("_renderedSize: $_renderedSize");
                });
              }
            },
            child: ExtendedImage(
              key: _imageKey,
              image: image,
              colorBlendMode: colorBlendMode,
              color: color,
              fit: getBoxFit(scaleType),
              filterQuality: FilterQuality.medium,
              mode: ExtendedImageMode.gesture,
              handleLoadingProgress: true,
              loadStateChanged: widget.loadStateChanged,
              initGestureConfigHandler: widget.initGestureConfigHandler,
              onDoubleTap: widget.onDoubleTap,
            ),
          ),
          if (_wordBoxes != null &&
              _renderedSize != null &&
              _originalImageSize != null)
            Positioned(
              left: 0,
              top: 0,
              width: _renderedSize!.width,
              height: _renderedSize!.height,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapDown:
                    (details) => print("TapDown: ${details.localPosition}"),
                onTapUp: (details) => print("TapUp: ${details.localPosition}"),
                child: SizedBox.expand(
                  child: WordBoxOverlay(
                    renderedSize: _renderedSize!,
                    originalSize: _originalImageSize!,
                    wordBoxes: [..._wordBoxes!],
                    onWordTap: (word) => print("Tapped word $word"),
                  ),
                ),
              ),
            ),

          // Positioned.fill(
          //   child: DrawRectDebugOverlay(
          //     onBoxDrawn: (box) {
          //       print('Drawn: ${box.rect}');
          //     },
          //   ),
          // ),
        ],
      ),
    );
  }
}

// Abstraction to measure the size of a child widget and react to it using a callback func
typedef OnSizeChanged = void Function(Size newSize);

class MeasureSize extends SingleChildRenderObjectWidget {
  final OnSizeChanged onSizeChanged;

  const MeasureSize({
    super.key,
    required Widget super.child,
    required this.onSizeChanged,
  });

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderMeasureSize(onSizeChanged);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderMeasureSize renderObject,
  ) {
    renderObject.onSizeChanged = onSizeChanged;
  }
}

class RenderMeasureSize extends RenderProxyBox {
  RenderMeasureSize(this.onSizeChanged);

  OnSizeChanged onSizeChanged;
  Size? _oldSize;

  @override
  void performLayout() {
    super.performLayout();

    Size newSize = child?.size ?? Size.zero;
    if (_oldSize != newSize) {
      _oldSize = newSize;

      /// still using a add post frame callback, just to be safe from
      /// setState calls that may be withint he [onSizeChanged] function
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onSizeChanged(newSize);
      });
    }
  }
}

// ---debug

class DebugBox {
  final Rect rect;
  final String? label;
  final Color color;

  DebugBox({required this.rect, this.label, this.color = Colors.red});
}

class DrawRectDebugOverlay extends StatefulWidget {
  final void Function(DebugBox box)? onBoxDrawn;

  const DrawRectDebugOverlay({super.key, this.onBoxDrawn});

  @override
  State<DrawRectDebugOverlay> createState() => _DrawRectDebugOverlayState();
}

class _DrawRectDebugOverlayState extends State<DrawRectDebugOverlay> {
  Offset? start;
  Offset? current;
  final List<DebugBox> boxes = [];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (details) {
        setState(() {
          start = details.localPosition;
          current = start;
        });
      },
      onPanUpdate: (details) {
        setState(() {
          current = details.localPosition;
        });
      },
      onPanEnd: (_) {
        if (start != null && current != null) {
          final rect = Rect.fromPoints(start!, current!);
          final box = DebugBox(
            rect: rect,
            label:
                '${rect.left.toStringAsFixed(1)}, ${rect.top.toStringAsFixed(1)}\n'
                '${rect.width.toStringAsFixed(1)} × ${rect.height.toStringAsFixed(1)}',
            color: Colors.green,
          );
          setState(() {
            boxes.add(box);
            start = null;
            current = null;
          });
          widget.onBoxDrawn?.call(box);
        }
      },
      child: CustomPaint(
        painter: _DebugBoxPainter(
          boxes: boxes,
          currentDrag:
              (start != null && current != null)
                  ? Rect.fromPoints(start!, current!)
                  : null,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _DebugBoxPainter extends CustomPainter {
  final List<DebugBox> boxes;
  final Rect? currentDrag;

  _DebugBoxPainter({required this.boxes, this.currentDrag});

  @override
  void paint(Canvas canvas, Size size) {
    final textStyle = TextStyle(
      color: Colors.white,
      fontSize: 10,
      backgroundColor: Colors.black.withOpacity(0.6),
    );

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    void drawBox(DebugBox box) {
      final paint =
          Paint()
            ..color = box.color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5;

      canvas.drawRect(box.rect, paint);

      final label =
          box.label ??
          '(${box.rect.left.toStringAsFixed(1)}, ${box.rect.top.toStringAsFixed(1)})\n'
              '${box.rect.width.toStringAsFixed(1)} × ${box.rect.height.toStringAsFixed(1)}';

      textPainter.text = TextSpan(text: label, style: textStyle);
      textPainter.layout();

      canvas.drawRect(
        Rect.fromLTWH(
          box.rect.left,
          box.rect.top,
          textPainter.width,
          textPainter.height,
        ),
        Paint()..color = Colors.black.withOpacity(0.5),
      );

      textPainter.paint(canvas, Offset(box.rect.left, box.rect.top));
    }

    for (final box in boxes) {
      drawBox(box);
    }

    if (currentDrag != null) {
      final tempBox = DebugBox(rect: currentDrag!, color: Colors.orange);
      drawBox(tempBox);
    }
  }

  @override
  bool shouldRepaint(covariant _DebugBoxPainter oldDelegate) {
    return oldDelegate.boxes != boxes || oldDelegate.currentDrag != currentDrag;
  }
}
