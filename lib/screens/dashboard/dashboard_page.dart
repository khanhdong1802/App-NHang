import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../services/dashboard_api.dart';
import '../../services/auth_service.dart';
import '../../models/category.dart';
import '../../models/transaction_item.dart';
import 'widgets/dashboard_header.dart';
import 'widgets/category_grid.dart';
import 'widgets/stats_cards.dart';
import 'widgets/tx_recent_list.dart';
import 'widgets/floating_fab.dart';
import 'widgets/dashboard_drawer.dart';
import 'modals/income_modal.dart';
import 'modals/record_modal.dart';
import 'create_room_page.dart';
import 'group_room_page.dart';
import 'transaction_history_page.dart';
import 'stats_page.dart';
import 'settings_page.dart';

import '../dashboard/admin_page.dart';
import 'package:doanmonhoc/providers/chat_provider.dart';
import 'package:provider/provider.dart';
import 'chatbot_screen.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final api = DashboardApi();
  final auth = AuthService();

  // đọc flag admin từ secure storage (đúng với AuthService.login() của bạn)
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  bool loading = true;

  Map<String, dynamic>? user;
  num balance = 0;
  num totalSpent = 0;
  num spendingLimit = 0;

  List<Map<String, dynamic>> rooms = [];
  List<Map<String, dynamic>> notifications = [];

  List<Category> categories = [];
  List<TransactionItem> txs = [];

  int visibleCount = 5;
  final int initialVisibleCount = 5;
  final int incrementCount = 10;

  bool _isAdminFlag = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<bool> _readIsAdminFromStorage() async {
    final v = await _storage.read(key: "isAdmin");
    return v == "true";
  }

  bool get isAdmin {
    // Ưu tiên flag đã lưu
    if (_isAdminFlag) return true;

    // fallback: check theo email giống AuthService.login()
    final email = (user?["email"] ?? "").toString().toLowerCase().trim();
    if (email == "admin@gmail.com") return true;

    // fallback nữa: nếu backend có trả role
    final role = (user?["role"] ?? "").toString().toLowerCase().trim();
    if (role == "admin") return true;

    return false;
  }

  Future<void> _loadAll() async {
    setState(() => loading = true);

    try {
      final fetchedUser = await auth.getUserFromStorage();
      final userId = fetchedUser?['_id']?.toString();

      if (userId == null || userId.isEmpty) {
        if (mounted) Navigator.pushReplacementNamed(context, "/login");
        return;
      }

      final adminFlag = await _readIsAdminFromStorage();

      final results = await Future.wait([
        api.fetchBalance(userId),
        api.fetchTotalSpent(userId),
        api.fetchSpendingLimit(userId),
        api.fetchRooms(userId),
        api.fetchNotifications(userId),
        api.fetchCategories(),
        api.fetchTransactionsForCurrentUser(
          tokenProvider: () => auth.getToken(),
        ),
      ]);

      if (!mounted) return;

      setState(() {
        user = fetchedUser;
        _isAdminFlag = adminFlag;

        balance = results[0] as num;
        totalSpent = results[1] as num;
        spendingLimit = results[2] as num;

        rooms = results[3] as List<Map<String, dynamic>>;
        notifications = results[4] as List<Map<String, dynamic>>;

        categories = results[5] as List<Category>;
        txs = results[6] as List<TransactionItem>;

        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Lỗi tải dashboard: ${e.toString()}")),
      );
    }
  }

  Future<void> _loadRooms() async {
    final userId = await api.getUserId();
    if (userId == null || !mounted) return;

    final freshRooms = await api.fetchRooms(userId);
    if (mounted) {
      setState(() => rooms = freshRooms);
    }
  }

  void _openCreateRoom() async {
    Navigator.pop(context);

    final userId = await api.getUserId();
    if (userId == null || !mounted) return;

    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateRoomPage(
          createdBy: userId,
          tokenProvider: () => auth.getToken(),
        ),
      ),
    );

    if (!mounted) return;

    if (ok == true) {
      await _loadRooms();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✅ Đã tạo nhóm & gửi lời mời (nếu có email)."),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  int get monthPercent {
    if (spendingLimit <= 0) return 0;
    final p = (totalSpent / spendingLimit) * 100;
    return p.isFinite ? p.round() : 0;
  }

  void _toast(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  void _goSettings() async {
    Navigator.pop(context); // đóng drawer trước
    if (user == null || !mounted) return;

    final updatedUser = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsPage(
          tokenProvider: () => auth.getToken(),
          user: user!,
        ),
      ),
    );

    if (updatedUser != null && mounted) {
      setState(() {
        user = Map<String, dynamic>.from(updatedUser);
      });
    }
  }

  void _goAdmin() async {
    Navigator.pop(context); // đóng drawer trước
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminPage(
          tokenProvider: () => auth.getToken(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: DashboardDrawer(
        rooms: rooms,

        // ✅ Admin menu (ẩn/hiện theo isAdmin)
        onGoAdmin: _goAdmin,
        showAdmin: isAdmin,

        onGoStats: () async {
          Navigator.pop(context);
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StatsPage(
                rooms: rooms,
                tokenProvider: () => auth.getToken(),
              ),
            ),
          );
        },
        onGoSettings: _goSettings,

        onGoPersonal: () => Navigator.pop(context),

        onGoHistory: () async {
          Navigator.pop(context);
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TransactionHistoryPage(
                tokenProvider: () => auth.getToken(),
              ),
            ),
          );
        },

        onGoRoom: (roomId) async {
          Navigator.pop(context);
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GroupRoomPage(
                groupId: roomId,
                tokenProvider: () => auth.getToken(),
              ),
            ),
          );
        },

        onCreateRoom: _openCreateRoom,

        onLogout: () async {
          // đóng drawer trước cho đẹp (optional)
          Navigator.of(context).pop();

          context.read<ChatProvider>().forceDisconnect();
          await context.read<AuthService>().logout();

          if (!context.mounted) return;
          Navigator.pushNamedAndRemoveUntil(context, "/login", (r) => false);
        },

      ),
      backgroundColor: const Color(0xFFF6F7FB),
      floatingActionButton: FloatingFab(
        onExpense: () => _toast("Mở Chi tiêu (ExpenseModal)"),
        onIncome: () async {
          final ok = await IncomeModal.open(context);
          if (ok == true) _loadAll();
        },
        onTransfer: () => _toast("Mở Chuyển khoản (TransferModal)"),
        onNote: () async {
          final ok = await RecordModal.open(context);
          if (ok == true) _loadAll();
        },
        onLimit: () => _toast("Mở Thiết lập hạn mức"),
        onChatbot: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ChatbotScreen()),
          );
        },
      ),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DashboardHeader(
              userName: user?['name']?.toString() ?? "Người dùng",
              avatarUrl: user?['avatar']?.toString(),
              balance: balance,
              totalSpent: totalSpent,
              spendingLimit: spendingLimit,
              monthPercent: monthPercent,
              notifications: notifications,
              loading: loading,
              onToggleNoti: () {},
              onAcceptInvite: (notiId) async {
                final userId = await api.getUserId();
                if (userId == null) return;

                final ok = await api.acceptInvite(notiId, userId);
                if (ok) {
                  _toast("Đã chấp nhận");
                  await _loadRooms();
                  setState(() {
                    notifications.removeWhere((n) => n["_id"] == notiId);
                  });
                }
              },
              onRejectInvite: (notiId) async {
                final ok = await api.rejectInvite(notiId);
                if (ok) {
                  _toast("Đã từ chối");
                  setState(() => notifications.removeWhere((n) => n["_id"] == notiId));
                }
              },
            ),
            const SizedBox(height: 14),

            CategoryGrid(
              categories: categories,
              onChanged: _loadAll,
              onTap: (cat) async {
                final ok = await RecordModal.open(
                  context,
                  selectedCategoryId: cat.id,
                );
                if (ok == true) _loadAll();
              },
            ),
            const SizedBox(height: 14),

            StatsCards(userIdProvider: api.getUserId),
            const SizedBox(height: 4),

            TxRecentList(
              txs: txs,
              onViewAll: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TransactionHistoryPage(),
                  ),
                );
              },
            ),

            const SizedBox(height: 70),
          ],
        ),
      ),
    );
  }
}
