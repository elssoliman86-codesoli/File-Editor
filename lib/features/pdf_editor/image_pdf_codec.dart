import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:jpeg_encode/jpeg_encode.dart';

Future<Uint8List> rgbaToJpeg(Uint8List rgba, int width, int height) {
  return compute(_encodeJpeg, (rgba: rgba, width: width, height: height));
}

Uint8List _encodeJpeg(({Uint8List rgba, int width, int height}) input) {
  return JpegEncoder().compress(input.rgba, input.width, input.height, 88);
}
