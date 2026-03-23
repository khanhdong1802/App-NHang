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

      // giống React: đăng ký xong -> chuyển qua login
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

    const accent = Color(0xFF34D399); // emerald
    const accent2 = Color(0xFF2DD4BF); // teal

    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0B1220),
                  Color(0xFF070A12),
                  Color(0xFF0B1220),
                ],
              ),
            ),
          ),

          // Glow blobs
          _GlowBlob(
            alignment: const Alignment(1.15, -1.15),
            size: 290,
            color: const Color(0x4D10B981), // emerald 30%
            blur: 70,
            durationMs: 2200,
          ),
          _GlowBlob(
            alignment: const Alignment(-1.20, 1.20),
            size: 320,
            color: const Color(0x4D6366F1), // indigo 30%
            blur: 75,
            durationMs: 2600,
          ),

          // Ring
          Center(
            child: Container(
              width: 380,
              height: 380,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0x1A34D399), width: 1),
              ),
            ),
          ).animate().fadeIn(duration: 600.ms),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    children: [
                      // Header
                      Column(
                        children: [
                          _Badge(
                            text: "Personal Finance App",
                            accent: accent,
                          ).animate().fadeIn(duration: 350.ms).slideY(begin: -0.1),
                          const SizedBox(height: 10),
                          Text(
                            "Tạo tài khoản mới",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isWide ? 34 : 30,
                              fontWeight: FontWeight.w800,
                            ),
                            textAlign: TextAlign.center,
                          ).animate().fadeIn(duration: 450.ms).slideY(begin: -0.08),
                          const SizedBox(height: 6),
                          const Text(
                            "Quản lý chi tiêu hiệu quả hơn cùng chúng tôi!",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white70, height: 1.3),
                          ).animate().fadeIn(duration: 550.ms),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Glass Card
                      _GlassCard(
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: const [
                                  _AccentLine(color: accent),
                                  SizedBox(width: 10),
                                  Text(
                                    "Đăng ký",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              const Text("Họ và tên",
                                  style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              _GlowTextField(
                                accent: accent,
                                controller: _nameCtrl,
                                hintText: "Họ Tên",
                                prefixIcon: Icons.person_outline_rounded,
                                validator: (v) {
                                  final value = (v ?? "").trim();
                                  if (value.isEmpty) return "Vui lòng nhập họ tên";
                                  if (value.length < 2) return "Họ tên quá ngắn";
                                  return null;
                                },
                              ),

                              const SizedBox(height: 14),

                              const Text("Email",
                                  style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              _GlowTextField(
                                accent: accent,
                                controller: _emailCtrl,
                                hintText: "you@example.com",
                                keyboardType: TextInputType.emailAddress,
                                prefixIcon: Icons.mail_outline_rounded,
                                validator: (v) {
                                  final value = (v ?? "").trim();
                                  if (value.isEmpty) return "Vui lòng nhập email";
                                  if (!value.contains("@")) return "Email không hợp lệ";
                                  return null;
                                },
                              ),

                              const SizedBox(height: 14),

                              const Text("Mật khẩu",
                                  style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              _GlowTextField(
                                accent: accent,
                                controller: _passCtrl,
                                hintText: "••••••••",
                                obscureText: !_showPassword,
                                prefixIcon: Icons.lock_outline_rounded,
                                suffix: IconButton(
                                  onPressed: () => setState(() => _showPassword = !_showPassword),
                                  icon: Icon(
                                    _showPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                    color: Colors.white60,
                                  ),
                                ),
                                validator: (v) {
                                  if ((v ?? "").isEmpty) return "Vui lòng nhập mật khẩu";
                                  if ((v ?? "").length < 6) return "Mật khẩu tối thiểu 6 ký tự";
                                  return null;
                                },
                              ),

                              const SizedBox(height: 18),

                              SizedBox(
                                width: double.infinity,
                                height: 46,
                                child: _GradientButton(
                                  accent: accent,
                                  accent2: accent2,
                                  isLoading: _isSubmitting,
                                  onPressed: _isSubmitting ? null : _handleRegister,
                                  text: _isSubmitting ? "Đang đăng ký..." : "Đăng ký",
                                ),
                              ),

                              const SizedBox(height: 14),

                              Center(
                                child: TextButton(
                                  onPressed: () => Navigator.pushReplacementNamed(context, "/login"),
                                  child: const Text(
                                    "Đã có tài khoản? Đăng nhập ngay",
                                    style: TextStyle(color: Color(0xFF6EE7B7), fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ).animate().fadeIn(duration: 650.ms).slideY(begin: 0.06),
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

/* ------- Widgets ------- */

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: const Color(0x0DFFFFFF),
        border: Border.all(color: const Color(0x1AFFFFFF)),
        boxShadow: const [
          BoxShadow(
            blurRadius: 50,
            offset: Offset(0, 18),
            color: Color(0xB0000000),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0x0DFFFFFF)),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _GlowTextField extends StatefulWidget {
  final Color accent;
  final TextEditingController controller;
  final String hintText;
  final TextInputType? keyboardType;
  final bool obscureText;
  final IconData prefixIcon;
  final Widget? suffix;
  final String? Function(String?)? validator;

  const _GlowTextField({
    required this.accent,
    required this.controller,
    required this.hintText,
    required this.prefixIcon,
    this.keyboardType,
    this.obscureText = false,
    this.suffix,
    this.validator,
  });

  @override
  State<_GlowTextField> createState() => _GlowTextFieldState();
}

class _GlowTextFieldState extends State<_GlowTextField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final borderColor = _focused ? widget.accent : const Color(0xB33B4A66);
    final glow = _focused ? widget.accent.withOpacity(0.35) : Colors.transparent;

    return AnimatedContainer(
      duration: 160.ms,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            offset: const Offset(0, 10),
            color: glow,
          ),
        ],
      ),
      child: Focus(
        onFocusChange: (v) => setState(() => _focused = v),
        child: TextFormField(
          controller: widget.controller,
          keyboardType: widget.keyboardType,
          obscureText: widget.obscureText,
          validator: widget.validator,
          style: const TextStyle(color: Colors.white, fontSize: 14.5),
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
            filled: true,
            fillColor: const Color(0x9920283A),
            prefixIcon: Icon(widget.prefixIcon, color: _focused ? widget.accent : Colors.white54),
            suffixIcon: widget.suffix,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: borderColor, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: widget.accent, width: 1.2),
            ),
          ),
        ),
      ),
    );
  }
}

class _GradientButton extends StatefulWidget {
  final Color accent;
  final Color accent2;
  final VoidCallback? onPressed;
  final String text;
  final bool isLoading;

  const _GradientButton({
    required this.accent,
    required this.accent2,
    required this.onPressed,
    required this.text,
    required this.isLoading,
  });

  @override
  State<_GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<_GradientButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: disabled ? null : widget.onPressed,
      child: AnimatedContainer(
        duration: 120.ms,
        transform: Matrix4.translationValues(0, _pressed ? 2 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [widget.accent, widget.accent2],
          ),
          boxShadow: [
            BoxShadow(
              blurRadius: _pressed ? 18 : 28,
              offset: const Offset(0, 14),
              color: widget.accent.withOpacity(0.45),
            )
          ],
        ),
        child: Center(
          child: widget.isLoading
              ? Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
              ),
              SizedBox(width: 10),
              Text("Đang đăng ký...",
                  style: TextStyle(color: Color(0xFF0B1220), fontWeight: FontWeight.w800)),
            ],
          )
              : Text(
            widget.text,
            style: TextStyle(
              color: disabled ? Colors.black38 : const Color(0xFF0B1220),
              fontWeight: FontWeight.w900,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color accent;

  const _Badge({required this.text, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: accent.withOpacity(0.12),
        border: Border.all(color: accent.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(shape: BoxShape.circle, color: accent),
              ),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(shape: BoxShape.circle, color: accent),
              )
                  .animate(onPlay: (c) => c.repeat())
                  .scale(begin: const Offset(1, 1), end: const Offset(2.1, 2.1), duration: 900.ms)
                  .fadeOut(begin: 0.55, duration: 900.ms),
            ],
          ),
          const SizedBox(width: 10),
          Text(
            text,
            style: TextStyle(color: accent.withOpacity(0.9), fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _AccentLine extends StatelessWidget {
  final Color color;
  const _AccentLine({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 2.5,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  final Alignment alignment;
  final double size;
  final Color color;
  final double blur;
  final int durationMs;

  const _GlowBlob({
    required this.alignment,
    required this.size,
    required this.color,
    required this.blur,
    required this.durationMs,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scale(begin: const Offset(1, 1), end: const Offset(1.08, 1.08), duration: durationMs.ms)
        .blurXY(begin: 0, end: blur, duration: durationMs.ms);
  }
}
