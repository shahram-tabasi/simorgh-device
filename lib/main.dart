import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/config/app_config.dart';
import 'src/config/config_store.dart';
import 'src/ui/login_screen.dart';
import 'src/ui/settings_screen.dart';
import 'src/ui/terminal_screen.dart';
import 'src/ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  final config = await ConfigStore().load();
  runApp(SimorghDeviceApp(initialConfig: config));
}

class SimorghDeviceApp extends StatefulWidget {
  const SimorghDeviceApp({super.key, required this.initialConfig});
  final AppConfig initialConfig;

  @override
  State<SimorghDeviceApp> createState() => _SimorghDeviceAppState();
}

class _SimorghDeviceAppState extends State<SimorghDeviceApp> {
  late AppConfig _config = widget.initialConfig;
  final _store = ConfigStore();
  bool _loggedIn = false;

  Future<void> _onConfigChanged(AppConfig c) async {
    await _store.save(c);
    setState(() => _config = c);
  }

  Widget _home() {
    if (!_config.isConfigured) {
      return SettingsScreen(
        config: _config,
        onSaved: _onConfigChanged,
        firstRun: true,
      );
    }
    if (_config.loginEnabled && !_loggedIn) {
      return LoginScreen(
        config: _config,
        onSuccess: () => setState(() => _loggedIn = true),
      );
    }
    return TerminalScreen(config: _config, onConfigChanged: _onConfigChanged);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'سیمرغ‌کارا — دستگاه حضور و غیاب',
      debugShowCheckedModeBanner: false,
      theme: SkTheme.build(),
      locale: const Locale('fa'),
      // RTL for the whole app (no localization delegates needed for fa-only UI).
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: _home(),
    );
  }
}
