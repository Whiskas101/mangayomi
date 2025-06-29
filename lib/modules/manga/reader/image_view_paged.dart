import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mangayomi/modules/manga/archive_reader/models/models.dart';
import 'package:mangayomi/modules/manga/reader/providers/reader_controller_provider.dart';
import 'package:mangayomi/modules/manga/reader/reader_view.dart';
import 'package:mangayomi/modules/manga/reader/widgets/color_filter_widget.dart';
import 'package:mangayomi/modules/manga/reader/widgets/word_box.dart';
import 'package:mangayomi/modules/more/settings/reader/providers/reader_state_provider.dart';
import 'package:mangayomi/utils/extensions/others.dart';
import 'package:win32/win32.dart';

class ImageViewPaged extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final GlobalKey _imageKey = GlobalKey();
    Size _imageSize = Size.zero;

    final scaleType = ref.watch(scaleTypeStateProvider);
    final image = data.getImageProvider(ref, true);

    List<WordBox>? wordBoxes = data.localImage?.wordBoxes;

    final value = getBoxFit(scaleType);
    print("\n||${scaleType.toString()} \n\n${value.toString()}");

    final (colorBlendMode, color) = chapterColorFIlterValues(context, ref);
    return GestureDetector(
      onLongPress: () => onLongPressData.call(data),
      child: Stack(
        children: [
          ExtendedImage(
            key: _imageKey,
            image: image,
            colorBlendMode: colorBlendMode,
            color: color,
            fit: getBoxFit(scaleType),
            filterQuality: FilterQuality.medium,
            mode: ExtendedImageMode.gesture,
            handleLoadingProgress: true,
            loadStateChanged: loadStateChanged,
            initGestureConfigHandler: initGestureConfigHandler,
            onDoubleTap: onDoubleTap,
          ),

          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTapDown:
                  (details) => print("TapDown: ${details.localPosition}"),
              onTapUp: (details) => print("TapUp: ${details.localPosition}"),
              child: SizedBox.expand(
                child: WordBoxOverlay(
                  wordBoxes: [...wordBoxes!],
                  onWordTap: (word) => print("Tapped word $word"),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
