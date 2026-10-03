import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as im;

import '../../core/config/api_config.dart';

/// Shrinks a capture until it fits the host upload limit.
Uint8List compressCapture(Uint8List bytes) {
  final decoded = im.decodeImage(bytes);
  if (decoded == null) return bytes;

  var width = decoded.width > 1600 ? 1600 : decoded.width;
  var quality = 82;
  var current = decoded;
  Uint8List encoded = bytes;

  for (var pass = 0; pass < 4; pass++) {
    final resized = current.width > width
        ? im.copyResize(current, width: width)
        : current;
    encoded = Uint8List.fromList(im.encodeJpg(resized, quality: quality));
    if (encoded.length <= ApiConfig.maxUploadBytes - 256 * 1024) {
      return encoded;
    }
    width = (width * 0.8).round();
    quality = 68;
    current = resized;
  }
  return encoded;
}

Future<File> writeCaptureFile({
  required File source,
  required String destinationPath,
}) async {
  final original = await source.readAsBytes();
  final payload = original.length > 7 * 1024 * 1024
      ? await compute(compressCapture, original)
      : original;
  final file = File(destinationPath);
  await file.writeAsBytes(payload, flush: true);
  return file;
}
