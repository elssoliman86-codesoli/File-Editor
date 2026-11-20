import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

Future<Uint8List> rgbaToJpeg(Uint8List rgba, int width, int height) {
  return compute(_encodeJpeg, (rgba: rgba, width: width, height: height));
}

Uint8List _encodeJpeg(({Uint8List rgba, int width, int height}) input) {
  final image = img.Image.fromBytes(
    width: input.width,
    height: input.height,
    bytes: input.rgba.buffer,
    order: img.ChannelOrder.rgba,
  );
  return Uint8List.fromList(img.encodeJpg(image, quality: 88));
}
