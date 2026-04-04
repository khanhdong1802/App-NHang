import 'package:flutter/material.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  void _goToLogin(BuildContext context) {
    Navigator.pushReplacementNamed(context, "/login");
  }

  @override
  Widget build(BuildContext context) {
    const pink = Color(0xFFFA7F7F);
    const pinkLight = Color(0xFFFFA1A1);
    const whiteCard = Color(0xFFF7F5F5);
    const textDark = Color(0xFF4A4A4A);
    const textMuted = Color(0xFFB0A8A8);

    return Scaffold(
      backgroundColor: pink,
      body: SafeArea(
        child: Stack(
          children: [
            // Nền hồng + pattern
            Positioned.fill(
              child: CustomPaint(
                painter: _TopographicPainter(
                  lineColor: Colors.white.withOpacity(0.22),
                ),
              ),
            ),

            // Khối trắng cong dưới
            Align(
              alignment: Alignment.bottomCenter,
              child: ClipPath(
                clipper: _BottomWaveClipper(),
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.46,
                  width: double.infinity,
                  color: whiteCard,
                ),
              ),
            ),

            // Nội dung
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    const Spacer(),

                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.34,
                    ),

                    const Spacer(),

                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Welcome",
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: textDark,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Quản lý chi tiêu cá nhân và chia sẻ nhóm\nmột cách đơn giản, trực quan.",
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: textMuted.withOpacity(0.95),
                        ),
                      ),
                    ),

                    const Spacer(),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          "Continue",
                          style: TextStyle(
                            fontSize: 12.5,
                            color: textMuted.withOpacity(0.95),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: () => _goToLogin(context),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: const BoxDecoration(
                              color: pink,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 26),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();

    path.lineTo(0, size.height * 0.22);

    path.quadraticBezierTo(
      size.width * 0.18,
      size.height * 0.02,
      size.width * 0.42,
      size.height * 0.12,
    );

    path.quadraticBezierTo(
      size.width * 0.62,
      size.height * 0.24,
      size.width,
      size.height * 0.04,
    );

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _TopographicPainter extends CustomPainter {
  final Color lineColor;

  _TopographicPainter({required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final paths = <Path>[
      _blobPath(
        size,
        const Offset(0.22, 0.18),
        90,
      ),
      _blobPath(
        size,
        const Offset(0.65, 0.20),
        110,
      ),
      _blobPath(
        size,
        const Offset(0.48, 0.48),
        120,
      ),
      _blobPath(
        size,
        const Offset(0.84, 0.44),
        80,
      ),
      _blobPath(
        size,
        const Offset(0.10, 0.55),
        70,
      ),
    ];

    for (final p in paths) {
      canvas.drawPath(p, paint);
    }
  }

  Path _blobPath(Size size, Offset centerFactor, double radius) {
    final cx = size.width * centerFactor.dx;
    final cy = size.height * centerFactor.dy;

    Path path = Path();
    for (int i = 0; i < 5; i++) {
      final r = radius - (i * 16);
      if (r <= 8) continue;

      final p = Path();
      p.moveTo(cx, cy - r);

      p.cubicTo(
        cx + r * 0.85,
        cy - r * 0.95,
        cx + r * 1.08,
        cy + r * 0.35,
        cx,
        cy + r,
      );

      p.cubicTo(
        cx - r * 1.05,
        cy + r * 0.72,
        cx - r * 1.05,
        cy - r * 0.45,
        cx,
        cy - r,
      );

      path.addPath(p, Offset.zero);
    }
    return path;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}