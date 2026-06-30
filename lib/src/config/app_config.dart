/// Direction the terminal records for each punch.
enum PunchDirection { inOnly, outOnly, ask }

extension PunchDirectionX on PunchDirection {
  String get storage => switch (this) {
        PunchDirection.inOnly => 'in',
        PunchDirection.outOnly => 'out',
        PunchDirection.ask => 'ask',
      };

  String get label => switch (this) {
        PunchDirection.inOnly => 'فقط ورود',
        PunchDirection.outOnly => 'فقط خروج',
        PunchDirection.ask => 'پرسش از کاربر',
      };

  static PunchDirection fromStorage(String? v) => switch (v) {
        'out' => PunchDirection.outOnly,
        'ask' => PunchDirection.ask,
        _ => PunchDirection.inOnly,
      };
}

/// What kind of device this terminal is registered as (matches the
/// attendance_devices.kind on the server: device | guard | mobile).
class DeviceKind {
  static const device = 'device';
  static const guard = 'guard';
  static const mobile = 'mobile';
  static const all = [device, guard, mobile];

  static String label(String v) => switch (v) {
        guard => 'نگهبانی',
        mobile => 'موبایل',
        _ => 'دستگاه درب',
      };
}

/// Persisted configuration of this terminal.
class AppConfig {
  AppConfig({
    this.baseUrl = '',
    this.slug = '',
    this.deviceToken = '',
    this.deviceKind = DeviceKind.device,
    this.direction = PunchDirection.ask,
    this.attachPhoto = true,
    this.attachGps = false,
    this.autoCapture = true,
    this.matchThreshold = 0.62,
    this.adminUser = 'admin',
    this.adminPass = '1234',
    this.continuousMode = false,
  });

  /// e.g. https://app.simorghkara.ir  (no trailing slash needed)
  final String baseUrl;

  /// company slug, e.g. "aahangari-demo"
  final String slug;

  /// attendance_devices.token issued by HR
  final String deviceToken;

  final String deviceKind;
  final PunchDirection direction;
  final bool attachPhoto;
  final bool attachGps;
  final bool autoCapture;

  /// client-side guard before sending (server also enforces its own threshold)
  final double matchThreshold;

  /// operator credentials required to unlock this terminal on launch.
  final String adminUser;
  final String adminPass;

  /// continuous kiosk mode: the terminal scans automatically and punches each
  /// recognised person in turn, instead of waiting for a button press.
  final bool continuousMode;

  /// whether the terminal is locked behind the login screen on launch.
  bool get loginEnabled => adminPass.trim().isNotEmpty;

  /// validate operator credentials entered on the login screen.
  bool checkLogin(String user, String pass) =>
      user.trim() == adminUser.trim() && pass == adminPass;

  bool get isConfigured =>
      baseUrl.trim().isNotEmpty &&
      slug.trim().isNotEmpty &&
      deviceToken.trim().isNotEmpty;

  AppConfig copyWith({
    String? baseUrl,
    String? slug,
    String? deviceToken,
    String? deviceKind,
    PunchDirection? direction,
    bool? attachPhoto,
    bool? attachGps,
    bool? autoCapture,
    double? matchThreshold,
    String? adminUser,
    String? adminPass,
    bool? continuousMode,
  }) {
    return AppConfig(
      baseUrl: baseUrl ?? this.baseUrl,
      slug: slug ?? this.slug,
      deviceToken: deviceToken ?? this.deviceToken,
      deviceKind: deviceKind ?? this.deviceKind,
      direction: direction ?? this.direction,
      attachPhoto: attachPhoto ?? this.attachPhoto,
      attachGps: attachGps ?? this.attachGps,
      autoCapture: autoCapture ?? this.autoCapture,
      matchThreshold: matchThreshold ?? this.matchThreshold,
      adminUser: adminUser ?? this.adminUser,
      adminPass: adminPass ?? this.adminPass,
      continuousMode: continuousMode ?? this.continuousMode,
    );
  }
}
