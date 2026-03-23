import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../models/category.dart';
import '../services/api_config.dart';

class RecordApi {
  final _storage = const FlutterSecureStorage();

  Future<Map<String, dynamic>?> _getUser() async {
    final raw = await _storage.read(key: "user");
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<String?> _getToken() => _storage.read(key: "accessToken");

  Map<String, String> _headers({String? token}) => {
    "Content-Type": "application/json",
    "Accept": "application/json",
    if (token != null && token.isNotEmpty) "Authorization": "Bearer $token",
  };

  Future<List<Category>> fetchCategories() async {
    final uri = Uri.parse("${ApiConfig.baseUrl}${ApiConfig.apiPrefix}/admin/categories");
    final res = await http.get(uri, headers: _headers(token: await _getToken()));

    if (res.statusCode != 200) {
      throw Exception("Không load được danh mục");
    }

    final decoded = jsonDecode(res.body);
    if (decoded is List) {
      return decoded.map((e) => Category.fromJson(Map<String, dynamic>.from(e))).toList();
    }
    throw Exception("Response categories không đúng format");
  }

  Future<List<Map<String, dynamic>>> fetchGroupsForMe() async {
    final user = await _getUser();
    final userId = user?["_id"]?.toString();
    if (userId == null || userId.isEmpty) return [];

    final uri = Uri.parse("${ApiConfig.baseUrl}${ApiConfig.apiPrefix}/group/groups?userId=$userId");
    final res = await http.get(uri, headers: _headers(token: await _getToken()));
    if (res.statusCode != 200) return [];

    final decoded = jsonDecode(res.body);
    final groups = (decoded["groups"] ?? []) as List<dynamic>;
    return groups.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<int> fetchGroupActualBalance(String groupId) async {
    final uri = Uri.parse("${ApiConfig.baseUrl}${ApiConfig.apiPrefix}/group/groups/$groupId/actual-balance");
    final res = await http.get(uri, headers: _headers(token: await _getToken()));
    if (res.statusCode != 200) return 0;

    final decoded = jsonDecode(res.body);
    return (decoded["balance"] ?? 0) is int ? decoded["balance"] as int : (decoded["balance"] as num).toInt();
  }

  /// Auto pick fund "chung/general" (giống React)
  Future<Map<String, String>?> pickCategorizationFund(String groupId) async {
    final uri = Uri.parse("${ApiConfig.baseUrl}${ApiConfig.apiPrefix}/group/group-funds?groupId=$groupId");
    final res = await http.get(uri, headers: _headers(token: await _getToken()));
    if (res.statusCode != 200) return null;

    final decoded = jsonDecode(res.body);
    final funds = (decoded["funds"] ?? []) as List<dynamic>;
    if (funds.isEmpty) return null;

    Map<String, dynamic>? target = funds
        .map((e) => Map<String, dynamic>.from(e))
        .cast<Map<String, dynamic>>()
        .firstWhere(
          (f) =>
      (f["name"]?.toString().toLowerCase().contains("chung") ?? false) ||
          (f["name"]?.toString().toLowerCase().contains("general") ?? false),
      orElse: () => Map<String, dynamic>.from(funds.first),
    );

    final id = target["_id"]?.toString();
    final name = target["name"]?.toString();
    if (id == null || name == null) return null;

    return {"id": id, "name": name};
  }

  Future<bool> withdrawPersonal({
    required int amount,
    required String categoryId,
    required String categoryName,
    required String note,
    required String dateYmd,
  }) async {
    final user = await _getUser();
    final userId = user?["_id"]?.toString();
    if (userId == null || userId.isEmpty) throw Exception("Không tìm thấy userId");

    final uri = Uri.parse("${ApiConfig.baseUrl}${ApiConfig.apiPrefix}/withdraw");
    final body = jsonEncode({
      "user_id": userId,
      "amount": amount,
      "category_id": categoryId,
      "source": categoryName,
      "note": note,
      "transaction_date": dateYmd,
      "payment_method": "personalFund",
    });

    final res = await http.post(uri, headers: _headers(token: await _getToken()), body: body);
    if (res.statusCode >= 200 && res.statusCode < 300) return true;

    final msg = _extractErr(res.body);
    throw Exception(msg);
  }

  Future<bool> createGroupExpense({
    required String fundId,
    required String groupId,
    required int amount,
    required String categoryId,
    required String description,
    required String dateYmd,
  }) async {
    final user = await _getUser();
    final userId = user?["_id"]?.toString();
    if (userId == null || userId.isEmpty) throw Exception("Không tìm thấy userId");

    final uri = Uri.parse("${ApiConfig.baseUrl}${ApiConfig.apiPrefix}/group/group-expenses");
    final body = jsonEncode({
      "fund_id": fundId,
      "user_making_expense_id": userId,
      "date": dateYmd,
      "description": description,
      "category_id": categoryId,
      "amount": amount,
    });

    final res = await http.post(uri, headers: _headers(token: await _getToken()), body: body);
    if (res.statusCode >= 200 && res.statusCode < 300) return true;

    final msg = _extractErr(res.body);
    throw Exception(msg);
  }

  String _extractErr(String body) {
    try {
      final decoded = jsonDecode(body);
      return (decoded["error"] ?? decoded["message"] ?? "Lỗi không xác định").toString();
    } catch (_) {
      return "Lỗi không xác định";
    }
  }
}
