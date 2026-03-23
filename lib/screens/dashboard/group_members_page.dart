import 'dart:async';
import 'package:flutter/material.dart';

import '../../services/group_api.dart';
import '../../services/dashboard_api.dart';

class GroupMembersPage extends StatefulWidget {
  final String groupId;
  final Future<String?> Function()? tokenProvider;

  const GroupMembersPage({
    super.key,
    required this.groupId,
    this.tokenProvider,
  });

  @override
  State<GroupMembersPage> createState() => _GroupMembersPageState();
}

class _GroupMembersPageState extends State<GroupMembersPage> {
  late final GroupApi api;
  final dashApi = DashboardApi();

  bool loading = true;
  String? error;

  Map<String, dynamic>? groupInfo;
  num balance = 0;
  num totalSpent = 0;

  String? currentUserId;

  bool get isLeader =>
      (groupInfo?["created_by"]?.toString() ?? "") == (currentUserId ?? "");

  List<_MemberSpent> members = [];

  @override
  void initState() {
    super.initState();
    api = GroupApi(tokenProvider: widget.tokenProvider);
    _load();
  }

  num _toNum(dynamic v) {
    if (v is num) return v;
    return num.tryParse((v ?? "0").toString()) ?? 0;
  }

  String _money(num n) => n.toStringAsFixed(0).replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (m) => ',',
  );

  void _toast(String s) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      // lấy userId hiện tại để check leader
      // nếu project bạn khác tên hàm -> sửa dòng này
      currentUserId = await dashApi.getUserId();

      final g = await api.fetchGroupInfo(widget.groupId);
      final b = await api.fetchActualBalance(widget.groupId);
      final m = await api.fetchMemberExpenses(widget.groupId);

      final memList = (m["members"] is List) ? (m["members"] as List) : <dynamic>[];
      final parsed = memList
          .whereType<Map>()
          .map((e) => _MemberSpent.fromJson(e.cast<String, dynamic>()))
          .toList();

      parsed.sort((a, b) => b.totalSpent.compareTo(a.totalSpent));

      if (!mounted) return;
      setState(() {
        groupInfo = g;
        balance = _toNum(b["balance"] ?? b["actualBalance"]);
        totalSpent = _toNum(b["totalSpent"] ?? b["spent"]);
        members = parsed;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  Future<void> _openAddMemberSheet() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddMemberSheet(
        tokenProvider: widget.tokenProvider,
        groupId: widget.groupId,
      ),
    );

    if (ok == true) {
      await _load();
      _toast("✅ Đã thêm thành viên");
    }
  }

  Future<void> _deleteGroup() async {
    final name = (groupInfo?["name"] ?? "nhóm").toString();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Xóa nhóm"),
        content: Text('Bạn chắc chắn muốn xóa nhóm "$name" không?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Hủy")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Xóa", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await api.deleteGroup(widget.groupId);
      if (!mounted) return;
      Navigator.pop(context, true);
      _toast("✅ Đã xóa nhóm");
    } catch (e) {
      if (!mounted) return;
      _toast("❌ ${e.toString()}");
    }
  }

  Future<void> _removeMember(_MemberSpent m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Xóa thành viên"),
        content: Text('Xóa "${m.name.isEmpty ? "Thành viên" : m.name}" khỏi nhóm?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Hủy")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Xóa", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await api.removeMember(widget.groupId, m.userId);
      await _load();
      _toast("✅ Đã xóa thành viên");
    } catch (e) {
      _toast("❌ ${e.toString()}");
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupName = (groupInfo?["name"] ?? "Nhóm").toString();
    final leaderId = groupInfo?["created_by"]?.toString() ?? "";

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FB),
      body: SafeArea(
        child: Column(
          children: [
            // HEADER
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF6D5EF9), Color(0xFF9B5CF6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
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
                      Expanded(
                        child: Text(
                          groupName,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (isLeader)
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                          onSelected: (v) {
                            if (v == "delete_group") _deleteGroup();
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: "delete_group",
                              child: Text("Xóa nhóm"),
                            ),
                          ],
                        )
                      else
                        const SizedBox(width: 44),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // Avatars preview
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: members.take(6).map((m) {
                      final isOwner = m.userId == leaderId;
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: isOwner ? const Color(0xFFFBBF24) : Colors.white70,
                                width: 2,
                              ),
                              boxShadow: const [
                                BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 6)),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              (m.name.isNotEmpty ? m.name[0].toUpperCase() : "?"),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                color: Color(0xFF6D5EF9),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            width: 74,
                            child: Text(
                              m.name.isEmpty ? "Không tên" : m.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                          ),
                          if (isOwner)
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Icon(Icons.emoji_events_rounded, size: 14, color: Color(0xFFFBBF24)),
                            ),
                        ],
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    "Số dư nhóm: ${loading ? "..." : "${_money(balance)} đ"}",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Tổng đã chi: ${loading ? "..." : "${_money(totalSpent)} đ"}",
                    style: TextStyle(color: Colors.white.withOpacity(0.85), fontWeight: FontWeight.w700, fontSize: 12),
                  ),

                  const SizedBox(height: 10),

                  if (isLeader)
                    ElevatedButton.icon(
                      onPressed: _openAddMemberSheet,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.15),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                        side: BorderSide(color: Colors.white.withOpacity(0.7)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 18),
                      label: const Text(
                        "Thêm thành viên",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                      ),
                    ),
                ],
              ),
            ),

            // BODY
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
                  boxShadow: [
                    BoxShadow(color: Colors.black12, blurRadius: 14, offset: Offset(0, -2)),
                  ],
                ),
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : error != null
                    ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(error!, style: const TextStyle(color: Colors.red)),
                  ),
                )
                    : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              "Danh sách thành viên",
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                            ),
                          ),
                          Text(
                            "${members.length} người",
                            style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      ...members.map((m) {
                        final isOwner = m.userId == leaderId;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F7FB),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.black.withOpacity(0.05)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: isOwner ? const Color(0xFFFBBF24) : Colors.white70,
                                    width: 2,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  (m.name.isNotEmpty ? m.name[0].toUpperCase() : "?"),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                    color: Color(0xFF6D5EF9),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            m.name.isEmpty ? "Không tên" : m.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontWeight: FontWeight.w900),
                                          ),
                                        ),
                                        if (isOwner)
                                          const Padding(
                                            padding: EdgeInsets.only(left: 6),
                                            child: Icon(Icons.emoji_events_rounded, size: 16, color: Color(0xFFFBBF24)),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      m.email.isEmpty ? "—" : m.email,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 10),

                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    "${_money(m.totalSpent)} đ",
                                    style: const TextStyle(fontWeight: FontWeight.w900),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    "Tổng chi",
                                    style: TextStyle(fontSize: 11, color: Colors.black45, fontWeight: FontWeight.w700),
                                  ),

                                  if (isLeader && !isOwner) ...[
                                    const SizedBox(height: 6),
                                    InkWell(
                                      onTap: () => _removeMember(m),
                                      child: const Text(
                                        "Xóa",
                                        style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w900),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        );
                      }).toList(),

                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberSpent {
  final String userId;
  final String name;
  final String email;
  final num totalSpent;

  _MemberSpent({
    required this.userId,
    required this.name,
    required this.email,
    required this.totalSpent,
  });

  factory _MemberSpent.fromJson(Map<String, dynamic> j) {
    final id = (j["user_id"] ?? j["userId"] ?? j["_id"] ?? "").toString();
    return _MemberSpent(
      userId: id,
      name: (j["name"] ?? "").toString(),
      email: (j["email"] ?? "").toString(),
      totalSpent: (j["totalSpent"] is num)
          ? (j["totalSpent"] as num)
          : num.tryParse((j["totalSpent"] ?? "0").toString()) ?? 0,
    );
  }
}

class _AddMemberSheet extends StatefulWidget {
  final String groupId;
  final Future<String?> Function()? tokenProvider;

  const _AddMemberSheet({
    required this.groupId,
    this.tokenProvider,
  });

  @override
  State<_AddMemberSheet> createState() => _AddMemberSheetState();
}

class _AddMemberSheetState extends State<_AddMemberSheet> {
  late final GroupApi api;

  final ctrl = TextEditingController();
  Timer? _debounce;

  bool loading = false;
  String? error;

  List<dynamic> suggestions = [];

  @override
  void initState() {
    super.initState();
    api = GroupApi(tokenProvider: widget.tokenProvider);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final q = v.trim();
      if (q.isEmpty) {
        if (!mounted) return;
        setState(() => suggestions = []);
        return;
      }
      try {
        final res = await api.searchUsers(q);
        if (!mounted) return;
        setState(() => suggestions = res);
      } catch (_) {
        // ignore
      }
    });
  }

  Future<void> _submit() async {
    final email = ctrl.text.trim();
    if (email.isEmpty) {
      setState(() => error = "Nhập email thành viên");
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });

    try {
      await api.addMemberByEmail(widget.groupId, email);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        padding: EdgeInsets.only(bottom: bottom),
        decoration: const BoxDecoration(color: Colors.transparent),
        child: Center(
          child: Container(
            width: 520,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 18, offset: Offset(0, 10)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        "Thêm thành viên",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context, false),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: ctrl,
                  onChanged: _onChanged,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: "Email thành viên",
                    hintText: "Nhập email...",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),

                if (suggestions.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 220),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F7FB),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.black.withOpacity(0.06)),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: suggestions.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: Colors.black.withOpacity(0.06)),
                      itemBuilder: (_, i) {
                        final u = suggestions[i];
                        final name = (u["name"] ?? "Không tên").toString();
                        final email = (u["email"] ?? "").toString();
                        return ListTile(
                          onTap: () {
                            ctrl.text = email;
                            setState(() => suggestions = []);
                          },
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF6D5EF9),
                            foregroundColor: Colors.white,
                            child: Text(name.isNotEmpty ? name[0].toUpperCase() : "?"),
                          ),
                          title: Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
                          subtitle: Text(email),
                        );
                      },
                    ),
                  ),
                ],

                const SizedBox(height: 10),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(error!, style: const TextStyle(color: Colors.red)),
                  ),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6D5EF9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      loading ? "Đang thêm..." : "Thêm",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
