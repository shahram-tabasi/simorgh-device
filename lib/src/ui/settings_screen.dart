import 'package:flutter/material.dart';

import '../config/app_config.dart';
import 'theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.config,
    required this.onSaved,
    this.firstRun = false,
  });

  final AppConfig config;
  final Future<void> Function(AppConfig) onSaved;
  final bool firstRun;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final _baseUrl = TextEditingController(text: widget.config.baseUrl);
  late final _slug = TextEditingController(text: widget.config.slug);
  late final _token = TextEditingController(text: widget.config.deviceToken);
  late final _adminUser = TextEditingController(text: widget.config.adminUser);
  late final _adminPass = TextEditingController(text: widget.config.adminPass);
  late String _kind = widget.config.deviceKind;
  late PunchDirection _dir = widget.config.direction;
  late bool _photo = widget.config.attachPhoto;
  late bool _gps = widget.config.attachGps;
  late bool _auto = widget.config.autoCapture;
  late double _threshold = widget.config.matchThreshold;
  bool _saving = false;

  @override
  void dispose() {
    _baseUrl.dispose();
    _slug.dispose();
    _token.dispose();
    _adminUser.dispose();
    _adminPass.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_baseUrl.text.trim().isEmpty ||
        _slug.text.trim().isEmpty ||
        _token.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('آدرس سرور، اسلاگ شرکت و توکن دستگاه الزامی است.'),
      ));
      return;
    }
    setState(() => _saving = true);
    final c = widget.config.copyWith(
      baseUrl: _baseUrl.text,
      slug: _slug.text,
      deviceToken: _token.text,
      deviceKind: _kind,
      direction: _dir,
      attachPhoto: _photo,
      attachGps: _gps,
      autoCapture: _auto,
      matchThreshold: _threshold,
      adminUser: _adminUser.text.trim().isEmpty ? 'admin' : _adminUser.text,
      adminPass: _adminPass.text,
    );
    await widget.onSaved(c);
    if (!mounted) return;
    setState(() => _saving = false);
    if (!widget.firstRun) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تنظیمات دستگاه'),
        backgroundColor: SkTheme.bg,
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          if (widget.firstRun)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'برای شروع، اطلاعات اتصال به سیمرغ‌کارا را وارد کنید. این مقادیر را مدیر/کارگزینی از بخش «دستگاه‌های تردد» در اختیار شما می‌گذارد.',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          _field(_baseUrl, 'آدرس سرور', ltr: true, hint: 'https://app.simorghkara.ir'),
          _field(_slug, 'اسلاگ شرکت', ltr: true, hint: 'aahangari-demo'),
          _field(_token, 'توکن دستگاه', ltr: true, hint: 'device token'),
          const Divider(height: 28),
          _label('ورود اپراتور به دستگاه'),
          const Padding(
            padding: EdgeInsets.only(bottom: 8, right: 2),
            child: Text(
              'این نام کاربری و گذرواژه برای باز کردن قفل ترمینال هنگام اجرا لازم است. اگر گذرواژه را خالی بگذارید، صفحهٔ ورود نمایش داده نمی‌شود.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
          _field(_adminUser, 'نام کاربری دستگاه', ltr: true, hint: 'admin'),
          _field(_adminPass, 'گذرواژه دستگاه', ltr: true, hint: '••••'),
          const Divider(height: 28),
          _label('نوع دستگاه'),
          DropdownButtonFormField<String>(
            value: _kind,
            items: [
              for (final k in DeviceKind.all)
                DropdownMenuItem(value: k, child: Text(DeviceKind.label(k))),
            ],
            onChanged: (v) => setState(() => _kind = v ?? DeviceKind.device),
          ),
          const SizedBox(height: 12),
          _label('جهت ثبت تردد'),
          DropdownButtonFormField<PunchDirection>(
            value: _dir,
            items: [
              for (final d in PunchDirection.values)
                DropdownMenuItem(value: d, child: Text(d.label)),
            ],
            onChanged: (v) => setState(() => _dir = v ?? PunchDirection.ask),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            value: _auto,
            onChanged: (v) => setState(() => _auto = v),
            title: const Text('ثبت خودکار هنگام تشخیص چهره'),
            activeColor: SkTheme.gold,
          ),
          SwitchListTile(
            value: _photo,
            onChanged: (v) => setState(() => _photo = v),
            title: const Text('ضمیمه‌کردن عکس لحظهٔ تردد'),
            activeColor: SkTheme.gold,
          ),
          SwitchListTile(
            value: _gps,
            onChanged: (v) => setState(() => _gps = v),
            title: const Text('ثبت موقعیت مکانی (GPS)'),
            activeColor: SkTheme.gold,
          ),
          const SizedBox(height: 8),
          _label('آستانهٔ تطبیق چهره: ${_threshold.toStringAsFixed(2)}'),
          Slider(
            value: _threshold,
            min: 0.45,
            max: 0.85,
            divisions: 40,
            activeColor: SkTheme.gold,
            onChanged: (v) => setState(() => _threshold = v),
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? '…' : 'ذخیره و ادامه'),
          ),
        ],
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6, right: 2),
        child: Text(t, style: const TextStyle(color: Colors.white70, fontSize: 13)),
      );

  Widget _field(TextEditingController c, String label,
      {bool ltr = false, String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label),
          TextField(
            controller: c,
            textDirection: ltr ? TextDirection.ltr : null,
            decoration: InputDecoration(hintText: hint),
          ),
        ],
      ),
    );
  }
}
