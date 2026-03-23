import 'package:flutter/material.dart';
import '../../models/category.dart';
import 'modals/group_transaction.dart';
import '../../services/group_api.dart';
import 'widgets/category_grid.dart';
import 'widgets/floating_fab.dart';
import 'modals/income_modal.dart';
import 'modals/record_modal.dart';
import 'group_members_page.dart';
import '../dashboard/group_chat_screen.dart';
import 'group_transaction_history_page.dart';
class GroupRoomPage extends StatefulWidget {
  final String groupId;
  final Future<String?> Function()? tokenProvider;

  const GroupRoomPage({
    super.key,
    required this.groupId,
    this.tokenProvider,
  });

  @override
  State<GroupRoomPage> createState() => _GroupRoomPageState();
}

class _GroupRoomPageState extends State<GroupRoomPage> {
  late final GroupApi api;

  bool loading = true;
  String? error;

  Map<String, dynamic>? groupInfo;
  num balance = 0;
  num totalSpent = 0;

  List<Category> categories = [];
  List<GroupTransaction> txs = [];



  @override
  void initState() {
    super.initState();
    api = GroupApi(tokenProvider: widget.tokenProvider);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final g = await api.fetchGroupInfo(widget.groupId);
      final b = await api.fetchActualBalance(widget.groupId);
      final c = await api.fetchCategories();
      final t = await api.fetchGroupTransactions(widget.groupId);

      if (!mounted) return;

      setState(() {
        groupInfo = g;
        balance = (b["balance"] is num) ? b["balance"] : num.tryParse((b["balance"] ?? "0").toString()) ?? 0;
        totalSpent = (b["totalSpent"] is num) ? b["totalSpent"] : num.tryParse((b["totalSpent"] ?? "0").toString()) ?? 0;
        categories = c;
        txs = t;

      });
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  String _money(num n) => n.toStringAsFixed(0).replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (m) => ',',
  );

  String _dateVN(DateTime? d) {
    if (d == null) return "";
    return "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}";
  }

  static const txLabel = {
    "expense": "Chi tiêu nhóm",
    "groupExpense": "Chi tiêu nhóm",
    "contribution": "Đóng góp vào quỹ",
    "income": "Nạp vào quỹ",
    "withdraw": "Rút tiền",
  };

  static const statusLabel = {
    "completed": "Hoàn thành",
    "approved": "Đã duyệt",
    "pending": "Đang xử lý",
    "rejected": "Từ chối",
    "failed": "Thất bại",
  };

  bool _isIncrease(String type) => type == "income" || type == "contribution";

  void _toast(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  Future<void> _openRecordModal({String? categoryId}) async {
    final ok = await RecordModal.open(
      context,
      groupId: widget.groupId,
      selectedCategoryId: categoryId,
    );
    if (ok == true) {
      _load();
    }
  }

  Future<void> _openIncomeModal() async {
    final ok = await IncomeModal.open(
      context,
      groupId: widget.groupId,
    );
    if (ok == true) {
      _load();
    }
  }
  void _openGroupHistoryPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupTransactionHistoryPage(
          groupId: widget.groupId,
          groupName: (groupInfo?["name"] ?? "").toString(),
          tokenProvider: widget.tokenProvider,
        ),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    final name = (groupInfo?["name"] ?? "Tên nhóm").toString();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      floatingActionButton: FloatingFab(
        onExpense: () => _openRecordModal(),
        onIncome: () => _openIncomeModal(),
        onTransfer: () => _toast("Chức năng này không áp dụng cho nhóm"),
        onNote: () => _toast("Chức năng này không áp dụng cho nhóm"),
        onLimit: () => _toast("Chức năng này không áp dụng cho nhóm"),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFF6D5EF9), Color(0xFF9B5CF6)]),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          InkWell(
                            onTap: () => Navigator.pop(context),
                            borderRadius: BorderRadius.circular(14),
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(Icons.arrow_back_rounded, color: Colors.white),
                            ),
                          ),
                          const Spacer(),
                          HeaderIconButton(
                            icon: Icons.chat_rounded,
                            tooltip: "Chat nhóm",
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => GroupChatScreen(groupId: widget.groupId),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.14),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: Colors.white.withOpacity(0.2)),
                            ),
                            child: const Text(
                              "Quỹ nhóm",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => GroupMembersPage(
                                groupId: widget.groupId,
                                tokenProvider: widget.tokenProvider,
                              ),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 16),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _statCard("Đã chi", "${_money(totalSpent)} đ")),
                          const SizedBox(width: 10),
                          Expanded(child: _statCard("Số dư nhóm", loading ? "Đang tải..." : "${_money(balance)} đ")),
                        ],
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 10),
                        Text(error!, style: const TextStyle(color: Colors.white)),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text("Danh mục", style: TextStyle(fontWeight: FontWeight.w900)),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: loading
                  ? const Center(child: Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator()))
                  : CategoryGrid(
                      categories: categories,
                      onTap: (cat) => _openRecordModal(categoryId: cat.id),
                    ),
            ),

            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text("Lịch sử giao dịch nhóm", style: TextStyle(fontWeight: FontWeight.w900)),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildHistory(),
            ),
            const SizedBox(height: 90),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 12)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildHistory() {
    if (loading) {
      return Column(
        children: List.generate(
          3,
              (i) => Container(
            height: 78,
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
            ),
          ),
        ),
      );
    }

    if (txs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Text(
          "Nhóm chưa có giao dịch nào.\nChạm vào danh mục để thêm giao dịch mới.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w700),
        ),
      );
    }

    final preview = txs.take(5).toList();

    return Column(
      children: [
        ...preview.map(_txCard),
        const SizedBox(height: 10),
        if (txs.length > 5)
          TextButton(
            onPressed: _openGroupHistoryPage,
            child: const Text(
              "Xem thêm",
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
      ],
    );
  }

  Widget _txCard(GroupTransaction tx) {
    final isInc = _isIncrease(tx.transactionType);
    final sign = isInc ? "+" : "-";
    final title = txLabel[tx.transactionType] ?? "Giao dịch nhóm";
    final status = statusLabel[tx.status] ?? tx.status;

    final amountColor = isInc ? const Color(0xFF059669) : const Color(0xFFE11D48);
    final pillBg = isInc ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2);
    final pillText = isInc ? const Color(0xFF047857) : const Color(0xFFBE123C);

    final date = _dateVN(tx.transactionDate ?? tx.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 16, offset: Offset(0, 10))],
      ),      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isInc ? const [Color(0xFF34D399), Color(0xFF2DD4BF)] : const [Color(0xFFFB7185), Color(0xFFF472B6)],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Center(
              child: Text(sign, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(
                  "${date.isEmpty ? "" : date}${tx.description.isNotEmpty ? " • ${tx.description}" : ""}",
                  style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w600, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
                if (tx.userName != null && tx.userName!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Text("👤 ${tx.userName}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ]
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "$sign${_money(tx.amount.abs())} đ",
                style: TextStyle(fontWeight: FontWeight.w900, color: amountColor),
              ),
              if (status.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: pillBg,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: pillText.withOpacity(0.2)),
                  ),
                  child: Text(status, style: TextStyle(color: pillText, fontSize: 11, fontWeight: FontWeight.w800)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String? tooltip;
  final VoidCallback onTap;

  const HeaderIconButton({
    super.key,
    required this.icon,
    this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Tooltip(
        message: tooltip ?? '',
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }
}
