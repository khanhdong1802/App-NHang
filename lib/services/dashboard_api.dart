import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';
import '../models/category.dart';
import '../models/transaction_item.dart';

class DashboardApi {
  final _storage = const FlutterSecureStorage();

  Future<Map<String, dynamic>?> _getUser() async {
    final raw = await _storage.read(key: "user");
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<String?> getUserId() async {
    final u = await _getUser();
    return u?["_id"]?.toString();
  }

  Future<String?> getUserName() async {
    final u = await _getUser();
    return u?["name"]?.toString();
  }

  Future<String?> getAvatarUrl() async {
    final u = await _getUser();
    return u?["avatar"]?.toString();
  }

  // ----------------- HEADER DATA -----------------

  Future<num> fetchBalance(String userId) async {
    final uri = Uri.parse(
        "${ApiConfig.baseUrl}${ApiConfig.apiPrefix}/auth/balance/$userId");
    final res = await http.get(uri);
    if (res.statusCode != 200) return 0;
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return (data["balance"] ?? 0) as num;
  }

  Future<num> fetchTotalSpent(String userId) async {
    final uri = Uri.parse("${ApiConfig.baseUrl}${ApiConfig
        .apiPrefix}/auth/expenses/personal/total/$userId");
    final res = await http.get(uri);
    if (res.statusCode != 200) return 0;
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return (data["total"] ?? 0) as num;
  }

  /// Gọi endpoint /summary để lấy hạn mức tổng (category = null) hiện tại.
  /// Trả về đầy đủ dữ liệu để hiển thị và pre-fill modal chỉnh sửa.
  /// Nếu chưa thiết lập hoặc hết hạn → trả về map với amount = 0.
  Future<Map<String, dynamic>> fetchSpendingLimitData(String userId) async {
    final uri = Uri.parse("${ApiConfig.baseUrl}${ApiConfig
        .apiPrefix}/spending-limit/spending-limits/$userId/summary");
    try {
      final res = await http.get(uri);
      if (res.statusCode != 200) return _emptyLimit();
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['success'] != true) return _emptyLimit();
      final list = (body['data'] ?? []) as List<dynamic>;
      if (list.isEmpty) return _emptyLimit();
      // Ưu tiên hạn mức tổng (category = null), fallback về hạn mức đầu tiên
      final raw = list.firstWhere(
        (l) => l['category'] == null,
        orElse: () => list.first,
      ) as Map<String, dynamic>;
      return {
        'amount':        (raw['amount']        ?? 0)    as num,
        'spent':         (raw['spent']         ?? 0)    as num,
        'remaining':     (raw['remaining']     ?? 0)    as num,
        'percent':       (raw['percent']       ?? 0)    as num,
        'status':        (raw['status']        ?? '')   as String,
        'message':       (raw['message']       ?? '')   as String,
        'note':          (raw['note']          ?? '')   as String,
        'months':        (raw['months']        ?? 1)    as num,
        'alert_percent': (raw['alert_percent'] ?? 80)   as num,
        'start_date':    raw['start_date'],
        'end_date':      raw['end_date'],
        'limit_id':      raw['limit_id'],
      };
    } catch (_) {
      return _emptyLimit();
    }
  }

  Map<String, dynamic> _emptyLimit() => {
    'amount': 0, 'spent': 0, 'remaining': 0, 'percent': 0,
    'status': '', 'message': '', 'note': '', 'months': 1,
    'alert_percent': 80, 'start_date': null, 'end_date': null, 'limit_id': null,
  };

  Future<List<Map<String, dynamic>>> fetchRooms(String userId) async {
    final uri = Uri.parse("${ApiConfig.baseUrl}${ApiConfig
        .apiPrefix}/group/groups?userId=$userId");
    final res = await http.get(uri);
    if (res.statusCode != 200) return [];
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final groups = (data["groups"] ?? []) as List<dynamic>;
    return groups.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<List<Map<String, dynamic>>> fetchNotifications(String userId) async {
    final uri = Uri.parse("${ApiConfig.baseUrl}${ApiConfig
        .apiPrefix}/group/notifications?userId=$userId");
    final res = await http.get(uri);
    if (res.statusCode != 200) return [];
    final data = jsonDecode(res.body);
    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }

  Future<bool> acceptInvite(String notiId, String userId) async {
    final uri = Uri.parse("${ApiConfig.baseUrl}${ApiConfig
        .apiPrefix}/group/invitations/$notiId/accept");
    final res = await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"userId": userId}),
    );
    return res.statusCode == 200;
  }

  Future<bool> rejectInvite(String notiId) async {
    final uri = Uri.parse("${ApiConfig.baseUrl}${ApiConfig
        .apiPrefix}/group/notifications/$notiId/reject");
    final res = await http.post(uri);
    return res.statusCode == 200;
  }

  // ----------------- DASHBOARD DATA (MODEL) -----------------

  /// GET /admin/categories  -> List<Category>
  Future<List<Category>> fetchCategories() async {
    final uri = Uri.parse(
        "${ApiConfig.baseUrl}${ApiConfig.apiPrefix}/admin/categories");
    final res = await http.get(uri);

    if (res.statusCode != 200) {
      throw Exception("Không load được danh mục");
    }

    final decoded = jsonDecode(res.body);

    // API trả mảng trực tiếp: [ {...}, {...} ]
    if (decoded is List) {
      return decoded
          .map((e) => Category.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    // Nếu BE trả kiểu { categories: [...] } thì mở dòng dưới:
    // final list = (decoded["categories"] ?? []) as List<dynamic>;
    // return list.map((e) => Category.fromJson(Map<String, dynamic>.from(e))).toList();

    throw Exception("Response categories không đúng format");
  }

  Future<List<TransactionItem>> fetchTransactionsByDate({
    required String date,
    required Future<String?> Function() tokenProvider,
  }) async {
    final userId = await getUserId();
    if (userId == null || userId.isEmpty) return [];

    final token = await tokenProvider();

    final uri = Uri.parse(
      "${ApiConfig.baseUrl}${ApiConfig.apiPrefix}/transactions/user/$userId",
    ).replace(queryParameters: {
      "date": date,
    });

    final res = await http.get(uri, headers: {
      "Accept": "application/json",
      "Content-Type": "application/json",
      if (token != null && token.isNotEmpty) "Authorization": "Bearer $token",
    });

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
          "Không lấy được lịch sử giao dịch (HTTP ${res.statusCode})");
    }

    final data = jsonDecode(res.body);
    if (data is List) {
      return data
          .map((e) => TransactionItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }

  Future<List<TransactionItem>> fetchTransactionsByRange({
    required String from,
    required String to,
    required Future<String?> Function() tokenProvider,
  }) async {
    final userId = await getUserId();
    if (userId == null || userId.isEmpty) return [];

    final token = await tokenProvider();

    final uri = Uri.parse(
      "${ApiConfig.baseUrl}${ApiConfig.apiPrefix}/transactions/user/$userId",
    ).replace(queryParameters: {
      "from": from,
      "to": to,
    });

    final res = await http.get(uri, headers: {
      "Accept": "application/json",
      "Content-Type": "application/json",
      if (token != null && token.isNotEmpty) "Authorization": "Bearer $token",
    });

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
          "Không lấy được lịch sử giao dịch (HTTP ${res.statusCode})");
    }

    final data = jsonDecode(res.body);
    if (data is List) {
      return data
          .map((e) => TransactionItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }

  Future<List<TransactionItem>> fetchTransactionsByMonth({
    required int month,
    required int year,
    required Future<String?> Function() tokenProvider,
  }) async {
    final userId = await getUserId();
    if (userId == null || userId.isEmpty) return [];

    final token = await tokenProvider();

    final uri = Uri.parse(
      "${ApiConfig.baseUrl}${ApiConfig.apiPrefix}/transactions/user/$userId",
    ).replace(queryParameters: {
      "month": "$month",
      "year": "$year",
    });

    final res = await http.get(uri, headers: {
      "Accept": "application/json",
      "Content-Type": "application/json",
      if (token != null && token.isNotEmpty) "Authorization": "Bearer $token",
    });

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
          "Không lấy được lịch sử giao dịch (HTTP ${res.statusCode})");
    }

    final data = jsonDecode(res.body);
    if (data is List) {
      return data
          .map((e) => TransactionItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }

  Future<List<TransactionItem>> fetchTransactionsByYear({
    required int year,
    required Future<String?> Function() tokenProvider,
  }) async {
    final userId = await getUserId();
    if (userId == null || userId.isEmpty) return [];

    final token = await tokenProvider();

    final uri = Uri.parse(
      "${ApiConfig.baseUrl}${ApiConfig.apiPrefix}/transactions/user/$userId",
    ).replace(queryParameters: {
      "year": "$year",
    });

    final res = await http.get(uri, headers: {
      "Accept": "application/json",
      "Content-Type": "application/json",
      if (token != null && token.isNotEmpty) "Authorization": "Bearer $token",
    });

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
          "Không lấy được lịch sử giao dịch (HTTP ${res.statusCode})");
    }

    final data = jsonDecode(res.body);
    if (data is List) {
      return data
          .map((e) => TransactionItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }

  Future<List<TransactionItem>> fetchTransactionsByUserId(String userId, {
    required Future<String?> Function() tokenProvider,
  }) async {
    final token = await tokenProvider();

    final uri = Uri.parse(
      "${ApiConfig.baseUrl}${ApiConfig.apiPrefix}/transactions/user/$userId",
    );

    final res = await http.get(uri, headers: {
      "Accept": "application/json",
      "Content-Type": "application/json",
      if (token != null && token.isNotEmpty) "Authorization": "Bearer $token",
    });

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception("Không lấy được transactions (HTTP ${res.statusCode})");
    }

    final data = jsonDecode(res.body);
    if (data is List) {
      return data
          .map((e) => TransactionItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }

  Future<List<TransactionItem>> fetchTransactionsForCurrentUser({
    required Future<String?> Function() tokenProvider,
  }) async {
    final userId = await getUserId();
    if (userId == null || userId.isEmpty) return [];

    final token = await tokenProvider();

    final uri = Uri.parse(
      "${ApiConfig.baseUrl}${ApiConfig.apiPrefix}/transactions/user/$userId",
    );

    final res = await http.get(uri, headers: {
      "Accept": "application/json",
      "Content-Type": "application/json",
      if (token != null && token.isNotEmpty) "Authorization": "Bearer $token",
    });

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
          "Không lấy được lịch sử giao dịch (HTTP ${res.statusCode})");
    }

    final decoded = jsonDecode(res.body);

    if (decoded is List) {
      return decoded
          .map((e) => TransactionItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    throw Exception("Response transactions không đúng format");
  }

  Future<List<TransactionItem>> fetchGroupTransactionsByDate({
    required String groupId,
    required String date,
    required Future<String?> Function() tokenProvider,
  }) async {
    final token = await tokenProvider();

    final uri = Uri.parse(
      "${ApiConfig.baseUrl}${ApiConfig.apiPrefix}/transactions/group/$groupId",
    ).replace(queryParameters: {
      "date": date,
    });

    final res = await http.get(uri, headers: {
      "Accept": "application/json",
      "Content-Type": "application/json",
      if (token != null && token.isNotEmpty) "Authorization": "Bearer $token",
    });

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        "Không lấy được lịch sử giao dịch nhóm (HTTP ${res.statusCode})",
      );
    }

    final data = jsonDecode(res.body);
    if (data is List) {
      return data
          .map((e) => TransactionItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }

  Future<List<TransactionItem>> fetchGroupTransactionsByRange({
    required String groupId,
    required String from,
    required String to,
    required Future<String?> Function() tokenProvider,
  }) async {
    final token = await tokenProvider();

    final uri = Uri.parse(
      "${ApiConfig.baseUrl}${ApiConfig.apiPrefix}/transactions/group/$groupId",
    ).replace(queryParameters: {
      "from": from,
      "to": to,
    });

    final res = await http.get(uri, headers: {
      "Accept": "application/json",
      "Content-Type": "application/json",
      if (token != null && token.isNotEmpty) "Authorization": "Bearer $token",
    });

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        "Không lấy được lịch sử giao dịch nhóm (HTTP ${res.statusCode})",
      );
    }

    final data = jsonDecode(res.body);
    if (data is List) {
      return data
          .map((e) => TransactionItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }

  Future<List<TransactionItem>> fetchGroupTransactionsByMonth({
    required String groupId,
    required int month,
    required int year,
    required Future<String?> Function() tokenProvider,
  }) async {
    final token = await tokenProvider();

    final uri = Uri.parse(
      "${ApiConfig.baseUrl}${ApiConfig.apiPrefix}/transactions/group/$groupId",
    ).replace(queryParameters: {
      "month": "$month",
      "year": "$year",
    });

    final res = await http.get(uri, headers: {
      "Accept": "application/json",
      "Content-Type": "application/json",
      if (token != null && token.isNotEmpty) "Authorization": "Bearer $token",
    });

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        "Không lấy được lịch sử giao dịch nhóm (HTTP ${res.statusCode})",
      );
    }

    final data = jsonDecode(res.body);
    if (data is List) {
      return data
          .map((e) => TransactionItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }

  Future<List<TransactionItem>> fetchGroupTransactionsByYear({
    required String groupId,
    required int year,
    required Future<String?> Function() tokenProvider,
  }) async {
    final token = await tokenProvider();

    final uri = Uri.parse(
      "${ApiConfig.baseUrl}${ApiConfig.apiPrefix}/transactions/group/$groupId",
    ).replace(queryParameters: {
      "year": "$year",
    });

    final res = await http.get(uri, headers: {
      "Accept": "application/json",
      "Content-Type": "application/json",
      if (token != null && token.isNotEmpty) "Authorization": "Bearer $token",
    });

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        "Không lấy được lịch sử giao dịch nhóm (HTTP ${res.statusCode})",
      );
    }

    final data = jsonDecode(res.body);
    if (data is List) {
      return data
          .map((e) => TransactionItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }



}