import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image/image.dart' as img;

import '../api/api_client.dart';
import '../config/app_config.dart';
import '../face/face_embedder.dart';
import '../face/face_service.dart';
import 'enroll_screen.dart';
import 'manual_punch_screen.dart';
import 'settings_screen.dart';
import 'theme.dart';

class TerminalScreen extends StatefulWidget {
  const TerminalScreen({
    super.key,
    required this.config,
    required this.onConfigChanged,
  });

  final AppConfig config;
  final Future<void> Function(AppConfig) onConfigChanged;

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen>
    with WidgetsBindingObserver {
  CameraController? _camera;
  FaceService? _faceService;
  bool _initializing = true;
  bool _busy = false;
  String? _faceError; // model/camera load error
  _Feedback? _feedback;

  AppConfig get _config => widget.config;
  late final ApiClient _api = ApiClient(_config);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final cameras = await availableCameras();
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      _camera = controller;
    } catch (e) {
      _faceError = 'دوربین در دسترس نیست: $e';
    }

    try {
      final embedder = await FaceEmbedder.load();
      _faceService = FaceService(embedder);
    } catch (e) {
      _faceError =
          'مدل تشخیص چهره بارگذاری نشد. فایل assets/models/mobilefacenet.tflite را اضافه کنید یا از «تردد دستی» استفاده کنید.';
    }

    if (mounted) setState(() => _initializing = false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final cam = _camera;
    if (cam == null || !cam.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      cam.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _bootstrap();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _camera?.dispose();
    _faceService?.close();
    super.dispose();
  }

  Future<void> _capture(String? kind) async {
    if (_busy) return;
    final cam = _camera;
    final fs = _faceService;
    if (cam == null || !cam.value.isInitialized || fs == null) {
      _show(_Feedback.error(_faceError ?? 'دوربین/مدل آماده نیست.'));
      return;
    }
    setState(() => _busy = true);
    try {
      final shot = await cam.takePicture();
      final capture = await fs.processFile(shot.path);
      if (!capture.ok) {
        _show(_Feedback.error(capture.error ?? 'چهره تشخیص داده نشد.'));
        return;
      }

      final photo = _config.attachPhoto ? _encodePhoto(capture.faceCrop!) : null;
      final pos = _config.attachGps ? await _maybePosition() : null;

      final res = await _api.identify(
        embedding: capture.embedding!,
        kind: kind, // null => recognize only (ask mode handled by caller)
        photoBase64: photo,
        lat: pos?.latitude,
        lng: pos?.longitude,
      );

      if (!res.ok) {
        _show(_Feedback.error(res.error!));
      } else if (!res.matched) {
        _show(_Feedback.error('شناسایی نشد. دوباره تلاش کنید یا تردد دستی.'));
      } else if (res.score != null && res.score! < _config.matchThreshold) {
        _show(_Feedback.error('اطمینان کم است؛ دوباره تلاش کنید.'));
      } else {
        final dir = kind == 'out' ? 'خروج' : kind == 'in' ? 'ورود' : '';
        _show(_Feedback.success(res.memberName ?? 'کاربر', dir, res.score));
      }
    } catch (e) {
      _show(_Feedback.error('خطا: $e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _encodePhoto(img.Image face) {
    final small = img.copyResize(face, width: 320);
    final jpg = img.encodeJpg(small, quality: 70);
    return 'data:image/jpeg;base64,${base64Encode(jpg)}';
  }

  Future<Position?> _maybePosition() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition();
    } catch (_) {
      return null;
    }
  }

  void _show(_Feedback fb) {
    setState(() => _feedback = fb);
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && _feedback == fb) setState(() => _feedback = null);
    });
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SettingsScreen(
        config: _config,
        onSaved: (c) async {
          await widget.onConfigChanged(c);
          if (mounted) Navigator.of(context).maybePop();
        },
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            Expanded(child: _preview()),
            _actions(),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.asset('assets/branding/logo.png',
                width: 26, height: 26, fit: BoxFit.cover),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('سیمرغ‌کارا — دستگاه حضور و غیاب',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text('${_config.slug} · ${DeviceKind.label(_config.deviceKind)}',
                    style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'ثبت چهره',
            icon: const Icon(Icons.face_retouching_natural, color: SkTheme.gold),
            onPressed: _faceService == null
                ? null
                : () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => EnrollScreen(
                        config: _config,
                        faceService: _faceService!,
                      ),
                    )),
          ),
          IconButton(
            tooltip: 'تردد دستی',
            icon: const Icon(Icons.dialpad, color: Colors.white70),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ManualPunchScreen(config: _config),
            )),
          ),
          IconButton(
            tooltip: 'تنظیمات',
            icon: const Icon(Icons.settings, color: Colors.white70),
            onPressed: _openSettings,
          ),
        ],
      ),
    );
  }

  Widget _preview() {
    if (_initializing) {
      return const Center(child: CircularProgressIndicator(color: SkTheme.gold));
    }
    final cam = _camera;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (cam != null && cam.value.isInitialized)
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: cam.value.previewSize?.height ?? 720,
                height: cam.value.previewSize?.width ?? 1280,
                child: CameraPreview(cam),
              ),
            ),
          )
        else
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(_faceError ?? 'دوربین در دسترس نیست.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70)),
            ),
          ),
        // oval guide
        IgnorePointer(
          child: Center(
            child: Container(
              width: 230,
              height: 300,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(150),
                border: Border.all(
                    color: SkTheme.gold.withOpacity(0.6), width: 3),
              ),
            ),
          ),
        ),
        if (_busy)
          Container(
            color: Colors.black54,
            child: const Center(
                child: CircularProgressIndicator(color: SkTheme.gold)),
          ),
        if (_feedback != null) _feedbackBanner(_feedback!),
      ],
    );
  }

  Widget _feedbackBanner(_Feedback fb) {
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        margin: const EdgeInsets.all(14),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: (fb.success ? SkTheme.ok : SkTheme.danger)
              .withOpacity(0.18),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: (fb.success ? SkTheme.ok : SkTheme.danger)
                  .withOpacity(0.6)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(fb.success ? '✓' : '✕',
                style: TextStyle(
                    fontSize: 34,
                    color: fb.success ? SkTheme.ok : SkTheme.danger)),
            const SizedBox(height: 4),
            Text(fb.title,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold)),
            if (fb.subtitle != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(fb.subtitle!,
                    style: const TextStyle(color: Colors.white70)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _actions() {
    final ask = _config.direction == PunchDirection.ask;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: ask
          ? Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: SkTheme.ok),
                    onPressed: _busy ? null : () => _capture('in'),
                    icon: const Icon(Icons.login),
                    label: const Text('ورود'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style:
                        ElevatedButton.styleFrom(backgroundColor: SkTheme.danger),
                    onPressed: _busy ? null : () => _capture('out'),
                    icon: const Icon(Icons.logout),
                    label: const Text('خروج'),
                  ),
                ),
              ],
            )
          : SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _busy
                    ? null
                    : () => _capture(_config.direction == PunchDirection.outOnly
                        ? 'out'
                        : 'in'),
                icon: const Icon(Icons.center_focus_strong),
                label: Text(
                    'ثبت ${_config.direction == PunchDirection.outOnly ? 'خروج' : 'ورود'}'),
              ),
            ),
    );
  }
}

class _Feedback {
  _Feedback(this.success, this.title, [this.subtitle]);
  factory _Feedback.success(String name, String dir, double? score) =>
      _Feedback(
        true,
        '$name${dir.isNotEmpty ? ' — $dir ثبت شد' : ''}',
        score != null ? 'اطمینان: ${(score * 100).toStringAsFixed(0)}٪' : null,
      );
  factory _Feedback.error(String msg) => _Feedback(false, msg);

  final bool success;
  final String title;
  final String? subtitle;
}
