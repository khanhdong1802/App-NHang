import 'dart:convert';
import 'package:http/http.dart' as http;

import 'api_config.dart';
import '../models/category.dart';
import '../screens/dashboard/modals/group_transaction.dart';
import '../services/auth_service.dart';
class GroupApi {
  final Future<String?> Function()? tokenProvider;
  final AuthService _auth = AuthService();
  GroupApi({this.tokenProvider});

  Future<Map<String, String>> _headers() async {
    final h = <String, String>{
      "Accept": "application/json",
      "Content-Type": "application/json",
    };
    final token = await tokenProvider?.call();
    if (token != null && token.isNotEmpty) {
      h["Authorization"] = "Bearer $token";
    }
    return h;
  }

  // =========================
  // 1) CREATE ROOM (INVITE)
  // =========================

  /// GET /api/group/search?q=...
  Future<List<dynamic>> searchUsers(String q) async {
    final uri = Uri.parse(
      "${ApiConfig.baseUrl}${ApiConfig.apiPrefix}/group/search?q=${Uri.encodeQueryComponent(q)}",
    );

    final res = await http.get(uri, headers: await _headers());
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception("Search failed: HTTP ${res.statusCode}");
    }

    final data = jsonDecode(res.body);
    if (data is List) return data;
    return [];
  }

  /// POST /api/group/invitations
  /// body: { name, description:"", created_by, memberEmail }
  Future<Map<String, dynamic>> createInvitation({
    required String name,
    required String createdBy,
    String? memberEmail,
  }) async {
    final uri = Uri.parse(
      "${ApiConfig.baseUrl}${ApiConfig.apiPrefix}/group/invitations",
    );

    final body = <String, dynamic>{
      "name": name,
      "description": "",
      "created_by": createdBy,
      if (memberEmail != null && memberEmail.trim().isNotEmpty)
        "memberEmail": memberEmail.trim(),
    };

    final res = await http.post(uri, headers: await _headers(), body: jsonEncode(body));
    final data = jsonDecode(res.body);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      final msg = (data is Map && data["message"] != null)
          ? data["message"].toString()
          : "Tạo phòng thất bại";
      throw Exception(msg);
    }

    if (data is Map<String, dynamic>) return data;
    return {"success": true};
  }

  // =========================
  // 2) GROUP ROOM DASHBOARD
  // =========================

  /// GET /api/group/:groupId
  Future<Map<String, dynamic>> fetchGroupInfo(String groupId) async {
    final uri = Uri.parse("${ApiConfig.baseUrl}${ApiConfig.apiPrefix}/group/$groupId");
    final res = await http.get(uri, headers: await _headers());

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception("Lấy thông tin nhóm thất bại (HTTP ${res.statusCode})");
    }

    final data = jsonDecode(res.body);
    if (data is Map<String, dynamic>) return data;
    throw Exception("Response không hợp lệ");
  }

  /// GET /api/group/groups/:groupId/actual-balance
  Future<Map<String, dynamic>> fetchActualBalance(String groupId) async {
    final uri = Uri.parse(
      "${ApiConfig.baseUrl}${ApiConfig.apiPrefix}/group/groups/$groupId/actual-balance",
    );
    final res = await http.get(uri, headers: await _headers());

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception("Lấy số dư nhóm thất bại (HTTP ${res.statusCode})");
    }

    final data = jsonDecode(res.body);
    if (data is Map<String, dynamic>) return data;
    throw Exception("Response không hợp lệ");
  }

  /// GET /api/admin/categories
  Future<List<Category>> fetchCategories() async {
    final uri = Uri.parse("${ApiConfig.baseUrl}${ApiConfig.apiPrefix}/admin/categories");
    final res = await http.get(uri, headers: await _headers());

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception("Lấy danh mục thất bại (HTTP ${res.statusCode})");
    }

    final data = jsonDecode(res.body);
    if (data is List) {
      return data.map((e) => Category.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  /// GET /api/transactions/group/:groupId
  Future<List<GroupTransaction>> fetchGroupTransactions(String groupId) async {
    final uri = Uri.parse("${ApiConfig.baseUrl}${ApiConfig.apiPrefix}/transactions/group/$groupId");
    final res = await http.get(uri, headers: await _headers());

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception("Không lấy được lịch sử giao dịch nhóm (HTTP ${res.statusCode})");
    }

    final data = jsonDecode(res.body);
    if (data is List) {
      return data.map((e) => GroupTransaction.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }
  // =========================
  // 3) GROUP MEMBERS
  // =========================

  /// GET /api/group/groups/:groupId/member-expenses
  /// Expect: { members: [ { user_id, name, email, totalSpent } ] }
  Future<Map<String, dynamic>> fetchMemberExpenses(String groupId) async {
    final uri = Uri.parse(
      "${ApiConfig.baseUrl}${ApiConfig.apiPrefix}/group/groups/$groupId/member-expenses",
    );

    final res = await http.get(uri, headers: await _headers());

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception("Không lấy được thành viên nhóm (HTTP ${res.statusCode})");
    }

    final data = jsonDecode(res.body);
    if (data is Map<String, dynamic>) return data;

    // fallback an toàn
    return {"members": []};
  }

  /// POST /api/group/groups/:groupId/members
  /// body: { email }
  Future<Map<String, dynamic>> addMemberByEmail(String groupId, String email) async {
    final uri = Uri.parse(
      "${ApiConfig.baseUrl}${ApiConfig.apiPrefix}/group/groups/$groupId/members",
    );

    final res = await http.post(
      uri,
      headers: await _headers(),
      body: jsonEncode({"email": email.trim()}),
    );

    dynamic data;
    try {
      data = jsonDecode(res.body);
    } catch (_) {
      data = null;
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      final msg = (data is Map && data["message"] != null)
          ? data["message"].toString()
          : "Thêm thành viên thất bại";
      throw Exception(msg);
    }

    if (data is Map<String, dynamic>) return data;
    return {"success": true};
  }
  // =========================
  // 4) DELETE MEMBER / DELETE GROUP
  // =========================

  /// DELETE /api/group/groups/:groupId/members/:memberId
  Future<Map<String, dynamic>> removeMember(String groupId, String memberId) async {
    final uri = Uri.parse(
      "${ApiConfig.baseUrl}${ApiConfig.apiPrefix}/group/groups/$groupId/members/$memberId",
    );

    final res = await http.delete(uri, headers: await _headers());

    dynamic data;
    try {
      data = jsonDecode(res.body);
    } catch (_) {
      data = null;
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      final msg = (data is Map && data["message"] != null)
          ? data["message"].toString()
          : "Không thể xóa thành viên";
      throw Exception(msg);
    }

    if (data is Map<String, dynamic>) return data;
    return {"success": true};
  }

  /// DELETE /api/group/groups/:groupId
  Future<Map<String, dynamic>> deleteGroup(String groupId) async {
    final uri = Uri.parse(
      "${ApiConfig.baseUrl}${ApiConfig.apiPrefix}/group/groups/$groupId",
    );

    final res = await http.delete(uri, headers: await _headers());

    dynamic data;
    try {
      data = jsonDecode(res.body);
    } catch (_) {
      data = null;
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      final msg = (data is Map && data["message"] != null)
          ? data["message"].toString()
          : "Không thể xóa nhóm";
      throw Exception(msg);
    }

    if (data is Map<String, dynamic>) return data;
    return {"success": true};
  }

  Future<List<GroupTransaction>> fetchGroupTransactionsByDate({
    required String groupId,
    required String date,
  }) async {
    final uri = Uri.parse(
      "${ApiConfig.baseUrl}${ApiConfig.apiPrefix}/transactions/group/$groupId",
    ).replace(queryParameters: {
      "date": date,
    });

    final res = await http.get(uri, headers: await _headers());

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        "Không lấy được lịch sử giao dịch nhóm (HTTP ${res.statusCode})",
      );
    }

    final data = jsonDecode(res.body);
    if (data is List) {
      return data
          .map((e) => GroupTransaction.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }

  Future<List<GroupTransaction>> fetchGroupTransactionsByRange({
    required String groupId,
    required String from,
    required String to,
  }) async {
    final uri = Uri.parse(
      "${ApiConfig.baseUrl}${ApiConfig.apiPrefix}/transactions/group/$groupId",
    ).replace(queryParameters: {
      "from": from,
      "to": to,
    });

    final res = await http.get(uri, headers: await _headers());

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        "Không lấy được lịch sử giao dịch nhóm (HTTP ${res.statusCode})",
      );
    }

    final data = jsonDecode(res.body);
    if (data is List) {
      return data
          .map((e) => GroupTransaction.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }

  Future<List<GroupTransaction>> fetchGroupTransactionsByMonth({
    required String groupId,
    required int month,
    required int year,
  }) async {
    final uri = Uri.parse(
      "${ApiConfig.baseUrl}${ApiConfig.apiPrefix}/transactions/group/$groupId",
    ).replace(queryParameters: {
      "month": "$month",
      "year": "$year",
    });

    final res = await http.get(uri, headers: await _headers());

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        "Không lấy được lịch sử giao dịch nhóm (HTTP ${res.statusCode})",
      );
    }

    final data = jsonDecode(res.body);
    if (data is List) {
      return data
          .map((e) => GroupTransaction.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }

  Future<List<GroupTransaction>> fetchGroupTransactionsByYear({
    required String groupId,
    required int year,
  }) async {
    final uri = Uri.parse(
      "${ApiConfig.baseUrl}${ApiConfig.apiPrefix}/transactions/group/$groupId",
    ).replace(queryParameters: {
      "year": "$year",
    });

    final res = await http.get(uri, headers: await _headers());

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        "Không lấy được lịch sử giao dịch nhóm (HTTP ${res.statusCode})",
      );
    }

    final data = jsonDecode(res.body);
    if (data is List) {
      return data
          .map((e) => GroupTransaction.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }


}
