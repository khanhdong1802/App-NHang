import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = AuthService();
  final _formKey = GlobalKey<FormState>();

  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _showPassword = false;
  bool _isSubmitting = false;

  final GoogleSignIn _google = GoogleSignIn(
    scopes: const ['openid', 'email', 'profile'],
    clientId:
    "41306821288-t244srfpqp5dnp6d9i9skap2u4p89ccm.apps.googleusercontent.com",
  );

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  // ================= GIỮ NGUYÊN LOGIC =================
  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final result = await _auth.login(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(result.message)));

      Navigator.pushReplacementNamed(context, "/dashboard");
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
            Text(e.toString().replaceFirst("Exception: ", ""))),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handleGoogleLogin() async {
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);
    try {
      try {
        await _google.signOut();
      } catch (_) {}

      final account = await _google.signIn();
      if (account == null) throw Exception("Bạn đã hủy đăng nhập");

      final auth = await account.authentication;

      final tokenToSend =
      (auth.idToken != null && auth.idToken!.isNotEmpty)
          ? auth.idToken!
          : (auth.accessToken ?? "");

      if (tokenToSend.isEmpty)
        throw Exception("Không lấy được token");

      final result =
      await _auth.loginWithGoogleToken(tokenToSend);

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(result.message)));

      Navigator.pushReplacementNamed(context, "/dashboard");
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
            Text(e.toString().replaceFirst("Exception: ", ""))),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
  // ===================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: Stack(
        children: [
          // 🌈 HEADER GRADIENT (điểm ăn tiền)
          Container(
            height: 260,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF7C5CFF), Color(0xFF5F8BFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(40),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  // Avatar + brand
                  const CircleAvatar(
                    radius: 38,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.wallet,
                        size: 30, color: Color(0xFF7C5CFF)),
                  ),

                  const SizedBox(height: 12),

                  const Text(
                    "Finance App",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 30),

                  // 🧊 CARD LOGIN
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 20,
                        )
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          const Text(
                            "Đăng nhập",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Email
                          TextFormField(
                            controller: _emailCtrl,
                            decoration: InputDecoration(
                              hintText: "Email",
                              prefixIcon:
                              const Icon(Icons.email_outlined),
                              filled: true,
                              fillColor: const Color(0xFFF3F4F6),
                              border: OutlineInputBorder(
                                borderRadius:
                                BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            validator: (v) {
                              if ((v ?? "").isEmpty) return "Nhập email";
                              if (!v!.contains("@"))
                                return "Email không hợp lệ";
                              return null;
                            },
                          ),

                          const SizedBox(height: 14),

                          // Password
                          TextFormField(
                            controller: _passCtrl,
                            obscureText: !_showPassword,
                            decoration: InputDecoration(
                              hintText: "Mật khẩu",
                              prefixIcon:
                              const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(_showPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility),
                                onPressed: () {
                                  setState(() {
                                    _showPassword = !_showPassword;
                                  });
                                },
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF3F4F6),
                              border: OutlineInputBorder(
                                borderRadius:
                                BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            validator: (v) {
                              if ((v ?? "").isEmpty)
                                return "Nhập mật khẩu";
                              return null;
                            },
                          ),

                          const SizedBox(height: 20),

                          // 🔥 BUTTON GRADIENT
                          SizedBox(
                            width: double.infinity,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF7C5CFF),
                                    Color(0xFF5F8BFF)
                                  ],
                                ),
                                borderRadius:
                                BorderRadius.circular(14),
                              ),
                              child: ElevatedButton(
                                onPressed: _isSubmitting
                                    ? null
                                    : _handleLogin,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                  Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14),
                                ),
                                child: _isSubmitting
                                    ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                                    : const Text("Đăng nhập"),
                              ),
                            ),
                          ),

                          const SizedBox(height: 14),

                          const Text("Hoặc"),

                          const SizedBox(height: 10),

                          OutlinedButton(
                            onPressed: _isSubmitting
                                ? null
                                : _handleGoogleLogin,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                                "Đăng nhập bằng Google"),
                          ),

                          const SizedBox(height: 10),

                          TextButton(
                            onPressed: () {
                              Navigator.pushNamed(
                                  context, "/register");
                            },
                            child: const Text("Tạo tài khoản mới"),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}