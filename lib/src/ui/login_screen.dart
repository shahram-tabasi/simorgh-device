import 'package:flutter/material.dart';

import '../config/app_config.dart';
import 'theme.dart';

/// Operator login that unlocks the terminal on launch.
///
/// Credentials are validated locally against [AppConfig.adminUser] /
/// [AppConfig.adminPass] (set in the device settings). The terminal stays
/// locked until the operator signs in.
class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.config,
    required this.onSuccess,
  });

  final AppConfig config;
  final VoidCallback onSuccess;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  void _submit() {
    if (widget.config.checkLogin(_user.text, _pass.text)) {
      widget.onSuccess();
    } else {
      setState(() => _error = 'نام کاربری یا گذرواژه نادرست است.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/branding/logo.png',
                      width: 96,
                      height: 96,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'سیمرغ‌کارا — دستگاه حضور و غیاب',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'برای ورود به ترمینال وارد شوید',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.6), fontSize: 13),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _user,
                    textDirection: TextDirection.ltr,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'نام کاربری',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _pass,
                    textDirection: TextDirection.ltr,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: 'گذرواژه',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Text(
                        _error!,
                        style: const TextStyle(
                            color: SkTheme.danger,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _submit,
                      icon: const Icon(Icons.login),
                      label: const Text('ورود'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
