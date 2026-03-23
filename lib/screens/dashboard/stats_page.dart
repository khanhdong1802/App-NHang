import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../models/category.dart';
import '../../models/transaction_item.dart';
import '../../services/auth_service.dart';
import '../../services/dashboard_api.dart';

class StatsPage extends StatefulWidget {
  final List<Map<String, dynamic>> rooms;
  final Future<String?> Function() tokenProvider;

  const StatsPage({
    super.key,
    required this.rooms,
    required this.tokenProvider,
  });

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  final api = DashboardApi();
  final auth = AuthService();

  bool loading = true;
  String? error;

  String mainTab = "Cá nhân"; // Cá nhân | Nhóm
  String tab = "Danh mục"; // Danh mục | Biểu đồ

  String? userId;
  String? selectedGroupId;

  List<TransactionItem> txs = [];
  List<Category> categories = [];

  DateTime now = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.rooms.isNotEmpty) {
      final id = (widget.rooms.first["_id"] ?? "").toString();
      selectedGroupId = id.isEmpty ? null : id;
    }
    _load();
  }

  String _yyyyMM(DateTime d) => DateFormat("yyyy-MM").format(d);
  String _yyyyMMdd(DateTime d) => DateFormat("yyyy-MM-dd").format(d);

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
      now = DateTime.now();
    });

    try {
      userId = await api.getUserId();
      if (userId == null || userId!.isEmpty) {
        if (mounted) Navigator.pushReplacementNamed(context, "/login");
        return;
      }

      final lastMonth = DateTime(now.year, now.month - 1, 1);

      final categoriesFuture = api.fetchCategories();
      final personalTxFuture = api.fetchTransactionsByUserId(
        userId!,
        tokenProvider: widget.tokenProvider,
      );

      Future<List<TransactionItem>> thisMonthGroupFuture() async {
        if (selectedGroupId == null || selectedGroupId!.isEmpty) return [];
        return api.fetchGroupTransactionsByMonth(
          groupId: selectedGroupId!,
          month: now.month,
          year: now.year,
          tokenProvider: widget.tokenProvider,
        );
      }

      Future<List<TransactionItem>> lastMonthGroupFuture() async {
        if (selectedGroupId == null || selectedGroupId!.isEmpty) return [];
        return api.fetchGroupTransactionsByMonth(
          groupId: selectedGroupId!,
          month: lastMonth.month,
          year: lastMonth.year,
          tokenProvider: widget.tokenProvider,
        );
      }

      final results = await Future.wait([
        categoriesFuture,
        personalTxFuture,
        thisMonthGroupFuture(),
        lastMonthGroupFuture(),
      ]);

      categories = results[0] as List<Category>;

      final personalTxs = results[1] as List<TransactionItem>;
      final thisMonthGroupTxs = results[2] as List<TransactionItem>;
      final lastMonthGroupTxs = results[3] as List<TransactionItem>;

      final mergedGroupTxs = <TransactionItem>[
        ...thisMonthGroupTxs,
        ...lastMonthGroupTxs,
      ];

      final seenIds = <String>{};
      txs = [
        ...personalTxs,
        ...mergedGroupTxs,
      ].where((e) => seenIds.add(e.id)).toList();

      if (!mounted) return;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  // =========================
  // FILTERS
  // =========================

  bool _isGroupTx(TransactionItem t) => (t.groupId ?? "").isNotEmpty;

  bool _matchSelectedGroup(TransactionItem t) {
    if (!_isGroupTx(t)) return false;
    if (selectedGroupId == null || selectedGroupId!.isEmpty) return true;
    return t.groupId == selectedGroupId;
  }

  bool _isPersonalExpense(TransactionItem t) {
    final type = t.transactionType.toLowerCase().trim();
    return !_isGroupTx(t) && (type == "expense" || type == "withdraw");
  }

  bool _isPersonalIncome(TransactionItem t) {
    final type = t.transactionType.toLowerCase().trim();
    return !_isGroupTx(t) && type == "income";
  }

  bool _isGroupExpense(TransactionItem t) {
    final type = t.transactionType.toLowerCase().trim();
    return _matchSelectedGroup(t) &&
        (type == "groupexpense" ||
            type == "group_expense" ||
            type == "group expense");
  }

  bool _isGroupContribution(TransactionItem t) {
    final type = t.transactionType.toLowerCase().trim();
    return _matchSelectedGroup(t) && type == "contribution";
  }

  // =========================
  // KPI
  // =========================

  num get totalToday {
    final today = now;
    return txs.where((t) {
      final d = t.transactionDate;
      if (d == null || !_isSameDay(d, today)) return false;
      return mainTab == "Cá nhân"
          ? _isPersonalExpense(t)
          : _isGroupExpense(t);
    }).fold<num>(0, (s, t) => s + t.amount);
  }

  num _totalMonth(DateTime month) {
    final ym = _yyyyMM(month);
    return txs.where((t) {
      final d = t.transactionDate;
      if (d == null) return false;
      if (_yyyyMM(d) != ym) return false;
      return mainTab == "Cá nhân"
          ? _isPersonalExpense(t)
          : _isGroupExpense(t);
    }).fold<num>(0, (s, t) => s + t.amount);
  }

  num get totalThisMonth => _totalMonth(now);

  num get totalLastMonth => _totalMonth(
    DateTime(now.year, now.month - 1, 1),
  );

  // =========================
  // LINE CHART
  // =========================

  List<_Point> get dayPoints {
    final todayStr = _yyyyMMdd(now);

    final filtered = txs.where((t) {
      final d = t.transactionDate;
      if (d == null) return false;
      if (_yyyyMMdd(d) != todayStr) return false;

      if (mainTab == "Cá nhân") {
        return _isPersonalIncome(t) || _isPersonalExpense(t);
      } else {
        return _isGroupContribution(t) || _isGroupExpense(t);
      }
    }).toList()
      ..sort(
            (a, b) => (a.transactionDate ?? DateTime(0)).compareTo(
          b.transactionDate ?? DateTime(0),
        ),
      );

    num balance = 0;
    final pts = <_Point>[const _Point(label: "Đầu ngày", value: 0)];

    for (final t in filtered) {
      final type = t.transactionType.toLowerCase().trim();
      num change = 0;

      if (mainTab == "Cá nhân") {
        if (type == "income") change = t.amount;
        if (type == "expense" || type == "withdraw") change = -t.amount;
      } else {
        if (type == "contribution") change = t.amount;
        if (type == "groupexpense") change = -t.amount;
      }

      if (change != 0) {
        balance += change;
        pts.add(
          _Point(
            label: DateFormat("HH:mm").format(t.transactionDate!),
            value: balance.toDouble(),
          ),
        );
      }
    }

    return pts.length <= 1 ? [] : pts;
  }

  // =========================
  // CATEGORY SPEND
  // =========================

  List<_CatSpent> _categorySpentFor({
    required bool forToday,
    required DateTime month,
  }) {
    final map = <String, num>{};

    for (final t in txs) {
      final d = t.transactionDate;
      if (d == null) continue;

      if (forToday) {
        if (!_isSameDay(d, now)) continue;
      } else {
        if (_yyyyMM(d) != _yyyyMM(month)) continue;
      }

      final ok = mainTab == "Cá nhân"
          ? _isPersonalExpense(t)
          : _isGroupExpense(t);

      if (!ok) continue;

      final cid = (t.categoryId ?? "").trim();
      if (cid.isEmpty) continue;

      map[cid] = (map[cid] ?? 0) + t.amount;
    }

    final out = <_CatSpent>[];

    for (final c in categories) {
      final spent = map[c.id] ?? 0;
      if (spent > 0) {
        out.add(_CatSpent(category: c, spent: spent));
      }
    }

    out.sort((a, b) => b.spent.compareTo(a.spent));
    return out;
  }

  bool get _shouldUseMonthlyGroupSpend {
    if (mainTab != "Nhóm") return false;
    final todayList = _categorySpentFor(forToday: true, month: now);
    return todayList.isEmpty;
  }

  List<_CatSpent> get currentSpendList {
    if (mainTab == "Nhóm" && _shouldUseMonthlyGroupSpend) {
      return _categorySpentFor(forToday: false, month: now);
    }
    return _categorySpentFor(forToday: true, month: now);
  }

  num get currentSpendTotal {
    return currentSpendList.fold<num>(0, (s, e) => s + e.spent);
  }

  String get currentSpendTitle {
    if (mainTab == "Nhóm" && _shouldUseMonthlyGroupSpend) {
      return "Chi tiêu tháng này theo danh mục";
    }
    return "Chi tiêu hôm nay theo danh mục";
  }

  // =========================
  // PIE CHART
  // =========================

  Map<String, num> _monthSummary(DateTime month) {
    final ym = _yyyyMM(month);
    final map = <String, num>{};

    for (final t in txs) {
      final d = t.transactionDate;
      if (d == null) continue;
      if (_yyyyMM(d) != ym) continue;

      final ok = mainTab == "Cá nhân"
          ? _isPersonalExpense(t)
          : _isGroupExpense(t);

      if (!ok) continue;

      final cid = (t.categoryId ?? "").trim();
      if (cid.isEmpty) continue;

      map[cid] = (map[cid] ?? 0) + t.amount;
    }

    return map;
  }

  List<PieChartSectionData> _pieSections(Map<String, num> summary) {
    final total = summary.values.fold<num>(0, (s, v) => s + v);
    if (total <= 0) return [];

    final entries = summary.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final top = entries.take(6).toList();
    final rest = entries.skip(6).fold<num>(0, (s, e) => s + e.value);

    final sections = <PieChartSectionData>[];
    final palette = [
      const Color(0xFF60A5FA),
      const Color(0xFF1D4ED8),
      const Color(0xFFF59E0B),
      const Color(0xFFEF4444),
      const Color(0xFFA78BFA),
      const Color(0xFFF472B6),
      const Color(0xFF10B981),
    ];

    int i = 0;
    for (final e in top) {
      final percent = (e.value / total) * 100;
      sections.add(
        PieChartSectionData(
          value: e.value.toDouble(),
          color: palette[i % palette.length],
          radius: 60,
          title: "${percent.toStringAsFixed(0)}%",
          titleStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      );
      i++;
    }

    if (rest > 0) {
      sections.add(
        PieChartSectionData(
          value: rest.toDouble(),
          color: palette[i % palette.length],
          radius: 60,
          title: "${(rest / total * 100).toStringAsFixed(0)}%",
          titleStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      );
    }

    return sections;
  }

  // =========================
  // UI HELPERS
  // =========================

  String _money(num n) {
    final s = n.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (m) => ',',
    );
    return "$s đ";
  }

  Color _pillColor() =>
      mainTab == "Cá nhân" ? const Color(0xFF6D5EF9) : const Color(0xFF2563EB);

  Widget _seg2(
      String a,
      String b,
      String current,
      void Function(String) onChanged,
      ) {
    final items = [a, b];
    return Container(
      height: 42,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: items.map((it) {
          final active = current == it;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(it),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active
                      ? _pillColor().withOpacity(0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  it,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: active ? _pillColor() : Colors.black54,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _kpiCard(String title, String value, String sub) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.black54,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            sub,
            style: TextStyle(
              fontSize: 11,
              color: _pillColor(),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _lineChart() {
    final pts = dayPoints;

    if (pts.isEmpty) {
      return Container(
        height: 180,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7FB),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Text(
          mainTab == "Nhóm"
              ? "Hôm nay nhóm chưa có biến động quỹ."
              : "Hôm nay chưa có biến động số dư.",
          style: const TextStyle(
            color: Colors.black45,
            fontWeight: FontWeight.w800,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    final spots = <FlSpot>[];
    for (int i = 0; i < pts.length; i++) {
      spots.add(FlSpot(i.toDouble(), pts[i].value));
    }

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: (pts.length / 4).clamp(1, 999).toDouble(),
                getTitlesWidget: (v, meta) {
                  final idx = v.toInt();
                  if (idx < 0 || idx >= pts.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      pts[idx].label,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.black54,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              isCurved: true,
              barWidth: 3,
              color: _pillColor(),
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: _pillColor().withOpacity(0.14),
              ),
              spots: spots,
            ),
          ],
        ),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  Widget _spendList(List<_CatSpent> list, num total) {
    if (list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            mainTab == "Nhóm"
                ? "Nhóm chưa có khoản chi phù hợp để thống kê."
                : "Không có dữ liệu chi tiêu hôm nay.",
            style: const TextStyle(
              color: Colors.black45,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );
    }

    return Column(
      children: list.map((it) {
        final percent = total > 0 ? (it.spent / total) : 0.0;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.black.withOpacity(0.05)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F7FB),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      it.category.icon ?? "📁",
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          it.category.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Dự chi: ${it.category.limit != null ? _money(it.category.limit!) : "Không giới hạn"}",
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black54,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    "-${_money(it.spent)}",
                    style: const TextStyle(
                      color: Color(0xFFEF4444),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: percent.clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: const Color(0xFFEFEFF7),
                  valueColor: AlwaysStoppedAnimation<Color>(_pillColor()),
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  "${(percent * 100).toStringAsFixed(0)}%",
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.black45,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _pieBox(String title, DateTime month) {
    final summary = _monthSummary(month);
    final total = summary.values.fold<num>(0, (s, v) => s + v);
    final sections = _pieSections(summary);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(
            _money(total),
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: sections.isEmpty
                ? const Center(
              child: Text(
                "Không có dữ liệu",
                style: TextStyle(
                  color: Colors.black45,
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
                : PieChart(
              PieChartData(
                sections: sections,
                sectionsSpace: 2,
                centerSpaceRadius: 36,
              ),
              swapAnimationDuration: const Duration(milliseconds: 700),
              swapAnimationCurve: Curves.easeOutCubic,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lastMonth = DateTime(now.year, now.month - 1, 1);
    final spendList = currentSpendList;
    final spendTotal = currentSpendTotal;
    final spendTitle = currentSpendTitle;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF6D5EF9), Color(0xFF9B5CF6)],
                ),
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
                        child: Column(
                          children: [
                            Text(
                              "Trung tâm thống kê",
                              style: TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              "Thống kê",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _load,
                        icon: const Icon(
                          Icons.refresh_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  _seg2("Cá nhân", "Nhóm", mainTab, (v) {
                    setState(() {
                      mainTab = v;
                      tab = "Danh mục";
                    });
                  }),

                  if (mainTab == "Nhóm" && widget.rooms.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.35),
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedGroupId,
                            isExpanded: true,
                            dropdownColor: const Color(0xFF6D5EF9),
                            iconEnabledColor: Colors.white,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                            items: widget.rooms.map((r) {
                              final id = (r["_id"] ?? "").toString();
                              final name = (r["name"] ?? "Room").toString();
                              return DropdownMenuItem<String>(
                                value: id,
                                child: Text(
                                  name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (v) {
                              setState(() => selectedGroupId = v);
                            },
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: _kpiCard("Hôm nay", _money(totalToday), mainTab),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _kpiCard(
                          "Tháng này",
                          _money(totalThisMonth),
                          "${now.month}/${now.year}",
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _kpiCard(
                          "Tháng trước",
                          _money(totalLastMonth),
                          "${lastMonth.month}/${lastMonth.year}",
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : error != null
                  ? Center(
                child: Text(
                  error!,
                  style: const TextStyle(color: Colors.red),
                ),
              )
                  : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: Colors.black.withOpacity(0.05),
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 12,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            mainTab == "Cá nhân"
                                ? "Biến động số dư cá nhân hôm nay"
                                : "Biến động quỹ nhóm hôm nay",
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            "Theo thời gian trong ngày",
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _lineChart(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: Colors.black.withOpacity(0.05),
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 12,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _seg2("Danh mục", "Biểu đồ", tab, (v) {
                            setState(() => tab = v);
                          }),
                          const SizedBox(height: 14),
                          if (tab == "Danh mục") ...[
                            if (mainTab == "Nhóm" &&
                                _shouldUseMonthlyGroupSpend)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 10),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    "Hôm nay nhóm chưa có khoản chi, đang hiển thị thống kê tháng này.",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.black54,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    spendTitle,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                Text(
                                  _money(spendTotal),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: _pillColor(),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _spendList(spendList, spendTotal),
                          ] else ...[
                            _pieBox(
                              "Tháng này (${now.month}/${now.year})",
                              now,
                            ),
                            const SizedBox(height: 12),
                            _pieBox(
                              "Tháng trước (${lastMonth.month}/${lastMonth.year})",
                              lastMonth,
                            ),
                          ],
                        ],
                      ),
                    ),
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

class _Point {
  final String label;
  final double value;

  const _Point({
    required this.label,
    required this.value,
  });
}

class _CatSpent {
  final Category category;
  final num spent;

  const _CatSpent({
    required this.category,
    required this.spent,
  });
}