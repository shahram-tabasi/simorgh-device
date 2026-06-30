import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../api/api_client.dart';
import '../config/app_config.dart';
import '../face/face_service.dart';
import 'theme.dart';

/// Enroll one or more face samples for a member (identified by personnel
/// code, with email as an optional fallback).
/// Multiple samples improve recognition accuracy.
class EnrollScreen extends StatefulWidget {
  const EnrollScreen({
    super.key,
    required this.config,
    required this.faceService,
  });

  final AppConfig config;
  final FaceService faceService;

  @override
  State<EnrollScreen> createState() => _EnrollScreenState();
}

class _EnrollScreenState extends State<EnrollScreen> {
  final _code = TextEditingController();
  final _email = TextEditingController();
  late final ApiClient _api = ApiClient(widget.config);
  CameraController? _camera;
  bool _ready = false;
  bool _busy = false;
  int _samples = 0;
  String? _msg;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cams = await availableCameras();
      final front = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cams.first,
      );
      final c = CameraController(front, ResolutionPreset.medium,
          enableAudio: false, imageFormatGroup: ImageFormatGroup.jpeg);
      await c.initialize();
      _camera = c;
    } catch (_) {}
    if (mounted) setState(() => _ready = true);
  }

  @override
  void dispose() {
    _camera?.dispose();
    _code.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _captureAndEnroll() async {
    final code = _code.text.trim();
    final email = _email.text.trim();
    if (code.isEmpty && email.isEmpty) {
      setState(() => _msg = 'کد پرسنلی (یا ایمیل) کارمند را وارد کنید.');
      return;
    }
    final cam = _camera;
    if (cam == null || !cam.value.isInitialized || _busy) return;
    setState(() {
      _busy = true;
      _msg = null;
    });
    try {
      final shot = await cam.takePicture();
      final cap = await widget.faceService.processFile(shot.path);
      if (!cap.ok) {
        setState(() => _msg = cap.error ?? 'چهره تشخیص داده نشد.');
        return;
      }
      // Always store the captured face photo with the enrollment so the
      // person's image is on file (recognition still uses the embedding).
      final photo = cap.faceCrop != null ? _encodePhoto(cap.faceCrop!) : null;
      final res = await _api.enroll(
        embedding: cap.embedding!,
        personnelCode: code,
        email: email,
        photoBase64: photo,
      );
      if (!res.ok) {
        setState(() => _msg = res.error ?? 'ثبت ناموفق بود.');
      } else {
        setState(() {
          _samples = res.samples;
          _msg = 'نمونه ثبت شد. مجموع نمونه‌ها: $_samples';
        });
      }
    } catch (e) {
      setState(() => _msg = 'خطا: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _encodePhoto(img.Image face) {
    final small = img.copyResize(face, width: 320);
    final jpg = img.encodeJpg(small, quality: 70);
    return 'data:image/jpeg;base64,${base64Encode(jpg)}';
  }

  @override
  Widget build(BuildContext context) {
    final cam = _camera;
    return Scaffold(
      appBar: AppBar(title: const Text('ثبت چهره کارمند'), backgroundColor: SkTheme.bg),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
            child: TextField(
              controller: _code,
              textDirection: TextDirection.ltr,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'کد پرسنلی',
                hintText: '۱۰۲۳',
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: TextField(
              controller: _email,
              textDirection: TextDirection.ltr,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'ایمیل کارمند (اختیاری)',
                hintText: 'ali@company.ir',
              ),
            ),
          ),
          Expanded(
            child: !_ready
                ? const Center(child: CircularProgressIndicator(color: SkTheme.gold))
                : (cam != null && cam.value.isInitialized)
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: cam.value.previewSize?.height ?? 720,
                            height: cam.value.previewSize?.width ?? 1280,
                            child: CameraPreview(cam),
                          ),
                        ),
                      )
                    : const Center(child: Text('دوربین در دسترس نیست.')),
          ),
          if (_msg != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Text(_msg!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: SkTheme.goldLight)),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _busy ? null : _captureAndEnroll,
                icon: const Icon(Icons.add_a_photo),
                label: Text(_busy ? '…' : 'گرفتن نمونهٔ چهره'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
