import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:doanmonhoc/services/admin_api.dart';
import 'package:doanmonhoc/services/api_config.dart';

class AdminPage extends StatefulWidget {
  final Future<String?> Function() tokenProvider;
  const AdminPage({super.key, required this.tokenProvider});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> with TickerProviderStateMixin {
  // ===== Theme (match app purple) =====
  static const _c1 = Color(0xFF6D5EF9);
  static const _c2 = Color(0xFF9B5CF6);
  static const _bg = Color(0xFFF6F7FB);

  late final TabController _tab;
  late final AdminApi api;

  late final AnimationController _enterCtrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  bool loading = true;
  String q = "";

  List<Map<String, dynamic>> users = [];
  List<Map<String, dynamic>> categories = [];
  List<Map<String, dynamic>> groups = [];
  Map<String, dynamic> stats = {
    "totalUsers": 0,
    "totalGroups": 0,
    "totalTransactions": 0,
    "userGrowthPercent": 0,
  };

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this)..addListener(() => setState(() {}));

    api = AdminApi(
      baseUrl: ApiConfig.baseUrl,
      tokenProvider: widget.tokenProvider,
    );

    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    final curved = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutCubic);
    _fade = Tween<double>(begin: 0, end: 1).animate(curved);
    _slide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(curved);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _enterCtrl.forward();
    });

    _loadAll();
  }

  @override
  void dispose() {
    _tab.dispose();
    _enterCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => loading = true);
    try {
      final rs = await Future.wait([
        api.fetchUsers(),
        api.fetchCategories(),
        api.fetchGroupsAll(),
        api.fetchOverviewStats(),
      ]);
      if (!mounted) return;
      setState(() {
        users = rs[0] as List<Map<String, dynamic>>;
        categories = rs[1] as List<Map<String, dynamic>>;
        groups = rs[2] as List<Map<String, dynamic>>;
        stats = rs[3] as Map<String, dynamic>;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      _toast(e.toString().replaceFirst("Exception: ", ""));
    }
  }

  void _toast(String s) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(s), behavior: SnackBarBehavior.floating),
    );
  }

  Future<bool> _confirm(String title, String content) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Hủy")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("OK")),
        ],
      ),
    );
    return ok == true;
  }

  List<Map<String, dynamic>> get filteredUsers {
    final s = q.trim().toLowerCase();
    if (s.isEmpty) return users;
    return users.where((u) {
      final name = (u["name"] ?? "").toString().toLowerCase();
      final email = (u["email"] ?? "").toString().toLowerCase();
      return name.contains(s) || email.contains(s);
    }).toList();
  }

  List<Map<String, dynamic>> get filteredCategories {
    final s = q.trim().toLowerCase();
    if (s.isEmpty) return categories;
    return categories.where((c) {
      final name = (c["name"] ?? "").toString().toLowerCase();
      final type = (c["type"] ?? "").toString().toLowerCase();
      return name.contains(s) || type.contains(s);
    }).toList();
  }

  // ===== Dialog: Add / Edit Category (giữ logic cũ) =====
  Future<void> _openAddCategory() async {
    final name = TextEditingController();
    final desc = TextEditingController();
    String type = "expense";

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text("Thêm danh mục", style: TextStyle(fontWeight: FontWeight.w900)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: "Tên")),
              TextField(controller: desc, decoration: const InputDecoration(labelText: "Mô tả")),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: type,
                items: const [
                  DropdownMenuItem(value: "expense", child: Text("Chi tiêu")),
                  DropdownMenuItem(value: "income", child: Text("Thu nhập")),
                ],
                onChanged: (v) => setLocal(() => type = v ?? "expense"),
                decoration: const InputDecoration(labelText: "Loại"),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Hủy")),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Lưu")),
          ],
        ),
      ),
    );

    if (ok != true) return;

    try {
      final added = await api.addCategory({
        "name": name.text.trim(),
        "description": desc.text.trim(),
        "type": type,
      });
      if (!mounted) return;
      setState(() => categories = [...categories, added]);
      _toast("Đã thêm danh mục");
    } catch (e) {
      _toast(e.toString().replaceFirst("Exception: ", ""));
    }
  }

  Future<void> _openEditCategory(Map<String, dynamic> c) async {
    final name = TextEditingController(text: (c["name"] ?? "").toString());
    final desc = TextEditingController(text: (c["description"] ?? "").toString());
    String type = (c["type"] ?? "expense").toString();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text("Sửa danh mục", style: TextStyle(fontWeight: FontWeight.w900)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: "Tên")),
              TextField(controller: desc, decoration: const InputDecoration(labelText: "Mô tả")),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: type,
                items: const [
                  DropdownMenuItem(value: "expense", child: Text("Chi tiêu")),
                  DropdownMenuItem(value: "income", child: Text("Thu nhập")),
                ],
                onChanged: (v) => setLocal(() => type = v ?? type),
                decoration: const InputDecoration(labelText: "Loại"),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Hủy")),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Lưu")),
          ],
        ),
      ),
    );

    if (ok != true) return;

    try {
      final id = (c["_id"] ?? "").toString();
      final updated = await api.updateCategory(id, {
        "name": name.text.trim(),
        "description": desc.text.trim(),
        "type": type,
      });
      if (!mounted) return;

      setState(() {
        categories = categories.map((x) {
          final xid = (x["_id"] ?? "").toString();
          return xid == id ? updated : x;
        }).toList();
      });
      _toast("Đã cập nhật danh mục");
    } catch (e) {
      _toast(e.toString().replaceFirst("Exception: ", ""));
    }
  }

  // ===== UI pieces =====
  Widget _gradientHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [_c1, _c2], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -70,
            right: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.12),
              ),
            ),
          ),
          Positioned(
            top: 80,
            left: -70,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.10),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                      ),
                      const Expanded(
                        child: Text(
                          "Admin Dashboard",
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                        ),
                      ),
                      IconButton(
                        onPressed: _loadAll,
                        icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                      ),
                    ],
                  ),

                  Text(
                    "Quản lý users • categories • groups",
                    style: TextStyle(color: Colors.white.withOpacity(0.85), fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),

                  // stats
                  SlideTransition(
                    position: _slide,
                    child: FadeTransition(
                      opacity: _fade,
                      child: Row(
                        children: [
                          Expanded(child: _GlassStatCard(label: "Users", value: "${stats["totalUsers"] ?? 0}", icon: Icons.people_alt_rounded)),
                          const SizedBox(width: 10),
                          Expanded(child: _GlassStatCard(label: "Groups", value: "${stats["totalGroups"] ?? 0}", icon: Icons.groups_rounded)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SlideTransition(
                    position: _slide,
                    child: FadeTransition(
                      opacity: _fade,
                      child: Row(
                        children: [
                          Expanded(child: _GlassStatCard(label: "Giao dịch", value: "${stats["totalTransactions"] ?? 0}", icon: Icons.receipt_long_rounded)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _GlassStatCard(
                              label: "Tăng trưởng",
                              value: "+${stats["userGrowthPercent"] ?? 0}%",
                              icon: Icons.trending_up_rounded,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // search bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.white.withOpacity(0.28)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.search_rounded, color: Colors.white.withOpacity(0.95)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                onChanged: (v) => setState(() => q = v),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                                decoration: InputDecoration(
                                  hintText: "Tìm kiếm users / categories...",
                                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.75), fontWeight: FontWeight.w700),
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                              ),
                            ),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 140),
                              child: q.trim().isEmpty
                                  ? const SizedBox.shrink()
                                  : InkWell(
                                key: const ValueKey("clear"),
                                onTap: () => setState(() => q = ""),
                                child: Icon(Icons.close_rounded, color: Colors.white.withOpacity(0.95)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // tabs pill
                  _PillTabBar(controller: _tab),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    return Expanded(
      child: Container(
        decoration: const BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: RefreshIndicator(
          onRefresh: _loadAll,
          child: loading
              ? ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: const [
              _SkeletonBlock(),
              SizedBox(height: 12),
              _SkeletonBlock(),
              SizedBox(height: 12),
              _SkeletonBlock(),
            ],
          )
              : TabBarView(
            controller: _tab,
            children: [
              _UsersTabModern(
                users: filteredUsers,
                onLock: (id) async {
                  try {
                    await api.lockUser(id);
                    setState(() {
                      users = users.map((u) {
                        if ((u["_id"] ?? "").toString() == id) {
                          return {...u, "locked": true, "status": "locked"};
                        }
                        return u;
                      }).toList();
                    });
                  } catch (e) {
                    _toast(e.toString().replaceFirst("Exception: ", ""));
                  }
                },
                onUnlock: (id) async {
                  try {
                    await api.unlockUser(id);
                    setState(() {
                      users = users.map((u) {
                        if ((u["_id"] ?? "").toString() == id) {
                          return {...u, "locked": false, "status": "active"};
                        }
                        return u;
                      }).toList();
                    });
                  } catch (e) {
                    _toast(e.toString().replaceFirst("Exception: ", ""));
                  }
                },
                onDelete: (id) async {
                  final ok = await _confirm("Xóa user", "Bạn chắc chắn muốn xóa user này?");
                  if (!ok) return;
                  try {
                    await api.deleteUser(id);
                    setState(() => users = users.where((u) => (u["_id"] ?? "").toString() != id).toList());
                  } catch (e) {
                    _toast(e.toString().replaceFirst("Exception: ", ""));
                  }
                },
              ),
              _CategoriesTabModern(
                categories: filteredCategories,
                onAdd: _openAddCategory,
                onEdit: _openEditCategory,
                onDelete: (id) async {
                  final ok = await _confirm("Xóa danh mục", "Bạn chắc chắn muốn xóa danh mục này?");
                  if (!ok) return;
                  try {
                    await api.deleteCategory(id);
                    setState(() => categories = categories.where((c) => (c["_id"] ?? "").toString() != id).toList());
                  } catch (e) {
                    _toast(e.toString().replaceFirst("Exception: ", ""));
                  }
                },
              ),
              _GroupsTabModern(
                groups: groups,
                onDelete: (groupId) async {
                  final ok = await _confirm("Xóa nhóm", "Bạn chắc chắn muốn xóa nhóm này?");
                  if (!ok) return;
                  try {
                    await api.deleteGroup(groupId);
                    setState(() {
                      groups = groups.where((g) {
                        final id = (g["_id"] ?? g["id"] ?? "").toString();
                        return id != groupId;
                      }).toList();
                    });
                  } catch (e) {
                    _toast(e.toString().replaceFirst("Exception: ", ""));
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fab() {
    final isCategories = _tab.index == 1;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
      child: isCategories
          ? FloatingActionButton.extended(
        key: const ValueKey("fab_add"),
        onPressed: _openAddCategory,
        backgroundColor: _c1,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text("Thêm danh mục", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
      )
          : const SizedBox.shrink(key: ValueKey("fab_none")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      floatingActionButton: _fab(),
      body: Column(
        children: [
          SlideTransition(position: _slide, child: FadeTransition(opacity: _fade, child: _gradientHeader())),
          _body(),
        ],
      ),
    );
  }
}

// ===================== Widgets =====================

class _PillTabBar extends StatelessWidget {
  final TabController controller;
  const _PillTabBar({required this.controller});

  static const _c1 = Color(0xFF6D5EF9);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
      ),
      child: TabBar(
        controller: controller,
        indicator: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        labelColor: _c1,
        unselectedLabelColor: Colors.white.withOpacity(0.9),
        labelStyle: const TextStyle(fontWeight: FontWeight.w900),
        tabs: const [
          Tab(text: "Users"),
          Tab(text: "Categories"),
          Tab(text: "Groups"),
        ],
      ),
    );
  }
}

class _GlassStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _GlassStatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.16),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.28)),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(color: Colors.white.withOpacity(0.85), fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
    );
  }
}

class _Appear extends StatelessWidget {
  final int index;
  final Widget child;
  const _Appear({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 280 + (index.clamp(0, 8) * 40)),
      curve: Curves.easeOutCubic,
      builder: (_, t, __) {
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 10),
            child: child,
          ),
        );
      },
    );
  }
}

class _UsersTabModern extends StatelessWidget {
  final List<Map<String, dynamic>> users;
  final Future<void> Function(String id) onLock;
  final Future<void> Function(String id) onUnlock;
  final Future<void> Function(String id) onDelete;

  const _UsersTabModern({
    required this.users,
    required this.onLock,
    required this.onUnlock,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: const [
          SizedBox(height: 40),
          Center(child: Text("Không có người dùng", style: TextStyle(fontWeight: FontWeight.w800))),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: users.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final u = users[i];
        final id = (u["_id"] ?? "").toString();
        final name = (u["name"] ?? "User").toString();
        final email = (u["email"] ?? "").toString();
        final locked = (u["locked"] == true) || (u["status"]?.toString() == "locked");
        final first = name.isNotEmpty ? name[0].toUpperCase() : "?";

        return _Appear(
          index: i,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.black.withOpacity(0.05)),
              boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 14, offset: Offset(0, 10))],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF6D5EF9), Color(0xFF9B5CF6)]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(first, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 3),
                      Text(email, style: TextStyle(color: Colors.black.withOpacity(0.55), fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      _MiniPill(
                        text: locked ? "LOCKED" : "ACTIVE",
                        color: locked ? const Color(0xFFFFEBEE) : const Color(0xFFE7F8EF),
                        textColor: locked ? const Color(0xFFB91C1C) : const Color(0xFF15803D),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: locked ? "Mở khóa" : "Khóa",
                  icon: Icon(locked ? Icons.lock_open_rounded : Icons.lock_rounded),
                  onPressed: () => locked ? onUnlock(id) : onLock(id),
                ),
                IconButton(
                  tooltip: "Xóa",
                  icon: const Icon(Icons.delete_rounded),
                  onPressed: () => onDelete(id),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CategoriesTabModern extends StatelessWidget {
  final List<Map<String, dynamic>> categories;
  final VoidCallback onAdd;
  final Future<void> Function(Map<String, dynamic> c) onEdit;
  final Future<void> Function(String id) onDelete;

  const _CategoriesTabModern({
    required this.categories,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: const [
          SizedBox(height: 40),
          Center(child: Text("Không có danh mục", style: TextStyle(fontWeight: FontWeight.w800))),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: categories.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final c = categories[i];
        final id = (c["_id"] ?? "").toString();
        final name = (c["name"] ?? "").toString();
        final type = (c["type"] ?? "").toString();
        final isExpense = type == "expense";

        return _Appear(
          index: i,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.black.withOpacity(0.05)),
              boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 14, offset: Offset(0, 10))],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F7FB),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.black.withOpacity(0.06)),
                  ),
                  child: Icon(isExpense ? Icons.payments_rounded : Icons.savings_rounded, color: Colors.black87),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 8),
                      _MiniPill(
                        text: isExpense ? "CHI TIÊU" : "THU NHẬP",
                        color: isExpense ? const Color(0xFFFFEBEE) : const Color(0xFFE7F8EF),
                        textColor: isExpense ? const Color(0xFFB91C1C) : const Color(0xFF15803D),
                      ),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.edit_rounded), onPressed: () => onEdit(c)),
                IconButton(icon: const Icon(Icons.delete_rounded), onPressed: () => onDelete(id)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _GroupsTabModern extends StatelessWidget {
  final List<Map<String, dynamic>> groups;
  final Future<void> Function(String groupId) onDelete;

  const _GroupsTabModern({required this.groups, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: const [
          SizedBox(height: 40),
          Center(child: Text("Không có nhóm", style: TextStyle(fontWeight: FontWeight.w800))),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: groups.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final g = groups[i];
        final id = (g["_id"] ?? g["id"] ?? "").toString();
        final name = (g["name"] ?? "Group").toString();

        return _Appear(
          index: i,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.black.withOpacity(0.05)),
              boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 14, offset: Offset(0, 10))],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black.withOpacity(0.08), Colors.black.withOpacity(0.03)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.black.withOpacity(0.06)),
                  ),
                  child: const Icon(Icons.groups_rounded),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text("ID: $id", style: TextStyle(color: Colors.black.withOpacity(0.55), fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.delete_rounded), onPressed: () => onDelete(id)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MiniPill extends StatelessWidget {
  final String text;
  final Color color;
  final Color textColor;

  const _MiniPill({
    required this.text,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: textColor)),
    );
  }
}
