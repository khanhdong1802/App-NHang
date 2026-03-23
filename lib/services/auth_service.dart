import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_config.dart';
import 'package:google_sign_in/google_sign_in.dart';

class RegisterResult {
  final String message;
  final String? token;

  RegisterResult({required this.message, this.token});
}

class LoginResult {
  final String message;
  final String accessToken;
  final Map<String, dynamic> user;
  final bool isAdmin;

  LoginResult({
    required this.message,
    required this.accessToken,
    required this.user,
    required this.isAdmin,
  });
}

class AuthService extends ChangeNotifier {
  final _storage = const FlutterSecureStorage();

  String? _token;
  Map<String, dynamic>? _currentUser;
  bool _isAdmin = false;

  // ✅ getters dùng cho UI/Provider
  String? get token => _token;
  Map<String, dynamic>? get currentUser => _currentUser;
  bool get isAdmin => _isAdmin;

  // ✅ tiện lấy id
  String? get currentUserId =>
      (_currentUser?["_id"] ?? _currentUser?["id"])?.toString();

  /// ✅ Load lại session từ SecureStorage (gọi lúc app start hoặc khi cần)
  Future<void> restoreSession() async {
    final t = await _storage.read(key: "token");
    final rawUser = await _storage.read(key: "user");
    final adminRaw = await _storage.read(key: "isAdmin");

    _token = t;
    _currentUser = (rawUser != null) ? jsonDecode(rawUser) as Map<String, dynamic> : null;
    _isAdmin = adminRaw == "true";

    notifyListeners();
  }

  Future<LoginResult> login({
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse(
      "${ApiConfig.baseUrl}${ApiConfig.apiPrefix}/auth/login",
    );

    final res = await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email, "password": password}),
    );

    Map<String, dynamic> data;
    try {
      data = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception("Phản hồi không hợp lệ từ server");
    }

    if (res.statusCode != 200) {
      throw Exception((data["message"] ?? "Lỗi đăng nhập").toString());
    }

    final message = (data["message"] ?? "Đăng nhập thành công").toString();
    if (message == "Tài khoản bị khóa") {
      throw Exception(message);
    }

    final accessToken = (data["accessToken"] ?? "").toString();
    final user = (data["user"] ?? {}) as Map<String, dynamic>;
    final isAdmin = (user["email"]?.toString() == "admin@gmail.com");


    await _storage.write(key: "token", value: accessToken);
    await _storage.write(key: "user", value: jsonEncode(user));
    await _storage.write(key: "isAdmin", value: isAdmin ? "true" : "false");


    _token = accessToken;
    _currentUser = user;
    _isAdmin = isAdmin;
    notifyListeners();

    return LoginResult(
      message: message,
      accessToken: accessToken,
      user: user,
      isAdmin: isAdmin,
    );
  }

  Future<bool> getIsAdmin() async {
    final v = await _storage.read(key: "isAdmin");
    return v == "true";
  }

  Future<void> logout() async {
    await _storage.delete(key: "token");
    await _storage.delete(key: "user");
    await _storage.delete(key: "isAdmin");

    _token = null;
    _currentUser = null;
    _isAdmin = false;
    notifyListeners();
  }

  // giữ lại để các API đang dùng tokenProvider không bị gãy
  Future<String?> getToken() => _storage.read(key: "token");

  Future<Map<String, dynamic>?> getUserFromStorage() async {
    final raw = await _storage.read(key: "user");
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> updateUserInStorage(Map<String, dynamic> newUser) async {
    await _storage.write(key: "user", value: jsonEncode(newUser));

    _currentUser = newUser;
    notifyListeners();
  }

  // ---------------- Register ----------------
  Future<RegisterResult> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse(
      "${ApiConfig.baseUrl}${ApiConfig.apiPrefix}/auth/register",
    );

    final res = await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "name": name,
        "email": email,
        "password": password,
      }),
    );

    Map<String, dynamic> data;
    try {
      data = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception("Phản hồi không hợp lệ từ server");
    }

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception((data["message"] ?? "Lỗi đăng ký").toString());
    }

    final message = (data["message"] ?? "Đăng ký thành công!").toString();
    final token = (data["accessToken"] ?? data["acessToken"])?.toString();

    return RegisterResult(message: message, token: token);
  }
  // ---------------- Google Login (WEB) ----------------
  // Yêu cầu: web/index.html có meta google-signin-client_id
  Future<LoginResult> loginWithGoogleWeb() async {
    // Google sign-in for web
    final google = GoogleSignIn(scopes: const ['email', 'profile']);

    final account = await google.signIn();
    if (account == null) {
      throw Exception("Bạn đã hủy đăng nhập Google");
    }

    final auth = await account.authentication;

    // Trên web thường cần đúng client_id trong web/index.html để có idToken
    final idToken = auth.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw Exception(
        "Không lấy được idToken. Kiểm tra web/index.html đã thêm google-signin-client_id chưa",
      );
    }

    // Gọi đúng endpoint giống hệ thống của bạn:
    // ${ApiConfig.baseUrl}${ApiConfig.apiPrefix}/auth/google
    final uri = Uri.parse(
      "${ApiConfig.baseUrl}${ApiConfig.apiPrefix}/auth/google",
    );

    final res = await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"token": idToken}),
    );

    Map<String, dynamic> data;
    try {
      data = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception("Phản hồi không hợp lệ từ server");
    }

    if (res.statusCode != 200) {
      throw Exception((data["message"] ?? "Google login thất bại").toString());
    }

    final message = (data["message"] ?? "Đăng nhập Google thành công").toString();
    final accessToken = (data["accessToken"] ?? "").toString();
    final user = (data["user"] ?? {}) as Map<String, dynamic>;
    final isAdmin = (user["email"]?.toString() == "admin@gmail.com");

    if (accessToken.isEmpty) {
      throw Exception("Backend không trả accessToken");
    }

    // ✅ Lưu storage (giữ đúng style bạn đang làm)
    await _storage.write(key: "token", value: accessToken);
    await _storage.write(key: "user", value: jsonEncode(user));
    await _storage.write(key: "isAdmin", value: isAdmin ? "true" : "false");

    // ✅ Set state trong RAM
    _token = accessToken;
    _currentUser = user;
    _isAdmin = isAdmin;
    notifyListeners();

    return LoginResult(
      message: message,
      accessToken: accessToken,
      user: user,
      isAdmin: isAdmin,
    );
  }

  Future<LoginResult> loginWithGoogleIdToken(String idToken) async {
    final uri = Uri.parse("${ApiConfig.baseUrl}${ApiConfig.apiPrefix}/auth/google");

    final res = await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"token": idToken}),
    );

    Map<String, dynamic> data;
    try {
      data = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception("Phản hồi không hợp lệ từ server");
    }

    if (res.statusCode != 200) {
      throw Exception((data["message"] ?? "Google login thất bại").toString());
    }

    final message = (data["message"] ?? "Đăng nhập Google thành công").toString();
    final accessToken = (data["accessToken"] ?? "").toString();
    final user = (data["user"] ?? {}) as Map<String, dynamic>;
    final isAdmin = (user["email"]?.toString() == "admin@gmail.com");

    if (accessToken.isEmpty) throw Exception("Backend không trả accessToken");

    await _storage.write(key: "token", value: accessToken);
    await _storage.write(key: "user", value: jsonEncode(user));
    await _storage.write(key: "isAdmin", value: isAdmin ? "true" : "false");

    _token = accessToken;
    _currentUser = user;
    _isAdmin = isAdmin;
    notifyListeners();

    return LoginResult(
      message: message,
      accessToken: accessToken,
      user: user,
      isAdmin: isAdmin,
    );
  }

  Future<LoginResult> loginWithGoogleToken(String token) async {
    final uri = Uri.parse("${ApiConfig.baseUrl}${ApiConfig.apiPrefix}/auth/google");

    final res = await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"token": token}),
    );

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400) {
      throw Exception((data["message"] ?? "Google login thất bại").toString());
    }

    final message = (data["message"] ?? "Google login success").toString();
    final accessToken = (data["accessToken"] ?? "").toString();
    final user = (data["user"] ?? {}) as Map<String, dynamic>;
    final isAdmin = (user["email"]?.toString() == "admin@gmail.com");

    await _storage.write(key: "token", value: accessToken);
    await _storage.write(key: "user", value: jsonEncode(user));
    await _storage.write(key: "isAdmin", value: isAdmin ? "true" : "false");

    _token = accessToken;
    _currentUser = user;
    _isAdmin = isAdmin;
    notifyListeners();

    return LoginResult(
      message: message,
      accessToken: accessToken,
      user: user,
      isAdmin: isAdmin,
    );
  }

  Future<String?> getUserId() async {
    if (_currentUser != null) {
      return currentUserId;
    }

    await restoreSession();
    return currentUserId;
  }

}
