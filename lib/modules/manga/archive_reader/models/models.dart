import 'package:flutter/foundation.dart';
import 'dart:ui';

class LocalArchive {
  String? name;

  Uint8List? coverImage;

  List<LocalImage>? images = [];

  LocalExtensionType? extensionType;

  String? path;
}

enum LocalExtensionType { cbz, zip, cbt, tar, folder }

class LocalImage {
  String? name;
  Uint8List? image;

  List<WordBox> wordBoxes = [];
}

// Each image (optionally) has a corresponding set of boxes that indicate the positions of text
// and the content of text within them
class WordBox {
  String word;
  Rect boundingBox;

  WordBox({required this.word, required this.boundingBox});

  factory WordBox.fromJson(Map<String, dynamic> json) => WordBox(
    word: json['text'],
    boundingBox: Rect.fromLTWH(
      (json['x'] as num).toDouble(),
      (json['y'] as num).toDouble(),
      (json['width'] as num).toDouble(),
      (json['height'] as num).toDouble(),
    ),
  );

  Map<String, dynamic> toJson() => {
    'word': word,
    'x': boundingBox.left,
    'y': boundingBox.top,
    'width': boundingBox.width,
    'height': boundingBox.height,
  };
  @override
  String toString() {
    return 'WordBox(text: $word, boundingBox: ${boundingBox.toString()})';
  }
}
