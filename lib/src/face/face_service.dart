import 'dart:io';
import 'dart:ui' show Rect;

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;

import 'face_embedder.dart';

/// Outcome of processing one captured frame.
class FaceCapture {
  FaceCapture({this.embedding, this.faceCrop, this.error});
  final List<double>? embedding;
  final img.Image? faceCrop;
  final String? error;

  bool get ok => embedding != null;
}

/// Detects the largest face in a captured photo, crops it, and produces an
/// embedding via [FaceEmbedder]. Detection runs with Google ML Kit; embedding
/// runs with the bundled TFLite model.
class FaceService {
  FaceService(this._embedder);

  final FaceEmbedder _embedder;

  final FaceDetector _detector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.accurate,
      minFaceSize: 0.15,
    ),
  );

  /// Process a JPEG file written by the camera's takePicture().
  Future<FaceCapture> processFile(String path) async {
    final bytes = await File(path).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      return FaceCapture(error: 'تصویر قابل خواندن نیست.');
    }

    final faces = await _detector.processImage(InputImage.fromFilePath(path));
    if (faces.isEmpty) {
      return FaceCapture(error: 'چهره‌ای تشخیص داده نشد. روبه‌روی دوربین قرار بگیرید.');
    }

    // Largest face wins (closest to the camera).
    faces.sort((a, b) =>
        (b.boundingBox.width * b.boundingBox.height)
            .compareTo(a.boundingBox.width * a.boundingBox.height));
    final box = faces.first.boundingBox;

    final crop = _cropWithMargin(decoded, box, margin: 0.25);
    final embedding = _embedder.embed(crop);
    return FaceCapture(embedding: embedding, faceCrop: crop);
  }

  img.Image _cropWithMargin(img.Image src, Rect box, {double margin = 0.2}) {
    final mw = box.width * margin;
    final mh = box.height * margin;
    var x = (box.left - mw).round();
    var y = (box.top - mh).round();
    var w = (box.width + 2 * mw).round();
    var h = (box.height + 2 * mh).round();

    x = x.clamp(0, src.width - 1);
    y = y.clamp(0, src.height - 1);
    w = w.clamp(1, src.width - x);
    h = h.clamp(1, src.height - y);

    return img.copyCrop(src, x: x, y: y, width: w, height: h);
  }

  void close() {
    _detector.close();
    _embedder.close();
  }
}
