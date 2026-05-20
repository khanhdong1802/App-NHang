import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../models/category.dart';

class CategoryApi {
  static String get baseUrl {
    if (kIsWeb) {
      return "http://localhost:3000/api/admin/categories";
    }

    return "http://10.0.2.2:3000/api/admin/categories";
  }

  Map<String, String> get _headers {
    return {
      "Content-Type": "application/json",
    };
  }

  Future<List<Category>> fetchCategories() async {
    final res = await http
        .get(
      Uri.parse(baseUrl),
      headers: _headers,
    )
        .timeout(const Duration(seconds: 15));

    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => Category.fromJson(e)).toList();
    }

    final body = _decodeBody(res.body);
    throw Exception(body["message"] ?? "Không thể tải danh mục");
  }

  Future<Category> createCategory(Category category) async {
    final res = await http
        .post(
      Uri.parse(baseUrl),
      headers: _headers,
      body: jsonEncode(category.toJson()),
    )
        .timeout(const Duration(seconds: 15));

    if (res.statusCode == 201) {
      return Category.fromJson(jsonDecode(res.body));
    }

    final body = _decodeBody(res.body);
    throw Exception(body["message"] ?? "Không thể thêm danh mục");
  }

  Future<Category> updateCategory(Category category) async {
    final res = await http
        .put(
      Uri.parse("$baseUrl/${category.id}"),
      headers: _headers,
      body: jsonEncode(category.toJson()),
    )
        .timeout(const Duration(seconds: 15));

    if (res.statusCode == 200) {
      return Category.fromJson(jsonDecode(res.body));
    }

    final body = _decodeBody(res.body);
    throw Exception(body["message"] ?? "Không thể cập nhật danh mục");
  }

  Future<void> deleteCategory(String id) async {
    final res = await http
        .delete(
      Uri.parse("$baseUrl/$id"),
      headers: _headers,
    )
        .timeout(const Duration(seconds: 15));

    if (res.statusCode == 200) {
      return;
    }

    final body = _decodeBody(res.body);
    throw Exception(body["message"] ?? "Không thể xóa danh mục");
  }

  Map<String, dynamic> _decodeBody(String body) {
    try {
      if (body.isEmpty) return {};
      final decoded = jsonDecode(body);

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      return {};
    } catch (_) {
      return {};
    }
  }
}