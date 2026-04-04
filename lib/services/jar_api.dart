import 'dart:convert';
import 'package:http/http.dart' as http;

class JarApi {
  final String baseUrl;

  JarApi({required this.baseUrl});

  Future<String?> fetchCurrentCycleId({required String token}) async {
    final uri = Uri.parse('$baseUrl/api/jars/cycle/current');

    final r = await http.get(uri, headers: {
      'Authorization': 'Bearer $token',
    });

    Map<String, dynamic>? d;
    try {
      d = jsonDecode(r.body);
    } catch (_) {}

    // ❗ QUAN TRỌNG: lấy message từ backend
    final message =
        d?['message']?.toString() ??
            'Lỗi (${r.statusCode}) khi lấy chu kỳ';

    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw Exception(message);
    }

    final cycle = d?['cycle'];
    final id = cycle?['_id']?.toString();
    if (id == null || id.isEmpty) return null;

    return id;
  }

  Future<void> fundCycle({
    required String token,
    required String cycleId,
    required int amount,
  }) async {
    final uri = Uri.parse('$baseUrl/api/jars/cycle/$cycleId/fund');
    final r = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'amount': amount}),
    );

    Map<String, dynamic>? d;
    try {
      d = jsonDecode(r.body) as Map<String, dynamic>;
    } catch (_) {
      d = null;
    }

    if (r.statusCode < 200 || r.statusCode >= 300 || d?['success'] != true) {
      throw Exception(d?['message']?.toString() ?? 'Nạp thất bại');
    }
  }

  Future<void> applyAllocation({
    required String token,
    required String cycleId,
  }) async {
    final uri = Uri.parse('$baseUrl/api/jars/cycle/$cycleId/apply-allocation');
    final r = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw Exception('Apply allocation thất bại. Mã lỗi: ${r.statusCode}');
    }
  }
}