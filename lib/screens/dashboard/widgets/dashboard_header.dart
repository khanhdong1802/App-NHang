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
    const primary = Color(0xFF5B5FEF);
    const secondary = Color(0xFF7B61FF);
    const textSoft = Color(0xFFEDE9FE);
    const danger = Color(0xFFFB7185);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7B61FF), Color(0xFF5B5FEF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.22),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -24,
            right: -18,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -18,
            left: -12,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.06),
              ),
            ),
          ),
          Column(
            children: [
              Row(
                children: [
                  Builder(
                    builder: (ctx) => _IconSurfaceButton(
                      icon: Icons.menu_rounded,
                      onTap: () => Scaffold.of(ctx).openDrawer(),
                    ),
                  ),
                  const Spacer(),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _IconSurfaceButton(
                        icon: Icons.notifications_none_rounded,
                        onTap: () => setState(() => showNoti = !showNoti),
                      ),
                      if (hasPending)
                        Positioned(
                          top: 3,
                          right: 3,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: danger,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.8),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  _AvatarCircle(url: widget.avatarUrl),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Xin chào",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.78),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.userName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(999),
                          ),

                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      title: "Số dư",
                      value: _money(widget.balance),
                      icon: Icons.account_balance_wallet_outlined,
                      subtleTextColor: textSoft,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricCard(
                      title: "Đã chi",
                      value: _money(widget.totalSpent),
                      icon: Icons.arrow_upward_rounded,
                      subtleTextColor: textSoft,
                    ),
                  ),
                ],
              ),

              if (showNoti) ...[
                const SizedBox(height: 14),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(10),
                  child: NotificationPanel(
                    notifications: widget.notifications,
                    onAccept: widget.onAcceptInvite,
                    onReject: widget.onRejectInvite,
                  ),
                ),
              ],

              if (widget.loading) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: const LinearProgressIndicator(
                    minHeight: 4,
                    backgroundColor: Color(0x33FFFFFF),
                    color: Colors.white,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _IconSurfaceButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _IconSurfaceButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.14),
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          child: Icon(
            icon,
            color: Colors.white,
            size: 23,
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color subtleTextColor;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.subtleTextColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.10),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 19,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: subtleTextColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
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
    return "${ApiConfig.baseUrl}$raw";
  }

  @override
  Widget build(BuildContext context) {
    final resolved = _resolveUrl(url);

    final finalUrl = resolved.isEmpty
        ? ""
        : (resolved.contains("?")
        ? "$resolved&v=${DateTime.now().millisecondsSinceEpoch}"
        : "$resolved?v=${DateTime.now().millisecondsSinceEpoch}");

    return Container(
      width: 64,
      height: 64,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.20),
      ),
      child: ClipOval(
        child: finalUrl.isNotEmpty
            ? Image.network(
          finalUrl,
          key: ValueKey(finalUrl),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(),
        )
            : _fallback(),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFF6366F1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.person_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }
}