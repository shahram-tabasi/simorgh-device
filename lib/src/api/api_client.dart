import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

/// Result of a recognition / punch attempt.
class PunchResult {
  PunchResult({
    required this.matched,
    this.memberName,
    this.memberId,
    this.score,
    this.punchId,
    this.error,
  });

  final bool matched;
  final String? memberName;
  final String? memberId;
  final double? score;
  final String? punchId;
  final String? error;

  bool get ok => error == null;
  bool get punched => punchId != null;
}

/// Thin client over the SIMORGH-KARA device endpoints.
///
/// All requests authenticate with the device token as a Bearer header.
class ApiClient {
  ApiClient(this.config);

  final AppConfig config;

  Uri _u(String path) {
    var base = config.baseUrl.trim();
    if (base.endsWith('/')) base = base.substring(0, base.length - 1);
    return Uri.parse('$base/api/${config.slug}/attendance$path');
  }

  Map<String, String> get _headers => {
        'content-type': 'application/json',
        'authorization': 'Bearer ${config.deviceToken.trim()}',
      };

  /// Identify a member from a face embedding and optionally punch them.
  Future<PunchResult> identify({
    required List<double> embedding,
    String? kind, // 'in' | 'out'  (null => no auto punch)
    String? photoBase64,
    double? lat,
    double? lng,
  }) async {
    final body = <String, dynamic>{
      'embedding': embedding,
      if (kind != null) ...{'kind': kind, 'auto_punch': true},
      if (photoBase64 != null) 'photo_url': photoBase64,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
    };
    try {
      final r = await http
          .post(_u('/face/identify'), headers: _headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 20));
      final j = _decode(r);
      if (r.statusCode >= 400) {
        return PunchResult(matched: false, error: _err(j, r.statusCode));
      }
      final matched = j['matched'] == true;
      return PunchResult(
        matched: matched,
        memberName: matched ? (j['member']?['name'] as String?) : null,
        memberId: matched ? (j['member']?['id'] as String?) : null,
        score: (j['score'] as num?)?.toDouble(),
        punchId: j['punch_id'] as String?,
      );
    } catch (e) {
      return PunchResult(matched: false, error: 'خطای شبکه: $e');
    }
  }

  /// Enroll a face embedding for a member (by personnel code, email or member id).
  /// The captured face photo is stored alongside the embedding when provided.
  Future<({bool ok, int samples, String? error})> enroll({
    required List<double> embedding,
    String? personnelCode,
    String? email,
    String? memberId,
    String? photoBase64,
  }) async {
    final body = <String, dynamic>{
      'embedding': embedding,
      if (personnelCode != null && personnelCode.isNotEmpty)
        'personnel_code': personnelCode,
      if (email != null && email.isNotEmpty) 'email': email,
      if (memberId != null && memberId.isNotEmpty) 'member_id': memberId,
      if (photoBase64 != null) 'photo_url': photoBase64,
    };
    try {
      final r = await http
          .post(_u('/face/enroll'), headers: _headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 20));
      final j = _decode(r);
      if (r.statusCode >= 400) {
        return (ok: false, samples: 0, error: _err(j, r.statusCode));
      }
      return (ok: true, samples: (j['samples'] as num?)?.toInt() ?? 0, error: null);
    } catch (e) {
      return (ok: false, samples: 0, error: 'خطای شبکه: $e');
    }
  }

  /// Manual punch by personnel code / email / member id (fallback when face fails).
  Future<PunchResult> manualPunch({
    required String kind, // 'in' | 'out'
    String? personnelCode,
    String? email,
    String? memberId,
    double? lat,
    double? lng,
  }) async {
    final body = <String, dynamic>{
      'kind': kind,
      if (personnelCode != null && personnelCode.isNotEmpty)
        'personnel_code': personnelCode,
      if (email != null && email.isNotEmpty) 'email': email,
      if (memberId != null && memberId.isNotEmpty) 'member_id': memberId,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
    };
    try {
      final r = await http
          .post(_u('/ingest'), headers: _headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 20));
      final j = _decode(r);
      if (r.statusCode >= 400) {
        return PunchResult(matched: false, error: _err(j, r.statusCode));
      }
      return PunchResult(matched: true, punchId: j['punch_id'] as String?);
    } catch (e) {
      return PunchResult(matched: false, error: 'خطای شبکه: $e');
    }
  }

  Map<String, dynamic> _decode(http.Response r) {
    try {
      return jsonDecode(r.body) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  String _err(Map<String, dynamic> j, int status) {
    final e = j['error']?.toString();
    return switch (status) {
      401 => 'توکن دستگاه نامعتبر است.',
      404 => e == 'member not found' ? 'کاربر شناسایی نشد.' : 'شرکت یافت نشد.',
      _ => e ?? 'خطای سرور ($status)',
    };
  }
}
