import 'package:flutter/material.dart';

class DashboardDrawer extends StatefulWidget {
  final List<Map<String, dynamic>> rooms;
  final VoidCallback onGoPersonal;
  final void Function(String roomId) onGoRoom;
  final VoidCallback onCreateRoom;
  final VoidCallback onLogout;
  final VoidCallback onGoHistory;
  final VoidCallback onGoStats;
  final VoidCallback onGoSettings;

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
    required this.onGoAdmin,
    required this.showAdmin,
  });

  @override
  State<DashboardDrawer> createState() => _DashboardDrawerState();
}

class _DashboardDrawerState extends State<DashboardDrawer> {
  bool _groupExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6D5EF9), Color(0xFF9B5CF6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 10),
              const Text(
                "MENU",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              const Divider(color: Colors.white24),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  children: [
                    _Item(
                      icon: Icons.home_rounded,
                      text: "Trang chủ cá nhân",
                      onTap: widget.onGoPersonal,
                    ),

                    const SizedBox(height: 4),

                    // ====== NHÓM GOM CHUNG ======
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(
                              Icons.group_rounded,
                              color: Colors.white,
                            ),
                            title: const Text(
                              "Nhóm",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white12,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    "${widget.rooms.length}",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  _groupExpanded
                                      ? Icons.keyboard_arrow_up_rounded
                                      : Icons.keyboard_arrow_down_rounded,
                                  color: Colors.white,
                                ),
                              ],
                            ),
                            onTap: () {
                              setState(() {
                                _groupExpanded = !_groupExpanded;
                              });
                            },
                          ),

                          AnimatedCrossFade(
                            duration: const Duration(milliseconds: 220),
                            crossFadeState: _groupExpanded
                                ? CrossFadeState.showFirst
                                : CrossFadeState.showSecond,
                            firstChild: Padding(
                              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                              child: Column(
                                children: [
                                  const Divider(color: Colors.white24, height: 1),

                                  const SizedBox(height: 6),

                                  _SubItem(
                                    icon: Icons.add_rounded,
                                    text: "Thêm nhóm mới",
                                    onTap: widget.onCreateRoom,
                                  ),

                                  if (widget.rooms.isEmpty)
                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          "Chưa có nhóm nào",
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    )
                                  else
                                    ...widget.rooms.map((r) {
                                      final id = (r["_id"] ?? "").toString();
                                      final name =
                                      (r["name"] ?? "Nhóm").toString();

                                      return _SubItem(
                                        icon: Icons.groups_rounded,
                                        text: name,
                                        onTap: () => widget.onGoRoom(id),
                                      );
                                    }),
                                ],
                              ),
                            ),
                            secondChild: const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 4),

                    _Item(
                      icon: Icons.history_rounded,
                      text: "Lịch sử giao dịch",
                      onTap: widget.onGoHistory,
                    ),
                    _Item(
                      icon: Icons.bar_chart_rounded,
                      text: "Thống kê",
                      onTap: widget.onGoStats,
                    ),
                    _Item(
                      icon: Icons.settings_rounded,
                      text: "Cài đặt tài khoản",
                      onTap: widget.onGoSettings,
                    ),

                    if (widget.showAdmin)
                      _Item(
                        icon: Icons.admin_panel_settings_rounded,
                        text: "Admin",
                        onTap: widget.onGoAdmin,
                      ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.only(left: 10, right: 10, bottom: 12),
                child: _Item(
                  icon: Icons.logout_rounded,
                  text: "Đăng xuất",
                  danger: true,
                  onTap: widget.onLogout,
                ),
              ),
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

  const _Item({
    required this.icon,
    required this.text,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFFFE4E6) : Colors.white;
    final bg = danger ? const Color(0x55EF4444) : Colors.white10;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          text,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
        onTap: onTap,
        tileColor: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}

class _SubItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  const _SubItem({
    required this.icon,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: Icon(icon, color: Colors.white70, size: 20),
      title: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}