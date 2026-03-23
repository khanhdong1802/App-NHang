import 'dart:convert';
import 'package:http/http.dart' as http;

import 'api_config.dart';

class AdminApi {
  final String baseUrl;
  final Future<String?> Function() tokenProvider;

  AdminApi({
    required this.baseUrl,
    required this.tokenProvider,
  });

  Future<Map<String, String>> _headers() async {
    final token = await tokenProvider();
    return {
      "Content-Type": "application/json",
      if (token != null && token.isNotEmpty) "Authorization": "Bearer $token",
    };
  }

  /// Ghép URL chuẩn: baseUrl + apiPrefix + path
  Uri _u(String path) {
    // path phải bắt đầu bằng "/"
    final p = path.startsWith("/") ? path : "/$path";
    return Uri.parse("$baseUrl${ApiConfig.apiPrefix}$p");
  }

  Future<List<Map<String, dynamic>>> fetchUsers() async {
    final r = await http.get(_u("/admin/users"), headers: await _headers());
    if (r.statusCode >= 400) throw Exception("Không lấy được users");
    final data = jsonDecode(r.body);
    return (data as List).map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> lockUser(String userId) async {
    final r = await http.patch(
      _u("/admin/users/$userId/status/lock"),
      headers: await _headers(),
    );
    if (r.statusCode >= 400) throw Exception("Khóa user thất bại");
  }

  Future<void> unlockUser(String userId) async {
    final r = await http.patch(
      _u("/admin/users/$userId/status/unlock"),
      headers: await _headers(),
    );
    if (r.statusCode >= 400) throw Exception("Mở khóa user thất bại");
  }

  Future<void> deleteUser(String userId) async {
    final r = await http.delete(
      _u("/admin/users/$userId"),
      headers: await _headers(),
    );
    if (r.statusCode >= 400) throw Exception("Xóa user thất bại");
  }

  Future<List<Map<String, dynamic>>> fetchCategories() async {
    final r = await http.get(_u("/admin/categories"), headers: await _headers());
    if (r.statusCode >= 400) throw Exception("Không lấy được categories");
    final data = jsonDecode(r.body);
    return (data as List).map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<Map<String, dynamic>> addCategory(Map<String, dynamic> payload) async {
    final r = await http.post(
      _u("/admin/categories"),
      headers: await _headers(),
      body: jsonEncode(payload),
    );
    if (r.statusCode >= 400) throw Exception("Thêm category thất bại");
    return Map<String, dynamic>.from(jsonDecode(r.body));
  }

  Future<Map<String, dynamic>> updateCategory(
      String id,
      Map<String, dynamic> payload,
      ) async {
    final r = await http.put(
      _u("/admin/categories/$id"),
      headers: await _headers(),
      body: jsonEncode(payload),
    );
    if (r.statusCode >= 400) throw Exception("Sửa category thất bại");
    return Map<String, dynamic>.from(jsonDecode(r.body));
  }

  Future<void> deleteCategory(String id) async {
    final r = await http.delete(
      _u("/admin/categories/$id"),
      headers: await _headers(),
    );
    if (r.statusCode >= 400) throw Exception("Xóa category thất bại");
  }

  Future<List<Map<String, dynamic>>> fetchGroupsAll() async {
    final r = await http.get(_u("/group/groups/all"), headers: await _headers());
    if (r.statusCode >= 400) throw Exception("Không lấy được groups");

    final data = jsonDecode(r.body);

    // response có thể là { groups: [...] } hoặc là list trực tiếp
    final groups =
    (data is Map && data["groups"] is List) ? data["groups"] as List : (data as List);

    return groups.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> deleteGroup(String groupId) async {
    final r = await http.delete(
      _u("/group/groups/$groupId"),
      headers: await _headers(),
    );
    if (r.statusCode >= 400) throw Exception("Xóa nhóm thất bại");
  }

  Future<Map<String, dynamic>> fetchOverviewStats() async {
    final r = await http.get(_u("/admin/stats/overview"), headers: await _headers());
    if (r.statusCode >= 400) throw Exception("Không lấy được stats");
    return Map<String, dynamic>.from(jsonDecode(r.body));
  }
}
