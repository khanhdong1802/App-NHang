import 'package:flutter/material.dart';

class DashboardDrawer extends StatelessWidget {
  final List<Map<String, dynamic>> rooms;
  final VoidCallback onGoPersonal;
  final void Function(String roomId) onGoRoom;
  final VoidCallback onCreateRoom;
  final VoidCallback onLogout;
  final VoidCallback onGoHistory;
  final VoidCallback onGoStats;
  final VoidCallback onGoSettings;

  // ✅ NEW
  final VoidCallback onGoAdmin;
  final bool showAdmin;

  const DashboardDrawer({
    super.key,
    required this.rooms,
    required this.onGoPersonal,
    required this.onGoRoom,
    required this.onCreateRoom,
    required this.onLogout,
    required this.onGoHistory,
    required this.onGoStats,
    required this.onGoSettings,

    // ✅ NEW
    required this.onGoAdmin,
    required this.showAdmin,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFF6D5EF9), Color(0xFF9B5CF6)]),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 10),
              const Text("MENU", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              const Divider(color: Colors.white24),

              _Item(icon: Icons.home_rounded, text: "Trang chủ cá nhân", onTap: onGoPersonal),

              ...rooms.map((r) {
                final id = (r["_id"] ?? "").toString();
                final name = (r["name"] ?? "Room").toString();
                return _Item(icon: Icons.group_rounded, text: name, onTap: () => onGoRoom(id));
              }),

              _Item(icon: Icons.add_rounded, text: "Thêm phòng mới", onTap: onCreateRoom),
              _Item(icon: Icons.qr_code_rounded, text: "QR Code", onTap: () {}),
              _Item(icon: Icons.history_rounded, text: "Lịch sử giao dịch", onTap: onGoHistory),
              _Item(icon: Icons.bar_chart_rounded, text: "Thống kê", onTap: onGoStats),
              _Item(icon: Icons.settings_rounded, text: "Cài đặt tài khoản", onTap: onGoSettings),

              // ✅ NEW: Admin item
              if (showAdmin)
                _Item(
                  icon: Icons.admin_panel_settings_rounded,
                  text: "Admin",
                  onTap: onGoAdmin,
                ),

              const Spacer(),
              _Item(icon: Icons.logout_rounded, text: "Đăng xuất", danger: true, onTap: onLogout),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  final bool danger;

  const _Item({required this.icon, required this.text, required this.onTap, this.danger = false});

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFFFE4E6) : Colors.white;
    final bg = danger ? const Color(0x55EF4444) : Colors.white10;

    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
      onTap: onTap,
      tileColor: bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
  }
}
