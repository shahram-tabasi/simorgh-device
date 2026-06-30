import 'dart:math' as math;

import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

/// Runs a MobileFaceNet / FaceNet TFLite model on-device to turn a cropped
/// face image into an embedding vector. The server stores and matches these
/// vectors; the raw face never leaves the device.
///
/// Place the model at: assets/models/mobilefacenet.tflite
/// (see assets/models/README.md for where to obtain a compatible model).
class FaceEmbedder {
  FaceEmbedder._(this._interpreter, this._inputSize, this._outputLength);

  final Interpreter _interpreter;
  final int _inputSize; // typically 112
  final int _outputLength; // typically 192 or 128

  static const _assetPath = 'assets/models/mobilefacenet.tflite';

  static Future<FaceEmbedder> load() async {
    final interpreter = await Interpreter.fromAsset(_assetPath);
    final inShape = interpreter.getInputTensor(0).shape; // [1, H, W, 3]
    final outShape = interpreter.getOutputTensor(0).shape; // [1, N]
    final inputSize = inShape.length >= 3 ? inShape[1] : 112;
    final outputLength = outShape.last;
    return FaceEmbedder._(interpreter, inputSize, outputLength);
  }

  int get inputSize => _inputSize;

  /// Compute the embedding for an already-cropped face image.
  List<double> embed(img.Image face) {
    final resized = img.copyResize(face, width: _inputSize, height: _inputSize);

    // Build [1, size, size, 3] float input, normalized to [-1, 1].
    final input = List.generate(
      1,
      (_) => List.generate(
        _inputSize,
        (y) => List.generate(_inputSize, (x) {
          final p = resized.getPixel(x, y);
          return [
            (p.r - 127.5) / 128.0,
            (p.g - 127.5) / 128.0,
            (p.b - 127.5) / 128.0,
          ];
        }),
      ),
    );

    final output =
        List.generate(1, (_) => List<double>.filled(_outputLength, 0.0));
    _interpreter.run(input, output);

    return _l2normalize(output[0]);
  }

  List<double> _l2normalize(List<double> v) {
    var sum = 0.0;
    for (final x in v) {
      sum += x * x;
    }
    final mag = math.sqrt(sum);
    if (mag == 0) return v;
    return [for (final x in v) x / mag];
  }

  void close() => _interpreter.close();
}
