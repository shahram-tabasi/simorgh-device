import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../config/app_config.dart';
import 'theme.dart';

/// Fallback: punch by personnel email when face recognition can't be used.
class ManualPunchScreen extends StatefulWidget {
  const ManualPunchScreen({super.key, required this.config});
  final AppConfig config;

  @override
  State<ManualPunchScreen> createState() => _ManualPunchScreenState();
}

class _ManualPunchScreenState extends State<ManualPunchScreen> {
  final _code = TextEditingController();
  final _email = TextEditingController();
  late final ApiClient _api = ApiClient(widget.config);
  bool _busy = false;
  String? _msg;
  bool _ok = false;

  @override
  void dispose() {
    _code.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _punch(String kind) async {
    final code = _code.text.trim();
    final email = _email.text.trim();
    if (code.isEmpty && email.isEmpty) {
      setState(() {
        _ok = false;
        _msg = 'کد پرسنلی (یا ایمیل) کارمند را وارد کنید.';
      });
      return;
    }
    setState(() {
      _busy = true;
      _msg = null;
    });
    final res = await _api.manualPunch(
      kind: kind,
      personnelCode: code,
      email: email,
    );
    setState(() {
      _busy = false;
      _ok = res.ok;
      _msg = res.ok
          ? '${kind == 'in' ? 'ورود' : 'خروج'} با موفقیت ثبت شد.'
          : res.error;
    });
    if (res.ok) {
      _code.clear();
      _email.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تردد دستی'), backgroundColor: SkTheme.bg),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Text('کد پرسنلی (یا ایمیل) کارمند را وارد و ورود یا خروج را ثبت کنید.',
              style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 14),
          TextField(
            controller: _code,
            textDirection: TextDirection.ltr,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'کد پرسنلی',
              hintText: '۱۰۲۳',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _email,
            textDirection: TextDirection.ltr,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'ایمیل کارمند (اختیاری)',
              hintText: 'ali@company.ir',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: SkTheme.ok),
                  onPressed: _busy ? null : () => _punch('in'),
                  icon: const Icon(Icons.login),
                  label: const Text('ورود'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: SkTheme.danger),
                  onPressed: _busy ? null : () => _punch('out'),
                  icon: const Icon(Icons.logout),
                  label: const Text('خروج'),
                ),
              ),
            ],
          ),
          if (_msg != null)
            Padding(
              padding: const EdgeInsets.only(top: 18),
              child: Text(
                _msg!,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: _ok ? SkTheme.ok : SkTheme.danger,
                    fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }
}
