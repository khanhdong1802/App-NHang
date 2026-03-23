// TODO Implement this library.
import 'package:flutter/material.dart';
import 'notification_panel.dart';
import 'package:doanmonhoc/services/api_config.dart';
class DashboardHeader extends StatefulWidget {
  final String userName;
  final String? avatarUrl;
  final num balance;
  final num totalSpent;
  final num spendingLimit;
  final int monthPercent;
  final List<Map<String, dynamic>> notifications;
  final bool loading;

  final Future<void> Function(String notiId) onAcceptInvite;
  final Future<void> Function(String notiId) onRejectInvite;

  const DashboardHeader({
    super.key,
    required this.userName,
    required this.avatarUrl,
    required this.balance,
    required this.totalSpent,
    required this.spendingLimit,
    required this.monthPercent,
    required this.notifications,
    required this.loading,
    required void Function() onToggleNoti,
    required this.onAcceptInvite,
    required this.onRejectInvite,
  });

  @override
  State<DashboardHeader> createState() => _DashboardHeaderState();
}

class _DashboardHeaderState extends State<DashboardHeader> {
  bool showNoti = false;

  String _money(num v) {
    final s = v.toStringAsFixed(0);
    final chars = s.split('');
    final buf = StringBuffer();
    for (int i = 0; i < chars.length; i++) {
      final idxFromEnd = chars.length - i;
      buf.write(chars[i]);
      if (idxFromEnd > 1 && idxFromEnd % 3 == 1) buf.write(',');
    }
    return "${buf}đ";
  }

  bool get hasPending =>
      widget.notifications.any((n) => n["status"]?.toString() == "pending");

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6D5EF9), Color(0xFF9B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
        boxShadow: [
          BoxShadow(color: Color(0x33000000), blurRadius: 18, offset: Offset(0, 10))
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Builder(
                builder: (ctx) => IconButton(
                  icon: const Icon(Icons.menu_rounded, color: Colors.white),
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                ),
              ),
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_none_rounded, color: Colors.white),
                    onPressed: () => setState(() => showNoti = !showNoti),
                  ),
                  if (hasPending)
                    Positioned(
                      right: 10,
                      top: 10,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFB4BB4),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 6),

          Row(
            children: [
              _AvatarCircle(url: widget.avatarUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.userName,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),

                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(child: _HeaderCard(title: "Đã chi", value: _money(widget.totalSpent))),
              const SizedBox(width: 12),
              Expanded(child: _HeaderCard(title: "Số dư", value: _money(widget.balance))),
            ],
          ),

          if (showNoti) ...[
            const SizedBox(height: 12),
            NotificationPanel(
              notifications: widget.notifications,
              onAccept: widget.onAcceptInvite,
              onReject: widget.onRejectInvite,
            ),
          ],

          if (widget.loading) ...[
            const SizedBox(height: 10),
            const LinearProgressIndicator(
              minHeight: 3,
              backgroundColor: Color(0x33FFFFFF),
              color: Colors.white,
            ),
          ],
        ],
      ),
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  final String? url;
  const _AvatarCircle({this.url});

  String _resolveUrl(String? u) {
    final raw = (u ?? "").trim();
    if (raw.isEmpty) return "";
    if (raw.startsWith("http")) return raw;
    return "${ApiConfig.baseUrl}$raw"; // ghép baseUrl nếu là /uploads/...
  }

  @override
  Widget build(BuildContext context) {
    final resolved = _resolveUrl(url);

    // cache bust để chắc chắn ra avatar mới (tránh bị cache)
    final finalUrl = resolved.isEmpty
        ? ""
        : (resolved.contains("?")
        ? "$resolved&v=${DateTime.now().millisecondsSinceEpoch}"
        : "$resolved?v=${DateTime.now().millisecondsSinceEpoch}");

    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white30, width: 3),
        gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF6366F1)]),
      ),
      child: ClipOval(
        child: finalUrl.isNotEmpty
            ? Image.network(
          finalUrl,
          key: ValueKey(finalUrl), // ép rebuild khi url đổi
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(),
        )
            : _fallback(),
      ),
    );
  }

  Widget _fallback() => const Center(
    child: Text("avatar", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
  );
}

class _HeaderCard extends StatelessWidget {
  final String title;
  final String value;
  const _HeaderCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.25),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
