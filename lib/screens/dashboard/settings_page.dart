import 'dart:convert';
import 'dart:typed_data';

import 'package:doanmonhoc/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:http_parser/http_parser.dart';

import '../../services/api_config.dart';

class SettingsPage extends StatefulWidget {
  final Future<String?> Function() tokenProvider;
  final Map<String, dynamic> user;

  const SettingsPage({
    super.key,
    required this.tokenProvider,
    required this.user,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _nameCtl = TextEditingController();
  final _emailCtl = TextEditingController();
  final _phoneCtl = TextEditingController();
  final _passCtl = TextEditingController();
  final _confirmCtl = TextEditingController();

  final auth = AuthService();

  String message = "";
  bool loading = false;

  // avatar-related
  String _avatarPreviewUrl = "";
  Uint8List? _avatarBytes;
  String _avatarFilename = "avatar.png";
  String? _avatarMimeType;

  @override
  void initState() {
    super.initState();
    _nameCtl.text = (widget.user["name"] ?? "").toString();
    _emailCtl.text = (widget.user["email"] ?? "").toString();
    _phoneCtl.text = (widget.user["phone"] ?? "").toString();

    final avatar = (widget.user["avatar"] ?? "").toString();
    if (avatar.isNotEmpty) {
      _avatarPreviewUrl =
      avatar.startsWith("http") ? avatar : "${ApiConfig.baseUrl}$avatar";
    }

    _nameCtl.addListener(() => setState(() {}));
    _emailCtl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _emailCtl.dispose();
    _phoneCtl.dispose();
    _passCtl.dispose();
    _confirmCtl.dispose();
    super.dispose();
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: const Color(0xFFF3F4F6),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide.none,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  );

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(t, style: const TextStyle(fontWeight: FontWeight.w700)),
  );

  Future<void> _pickAvatar() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x == null) return;

    final bytes = await x.readAsBytes();
    if (bytes.lengthInBytes > 2 * 1024 * 1024) {
      setState(() => message = "Ảnh quá lớn (tối đa 2MB).");
      return;
    }

    setState(() {
      _avatarBytes = bytes;
      _avatarFilename = (x.name.isNotEmpty) ? x.name : "avatar.jpg";
      _avatarMimeType = x.mimeType;
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => message = "");

    final name = _nameCtl.text.trim();
    final email = _emailCtl.text.trim();
    final phone = _phoneCtl.text.trim();
    final pass = _passCtl.text;
    final confirm = _confirmCtl.text;

    if (name.isEmpty) {
      setState(() => message = "Vui lòng nhập tên hiển thị.");
      return;
    }
    if (email.isEmpty) {
      setState(() => message = "Vui lòng nhập email.");
      return;
    }
    if (pass.isNotEmpty && pass != confirm) {
      setState(() => message = "Mật khẩu mới và xác nhận mật khẩu không khớp!");
      return;
    }

    final userId = (widget.user["_id"] ?? "").toString();
    if (userId.isEmpty) {
      setState(() => message = "Không tìm thấy thông tin người dùng.");
      return;
    }

    final token = await widget.tokenProvider();
    if (token == null || token.isEmpty) {
      setState(() => message = "Bạn chưa đăng nhập (thiếu token).");
      return;
    }

    setState(() => loading = true);

    try {
      final uri = Uri.parse(
        "${ApiConfig.baseUrl}${ApiConfig.apiPrefix}/auth/update/$userId",
      );

      final req = http.MultipartRequest("PUT", uri);
      req.headers["Authorization"] = "Bearer $token";
      req.headers["Accept"] = "application/json";

      req.fields["name"] = name;
      req.fields["email"] = email;
      req.fields["phone"] = phone;

      if (pass.isNotEmpty) req.fields["password"] = pass;

      if (_avatarBytes != null) {
        req.files.add(http.MultipartFile.fromBytes(
          "avatar",
          _avatarBytes!,
          filename: _avatarFilename,
          contentType: _avatarMimeType != null ? MediaType.parse(_avatarMimeType!) : null,
        ));
      }

      final streamed = await req.send();
      final res = await http.Response.fromStream(streamed);

      dynamic data;
      try {
        data = jsonDecode(res.body);
      } catch (_) {
        data = null;
      }

      if (res.statusCode < 200 || res.statusCode >= 300) {
        final msg = (data is Map && data["message"] != null)
            ? data["message"].toString()
            : "Cập nhật thất bại (HTTP ${res.statusCode})";
        throw Exception(msg);
      }

      if (data is Map && data["user"] is Map) {
        final newUser = data["user"] as Map<String, dynamic>;
        await auth.updateUserInStorage(newUser);

        final newAvatar = (newUser["avatar"] ?? "").toString();
        if (newAvatar.isNotEmpty) {
          _avatarPreviewUrl = newAvatar.startsWith("http")
              ? newAvatar
              : "${ApiConfig.baseUrl}$newAvatar";
        }
      }

      setState(() {
        _passCtl.clear();
        _confirmCtl.clear();
        _avatarBytes = null;
        _avatarFilename = "avatar.png";
        _avatarMimeType = null;
        message = "✅ Cập nhật thành công!";
      });
    } catch (e) {
      setState(() => message = e.toString().replaceFirst("Exception:", "").trim());
    } finally {
      setState(() => loading = false);
    }
  }

  Widget _buildAvatar() {
    if (_avatarBytes != null) {
      return Image.memory(_avatarBytes!, fit: BoxFit.cover);
    }

    if (_avatarPreviewUrl.isNotEmpty) {
      return Image.network(
        _avatarPreviewUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
        const Center(child: Text("avatar")),
      );
    }

    return const Center(child: Text("avatar"));
  }


  @override
  Widget build(BuildContext context) {
    final name = _nameCtl.text.trim().isEmpty ? "Người dùng" : _nameCtl.text.trim();
    final email = _emailCtl.text.trim().isEmpty ? "email" : _emailCtl.text.trim();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 18),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF6D5EF9), Color(0xFF9B5CF6), Color(0xFF22C1C3)],
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                      ),
                      const Expanded(
                        child: Column(
                          children: [
                            Text("Tài khoản",
                                style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w800, fontSize: 11)),
                            SizedBox(height: 2),
                            Text("Hồ sơ cá nhân",
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 44),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _pickAvatar,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: Colors.white.withOpacity(0.25)),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: _buildAvatar(),
                            ),
                            Positioned(
                              right: -6,
                              bottom: -6,
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: const [
                                    BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
                                  ],
                                ),
                                child: const Icon(Icons.camera_alt_rounded, size: 18, color: Colors.black87),
                              ),
                            )
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                            const SizedBox(height: 2),
                            Text(email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w800, fontSize: 12)),
                            const SizedBox(height: 6),
                            const Text("Nhấn avatar để thay ảnh (tối đa 2MB)",
                                style: TextStyle(color: Colors.white60, fontWeight: FontWeight.w700, fontSize: 11)),
                          ],
                        ),
                      )
                    ],
                  ),
                ],
              ),
            ),
            Container(
              height: 18,
              decoration: const BoxDecoration(
                color: Color(0xFFF6F7FB),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: Colors.black.withOpacity(0.05)),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 6))
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Cập nhật thông tin", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      const Text("Thay đổi thông tin cá nhân và bảo mật tài khoản.",
                          style: TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 16),

                      _label("Tên hiển thị"),
                      TextField(controller: _nameCtl, decoration: _inputDeco("Tên hiển thị"), onChanged: (_) => setState(() {})),
                      const SizedBox(height: 12),

                      _label("Email"),
                      TextField(
                        controller: _emailCtl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: _inputDeco("Email"),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),

                      _label("Số điện thoại (tuỳ chọn)"),
                      TextField(
                        controller: _phoneCtl,
                        keyboardType: TextInputType.phone,
                        decoration: _inputDeco("VD: 09xxxxxxxx"),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _label("Mật khẩu mới"),
                                TextField(
                                  controller: _passCtl,
                                  obscureText: true,
                                  decoration: _inputDeco("Để trống nếu không đổi"),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _label("Xác nhận mật khẩu"),
                                TextField(
                                  controller: _confirmCtl,
                                  obscureText: true,
                                  decoration: _inputDeco("Nhập lại mật khẩu mới"),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      if (message.isNotEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: message.contains("✅") ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: message.contains("✅") ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA),
                            ),
                          ),
                          child: Text(
                            message,
                            style: TextStyle(
                              color: message.contains("✅") ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),

                      const SizedBox(height: 14),

                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: loading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                            padding: EdgeInsets.zero,
                          ),
                          child: Ink(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF4F46E5), Color(0xFF9333EA), Color(0xFF06B6D4)],
                              ),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Center(
                              child: loading
                                  ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                                  : const Text("Lưu thay đổi",
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
