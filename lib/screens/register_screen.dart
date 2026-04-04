import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _auth = AuthService();
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _showPassword = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final result = await _auth.register(
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );

      Navigator.pushReplacementNamed(context, "/login");
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst("Exception: ", ""))),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final isWide = w >= 520;

    const primary = Color(0xFF5B5FEF);
    const secondary = Color(0xFF7B61FF);
    const success = Color(0xFF22C55E);
    const bg = Color(0xFFF8FAFC);
    const cardBg = Colors.white;
    const textDark = Color(0xFF111827);
    const textMuted = Color(0xFF6B7280);
    const inputFill = Color(0xFFF3F4F6);
    const stroke = Color(0xFFE5E7EB);

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          Container(
            height: 320,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [secondary, primary],
              ),
            ),
          ),

          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
            ),
          ),

          Positioned(
            top: 130,
            left: -55,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    children: [
                      Container(
                        width: 82,
                        height: 82,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.10),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.person_add_alt_1_rounded,
                          color: primary,
                          size: 38,
                        ),
                      ).animate().fadeIn(duration: 350.ms).slideY(begin: -0.08),

                      const SizedBox(height: 18),

                      Text(
                        "Tạo tài khoản mới",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isWide ? 30 : 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ).animate().fadeIn(duration: 450.ms).slideY(begin: -0.06),

                      const SizedBox(height: 8),

                      Text(
                        "Bắt đầu quản lý chi tiêu cá nhân và nhóm một cách thông minh",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.92),
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ).animate().fadeIn(duration: 550.ms),

                      const SizedBox(height: 28),

                      Container(
                        padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 32,
                              offset: const Offset(0, 16),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 28,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: success,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Text(
                                    "Đăng ký",
                                    style: TextStyle(
                                      color: textDark,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 8),

                              const Text(
                                "Điền thông tin bên dưới để tạo tài khoản mới",
                                style: TextStyle(
                                  color: textMuted,
                                  fontSize: 14,
                                  height: 1.4,
                                ),
                              ),

                              const SizedBox(height: 22),

                              const Text(
                                "Họ và tên",
                                style: TextStyle(
                                  color: textDark,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),

                              _FinanceTextField(
                                controller: _nameCtrl,
                                hintText: "Nhập họ và tên",
                                prefixIcon: Icons.person_outline_rounded,
                                fillColor: inputFill,
                                borderColor: stroke,
                                focusColor: primary,
                                validator: (v) {
                                  final value = (v ?? "").trim();
                                  if (value.isEmpty) return "Vui lòng nhập họ tên";
                                  if (value.length < 2) return "Họ tên quá ngắn";
                                  return null;
                                },
                              ),

                              const SizedBox(height: 16),

                              const Text(
                                "Email",
                                style: TextStyle(
                                  color: textDark,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),

                              _FinanceTextField(
                                controller: _emailCtrl,
                                hintText: "you@example.com",
                                keyboardType: TextInputType.emailAddress,
                                prefixIcon: Icons.mail_outline_rounded,
                                fillColor: inputFill,
                                borderColor: stroke,
                                focusColor: primary,
                                validator: (v) {
                                  final value = (v ?? "").trim();
                                  if (value.isEmpty) return "Vui lòng nhập email";
                                  if (!value.contains("@")) return "Email không hợp lệ";
                                  return null;
                                },
                              ),

                              const SizedBox(height: 16),

                              const Text(
                                "Mật khẩu",
                                style: TextStyle(
                                  color: textDark,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),

                              _FinanceTextField(
                                controller: _passCtrl,
                                hintText: "Nhập mật khẩu",
                                obscureText: !_showPassword,
                                prefixIcon: Icons.lock_outline_rounded,
                                fillColor: inputFill,
                                borderColor: stroke,
                                focusColor: primary,
                                suffix: IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _showPassword = !_showPassword;
                                    });
                                  },
                                  icon: Icon(
                                    _showPassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: textMuted,
                                  ),
                                ),
                                validator: (v) {
                                  if ((v ?? "").isEmpty) return "Vui lòng nhập mật khẩu";
                                  if ((v ?? "").length < 6) {
                                    return "Mật khẩu tối thiểu 6 ký tự";
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 22),

                              SizedBox(
                                width: double.infinity,
                                height: 54,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [secondary, primary],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: primary.withOpacity(0.28),
                                        blurRadius: 18,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    onPressed: _isSubmitting ? null : _handleRegister,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      foregroundColor: Colors.white,
                                      disabledBackgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: _isSubmitting
                                        ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.4,
                                        color: Colors.white,
                                      ),
                                    )
                                        : const Text(
                                      "Đăng ký",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 16),

                              Center(
                                child: TextButton(
                                  onPressed: () =>
                                      Navigator.pushReplacementNamed(context, "/login"),
                                  child: const Text.rich(
                                    TextSpan(
                                      text: "Đã có tài khoản? ",
                                      style: TextStyle(
                                        color: textMuted,
                                        fontSize: 14,
                                      ),
                                      children: [
                                        TextSpan(
                                          text: "Đăng nhập ngay",
                                          style: TextStyle(
                                            color: primary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ).animate().fadeIn(duration: 650.ms).slideY(begin: 0.05),

                      const SizedBox(height: 18),

                      Text(
                        "Dữ liệu của bạn sẽ được bảo mật và đồng bộ an toàn",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.88),
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FinanceTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final TextInputType? keyboardType;
  final bool obscureText;
  final IconData prefixIcon;
  final Widget? suffix;
  final String? Function(String?)? validator;
  final Color fillColor;
  final Color borderColor;
  final Color focusColor;

  const _FinanceTextField({
    required this.controller,
    required this.hintText,
    required this.prefixIcon,
    required this.fillColor,
    required this.borderColor,
    required this.focusColor,
    this.keyboardType,
    this.obscureText = false,
    this.suffix,
    this.validator,
  });

  @override
  State<_FinanceTextField> createState() => _FinanceTextFieldState();
}

class _FinanceTextFieldState extends State<_FinanceTextField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (v) => setState(() => _focused = v),
      child: AnimatedContainer(
        duration: 180.ms,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            if (_focused)
              BoxShadow(
                color: widget.focusColor.withOpacity(0.12),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
          ],
        ),
        child: TextFormField(
          controller: widget.controller,
          keyboardType: widget.keyboardType,
          obscureText: widget.obscureText,
          validator: widget.validator,
          style: const TextStyle(
            color: Color(0xFF111827),
            fontSize: 14.5,
          ),
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
            filled: true,
            fillColor: widget.fillColor,
            prefixIcon: Icon(
              widget.prefixIcon,
              color: _focused ? widget.focusColor : const Color(0xFF6B7280),
            ),
            suffixIcon: widget.suffix,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: widget.borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: widget.focusColor,
                width: 1.4,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.redAccent),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: Colors.redAccent,
                width: 1.4,
              ),
            ),
          ),
        ),
      ),
    );
  }
}