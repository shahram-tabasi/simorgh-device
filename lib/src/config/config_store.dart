import 'package:shared_preferences/shared_preferences.dart';

import 'app_config.dart';

/// Loads and persists [AppConfig] in shared preferences.
class ConfigStore {
  static const _kBaseUrl = 'base_url';
  static const _kSlug = 'slug';
  static const _kToken = 'device_token';
  static const _kKind = 'device_kind';
  static const _kDir = 'direction';
  static const _kPhoto = 'attach_photo';
  static const _kGps = 'attach_gps';
  static const _kAuto = 'auto_capture';
  static const _kThreshold = 'match_threshold';
  static const _kAdminUser = 'admin_user';
  static const _kAdminPass = 'admin_pass';

  Future<AppConfig> load() async {
    final p = await SharedPreferences.getInstance();
    return AppConfig(
      baseUrl: p.getString(_kBaseUrl) ?? '',
      slug: p.getString(_kSlug) ?? '',
      deviceToken: p.getString(_kToken) ?? '',
      deviceKind: p.getString(_kKind) ?? DeviceKind.device,
      direction: PunchDirectionX.fromStorage(p.getString(_kDir)),
      attachPhoto: p.getBool(_kPhoto) ?? true,
      attachGps: p.getBool(_kGps) ?? false,
      autoCapture: p.getBool(_kAuto) ?? true,
      matchThreshold: p.getDouble(_kThreshold) ?? 0.62,
      adminUser: p.getString(_kAdminUser) ?? 'admin',
      adminPass: p.getString(_kAdminPass) ?? '1234',
    );
  }

  Future<void> save(AppConfig c) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kBaseUrl, c.baseUrl.trim());
    await p.setString(_kSlug, c.slug.trim());
    await p.setString(_kToken, c.deviceToken.trim());
    await p.setString(_kKind, c.deviceKind);
    await p.setString(_kDir, c.direction.storage);
    await p.setBool(_kPhoto, c.attachPhoto);
    await p.setBool(_kGps, c.attachGps);
    await p.setBool(_kAuto, c.autoCapture);
    await p.setDouble(_kThreshold, c.matchThreshold);
    await p.setString(_kAdminUser, c.adminUser.trim());
    await p.setString(_kAdminPass, c.adminPass);
  }
}
