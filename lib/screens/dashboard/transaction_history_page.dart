import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/transaction_item.dart';
import '../../services/auth_service.dart';
import '../../services/dashboard_api.dart';

enum HistoryFilterMode { day, range, month, year }

class TransactionHistoryPage extends StatefulWidget {
  final Future<String?> Function()? tokenProvider;

  const TransactionHistoryPage({super.key, this.tokenProvider});

  @override
  State<TransactionHistoryPage> createState() => _TransactionHistoryPageState();
}

class _TransactionHistoryPageState extends State<TransactionHistoryPage> {
  final DashboardApi api = DashboardApi();
  final AuthService auth = AuthService();

  final TextEditingController _searchCtrl = TextEditingController();

  static const _c1 = Color(0xFF6D5EF9);
  static const _c2 = Color(0xFF9B5CF6);

  bool loading = true;
  String? error;

  HistoryFilterMode filterMode = HistoryFilterMode.day;

  DateTime selectedDate = DateTime.now();
  DateTimeRange? selectedRange;
  DateTime selectedMonth = DateTime.now();
  int selectedYear = DateTime.now().year;

  String selectedType = "Tất cả"; // local filter only
  String keyword = "";

  List<TransactionItem> rawTransactions = [];

  List<TransactionItem> get displayedTransactions {
    Iterable<TransactionItem> list = rawTransactions;

    if (selectedType != "Tất cả") {
      if (selectedType == "income") {
        list = list.where((e) => (e.transactionType ?? "") == "income");
      } else if (selectedType == "expense") {
        list = list.where((e) => _isExpenseType(e.transactionType ?? ""));
      }
    }

    final q = keyword.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((e) {
        final desc = (e.description ?? "").toLowerCase();
        final cate = (e.categoryName ?? "").toLowerCase();
        final group = (e.groupName ?? "").toLowerCase();
        final user = (e.userName ?? "").toLowerCase();
        final type = (e.transactionType ?? "").toLowerCase();

        return desc.contains(q) ||
            cate.contains(q) ||
            group.contains(q) ||
            user.contains(q) ||
            type.contains(q);
      });
    }

    return list.toList();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<String?> _getToken() async {
    final provider = widget.tokenProvider ?? () => auth.getToken();
    return provider();
  }

  String _fmtDate(DateTime d) => DateFormat("yyyy-MM-dd").format(d);
  String _fmtHeaderDate(DateTime d) => DateFormat("dd/MM/yyyy").format(d);
  String _fmtMonthYear(DateTime d) => DateFormat("MM/yyyy").format(d);

  bool _isExpenseType(String t) {
    return ["expense", "withdraw", "groupExpense", "contribution"]
        .contains(t);
  }

  String _money(num value) {
    final sign = value >= 0 ? "" : "-";
    final absValue = value.abs().toStringAsFixed(0);
    final formatted = absValue.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (m) => ",",
    );
    return "$sign$formatted đ";
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final tokenProvider = () => _getToken();

      List<TransactionItem> items = [];

      switch (filterMode) {
        case HistoryFilterMode.day:
          items = await api.fetchTransactionsByDate(
            date: _fmtDate(selectedDate),
            tokenProvider: tokenProvider,
          );
          break;

        case HistoryFilterMode.range:
          final range = selectedRange ??
              DateTimeRange(
                start: DateTime.now().subtract(const Duration(days: 7)),
                end: DateTime.now(),
              );

          items = await api.fetchTransactionsByRange(
            from: _fmtDate(range.start),
            to: _fmtDate(range.end),
            tokenProvider: tokenProvider,
          );
          break;

        case HistoryFilterMode.month:
          items = await api.fetchTransactionsByMonth(
            month: selectedMonth.month,
            year: selectedMonth.year,
            tokenProvider: tokenProvider,
          );
          break;

        case HistoryFilterMode.year:
          items = await api.fetchTransactionsByYear(
            year: selectedYear,
            tokenProvider: tokenProvider,
          );
          break;
      }

      if (!mounted) return;
      setState(() {
        rawTransactions = items;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString();
        rawTransactions = [];
      });
    } finally {
      if (!mounted) return;
      setState(() {
        loading = false;
      });
    }
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  void _changeDay(int delta) {
    setState(() {
      selectedDate = selectedDate.add(Duration(days: delta));
    });
    _load();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: _c1),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return;

    setState(() {
      selectedDate = picked;
    });
    _load();
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: selectedRange ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 7)),
            end: now,
          ),
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: _c1),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return;

    setState(() {
      selectedRange = picked;
    });
    _load();
  }

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    int tempMonth = selectedMonth.month;
    int tempYear = selectedMonth.year;

    final picked = await showDialog<DateTime>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Chọn tháng"),
          content: StatefulBuilder(
            builder: (context, setInnerState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButton<int>(
                    value: tempMonth,
                    isExpanded: true,
                    items: List.generate(
                      12,
                          (index) => DropdownMenuItem(
                        value: index + 1,
                        child: Text("Tháng ${index + 1}"),
                      ),
                    ),
                    onChanged: (v) {
                      if (v == null) return;
                      setInnerState(() => tempMonth = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButton<int>(
                    value: tempYear,
                    isExpanded: true,
                    items: List.generate(
                      10,
                          (index) {
                        final y = now.year - 5 + index;
                        return DropdownMenuItem(
                          value: y,
                          child: Text("$y"),
                        );
                      },
                    ),
                    onChanged: (v) {
                      if (v == null) return;
                      setInnerState(() => tempYear = v);
                    },
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Hủy"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, DateTime(tempYear, tempMonth)),
              child: const Text("Chọn"),
            ),
          ],
        );
      },
    );

    if (picked == null) return;

    setState(() {
      selectedMonth = picked;
    });
    _load();
  }

  Future<void> _pickYear() async {
    final now = DateTime.now();
    int tempYear = selectedYear;

    final picked = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Chọn năm"),
          content: DropdownButton<int>(
            value: tempYear,
            isExpanded: true,
            items: List.generate(
              12,
                  (index) {
                final y = now.year - 6 + index;
                return DropdownMenuItem(
                  value: y,
                  child: Text("$y"),
                );
              },
            ),
            onChanged: (v) {
              if (v == null) return;
              tempYear = v;
              (context as Element).markNeedsBuild();
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Hủy"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, tempYear),
              child: const Text("Chọn"),
            ),
          ],
        );
      },
    );

    if (picked == null) return;

    setState(() {
      selectedYear = picked;
    });
    _load();
  }

  Widget _iconGlassBtn({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: Colors.white.withOpacity(0.16),
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              width: 42,
              height: 42,
              child: Icon(icon, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  Widget _filterModeTabs() {
    final items = <(HistoryFilterMode, String)>[
      (HistoryFilterMode.day, "Ngày"),
      (HistoryFilterMode.range, "Khoảng"),
      (HistoryFilterMode.month, "Tháng"),
      (HistoryFilterMode.year, "Năm"),
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.24)),
      ),
      child: Row(
        children: items.map((item) {
          final active = filterMode == item.$1;
          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                setState(() {
                  filterMode = item.$1;
                });
                _load();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: active ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  item.$2,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: active ? const Color(0xFF4F46E5) : Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _timeFilterBar() {
    if (filterMode == HistoryFilterMode.day) {
      return GestureDetector(
        onHorizontalDragEnd: (d) {
          final v = d.primaryVelocity ?? 0;
          if (v > 220) _changeDay(-1);
          if (v < -220) _changeDay(1);
        },
        child: Row(
          children: [
            _iconGlassBtn(
              icon: Icons.chevron_left_rounded,
              onTap: () => _changeDay(-1),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _pickDate,
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.28)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month_rounded,
                          color: Colors.white, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _fmtHeaderDate(selectedDate),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Icon(Icons.keyboard_arrow_down_rounded,
                          color: Colors.white.withOpacity(0.95)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            _iconGlassBtn(
              icon: Icons.chevron_right_rounded,
              onTap: () => _changeDay(1),
            ),
          ],
        ),
      );
    }

    if (filterMode == HistoryFilterMode.range) {
      final text = selectedRange == null
          ? "Chọn khoảng thời gian"
          : "${_fmtHeaderDate(selectedRange!.start)} - ${_fmtHeaderDate(selectedRange!.end)}";

      return InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _pickRange,
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.16),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.28)),
          ),
          child: Row(
            children: [
              const Icon(Icons.date_range_rounded,
                  color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Icon(Icons.keyboard_arrow_down_rounded,
                  color: Colors.white.withOpacity(0.95)),
            ],
          ),
        ),
      );
    }

    if (filterMode == HistoryFilterMode.month) {
      return InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _pickMonth,
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.16),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.28)),
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_view_month_rounded,
                  color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _fmtMonthYear(selectedMonth),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Icon(Icons.keyboard_arrow_down_rounded,
                  color: Colors.white.withOpacity(0.95)),
            ],
          ),
        ),
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: _pickYear,
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.16),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.28)),
        ),
        child: Row(
          children: [
            const Icon(Icons.event_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "$selectedYear",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded,
                color: Colors.white.withOpacity(0.95)),
          ],
        ),
      ),
    );
  }

  Widget _filtersCard() {
    final tabsType = const ["Tất cả", "income", "expense"];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 14,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          /// SEARCH
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F3F8),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, color: Colors.black45),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (value) {
                        setState(() {
                          keyword = value;
                        });
                      },
                      decoration: const InputDecoration(
                        hintText: "Tìm...",
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  if (keyword.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _searchCtrl.clear();
                        setState(() => keyword = "");
                      },
                      child: const Icon(Icons.close_rounded, size: 18),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 10),

          /// TYPE FILTER
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F3F8),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: tabsType.map((it) {
                  final active = it == selectedType;

                  final label = switch (it) {
                    "income" => "Thu",
                    "expense" => "Chi",
                    _ => "Tất cả",
                  };

                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedType = it;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: active ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            color: active
                                ? const Color(0xFF4F46E5)
                                : Colors.black54,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _txItem(TransactionItem tx) {
    final type = tx.transactionType ?? "";
    final amount = tx.amount ?? 0;

    final isIncome = type == "income";
    final isExpense = _isExpenseType(type);

    final sign = isIncome ? "+" : (isExpense ? "-" : "");
    final amountText = "$sign${_money(amount.abs())}";

    final badge = isIncome ? "IN" : "OUT";
    final badgeBg = isIncome ? const Color(0xFFE7F8EF) : const Color(0xFFFFEBEE);
    final badgeFg = isIncome ? const Color(0xFF15803D) : const Color(0xFFB91C1C);
    final amtFg = isIncome ? const Color(0xFF15803D) : const Color(0xFFB91C1C);

    final title = tx.description?.trim().isNotEmpty == true
        ? tx.description!
        : (isIncome ? "Thu nhập" : "Chi tiêu");

    final timeText = tx.transactionDate != null
        ? DateFormat("HH:mm dd/MM/yyyy").format(tx.transactionDate!)
        : "";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 6))
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7FB),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black.withOpacity(0.05)),
            ),
            alignment: Alignment.center,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  color: badgeFg,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${tx.userName ?? "Bạn"} • ${tx.categoryName ?? title}",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (timeText.isNotEmpty) timeText,
                    if ((tx.groupName ?? "").isNotEmpty) tx.groupName!,
                  ].join(" • "),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if ((tx.categoryName ?? "").isNotEmpty)
                      _miniTag("📁 ${tx.categoryName}"),
                    if ((tx.groupName ?? "").isNotEmpty)
                      _miniTag("🏠 ${tx.groupName}"),
                    if (type.isNotEmpty) _miniTag(type),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            amountText,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 15,
              color: amtFg,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final countText = loading
        ? "Đang tải..."
        : "${displayedTransactions.length} giao dịch";

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [_c1, _c2]),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          "Lịch sử giao dịch",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _toast("Export Excel sẽ làm sau"),
                        icon: const Icon(
                          Icons.download_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _filterModeTabs(),
                  const SizedBox(height: 10),
                  _timeFilterBar(),
                  const SizedBox(height: 6),
                  Text(
                    countText,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF6F7FB),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                ),
                child: RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
                    children: [
                      _filtersCard(),
                      const SizedBox(height: 14),
                      if (loading)
                        const Padding(
                          padding: EdgeInsets.only(top: 40),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 40),
                          child: Center(
                            child: Text(
                              error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        )
                      else if (displayedTransactions.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 40),
                            child: Center(
                              child: Text(
                                "Không có giao dịch\nHãy thử đổi khoảng thời gian hoặc bộ lọc.",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          )
                        else
                          ...displayedTransactions.map(_txItem),
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