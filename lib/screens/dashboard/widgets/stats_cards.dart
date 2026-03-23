import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../../services/api_config.dart';

class StatsCards extends StatefulWidget {
  final Future<String?> Function() userIdProvider;
  final Future<String?> Function()? tokenProvider;

  const StatsCards({
    super.key,
    required this.userIdProvider,
    this.tokenProvider,
  });

  @override
  State<StatsCards> createState() => _StatsCardsState();
}

class _StatsCardsState extends State<StatsCards> {
  bool loading = false;
  String? error;
  Map<String, dynamic>? stats;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = await widget.userIdProvider();
    if (!mounted) return;

    if (userId == null || userId.isEmpty) {
      setState(() => error = "Không tìm thấy userId");
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final uri = Uri.parse(
        "${ApiConfig.baseUrl}${ApiConfig.apiPrefix}/auth/stats/overview/$userId",
      );

      final headers = <String, String>{
        "Accept": "application/json",
      };

      final token = await widget.tokenProvider?.call();
      if (token != null && token.isNotEmpty) {
        headers["Authorization"] = "Bearer $token";
      }

      final res = await http.get(uri, headers: headers);

      if (!mounted) return;

      if (!res.ok) {
        String message = "Không thể tải dữ liệu";
        try {
          final errData = jsonDecode(res.body);
          if (errData is Map && errData["message"] != null) {
            message = errData["message"].toString();
          }
        } catch (_) {}
        throw Exception(message);
      }

      final data = jsonDecode(res.body);
      if (data is! Map<String, dynamic>) {
        throw Exception("Dữ liệu phản hồi không hợp lệ");
      }

      final rawStats = data["stats"];
      if (data["success"] == true && rawStats is Map) {
        setState(() {
          stats = rawStats.cast<String, dynamic>();
        });
      } else {
        setState(() => error = data["message"]?.toString() ?? "Không có dữ liệu");
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString().replaceFirst("Exception: ", ""));
    } finally {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  num _num(dynamic v) {
    if (v is num) return v;
    return num.tryParse(v?.toString() ?? "") ?? 0;
  }

  double? _parsePercent(dynamic trend) {
    if (trend == null) return null;
    final s = trend.toString();
    final m = RegExp(r'[-+]?\d+(\.\d+)?').firstMatch(s);
    if (m == null) return null;
    return double.tryParse(m.group(0)!);
  }

  String _formatTrend(dynamic trend) {
    if (trend == null) return "—";

    if (trend is num) {
      final sign = trend > 0 ? "+" : "";
      return "$sign${trend.toStringAsFixed(trend % 1 == 0 ? 0 : 1)}%";
    }

    final p = _parsePercent(trend);
    if (p == null) return trend.toString();

    final sign = p > 0 ? "+" : "";
    return "$sign${p.toStringAsFixed(p % 1 == 0 ? 0 : 1)}%";
  }

  bool? _asNullableBool(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final t = v.trim().toLowerCase();
      if (t == "true") return true;
      if (t == "false") return false;
    }
    return null;
  }

  String? _asString(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  bool _resolveGood({
    required String key,
    required Map? item,
    bool fallback = true,
  }) {
    final isPositive = _asNullableBool(item?["isPositive"]);
    if (isPositive != null) return isPositive;

    final trendUp = _asNullableBool(item?["trendUp"]);
    if (trendUp != null) return trendUp;

    final direction = _asString(item?["direction"]);
    if (direction != null) {
      if (key == "spending") {
        return direction == "down" || direction == "flat";
      }
      if (key == "savings") {
        return direction == "up" || direction == "flat";
      }
    }

    final p = _parsePercent(item?["trend"]);
    if (p != null) {
      if (key == "spending") return p <= 0;
      if (key == "savings") return p >= 0;
    }

    return fallback;
  }

  bool _resolveBudgetGood(Map? budget, double? budgetPct) {
    final status = _asString(budget?["status"]);
    if (status != null) {
      switch (status) {
        case "within_budget":
          return true;
        case "overspent":
          return false;
        case "no_income":
          return false;
      }
    }

    if (budgetPct == null) return false;
    return budgetPct >= 50;
  }

  String _money(num v) {
    final negative = v < 0;
    final s = v.abs().round().toString();
    final buf = StringBuffer();

    for (int i = 0; i < s.length; i++) {
      final posFromEnd = s.length - i;
      buf.write(s[i]);
      if (posFromEnd > 1 && posFromEnd % 3 == 1) {
        buf.write(',');
      }
    }

    return "${negative ? '-' : ''}${buf.toString()} đ";
  }

  @override
  Widget build(BuildContext context) {
    final spending = stats?["spendingToday"] as Map?;

    final budget = (stats?["budgetRemaining"] ?? stats?["budgetThisMonth"]) as Map?;

    final budgetPctRaw = budget?["percentRemaining"] ?? budget?["remainingPercent"];
    final double? budgetPct =
    budgetPctRaw == null ? null : _num(budgetPctRaw).toDouble();

    final budgetValueRaw = budget?["value"] ?? budget?["remaining"];
    final budgetMoney = _num(budgetValueRaw);

    final budgetSubtitle = budgetPct == null
        ? "Chưa có thu nhập tháng"
        : "${budgetPct.round()}% thu nhập tháng còn lại";

    final cards = <_CardVM>[
      _CardVM(
        keyName: "spending",
        title: _asString(spending?["label"]) ?? "Chi tiêu hôm nay",
        subtitle: "So với hôm qua",
        valueText: _money(_num(spending?["value"])),
        badgeText: _formatTrend(spending?["trend"] ?? spending?["percentChange"]),
        good: _resolveGood(key: "spending", item: spending, fallback: true),
        icon: Icons.trending_down_rounded,
        iconGradient: const [Color(0xFFEF476F), Color(0xFFEC4899)],
        isBudget: false,
        budgetPct: null,
      ),

      _CardVM(
        keyName: "budget",
        title: _asString(budget?["label"]) ?? "Ngân sách tháng này",
        subtitle: budgetSubtitle,
        valueText: _money(budgetMoney),
        badgeText: budgetPct == null ? "—" : "${budgetPct.round()}%",
        good: _resolveBudgetGood(budget, budgetPct),
        icon: Icons.account_balance_wallet_rounded,
        iconGradient: const [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
        isBudget: true,
        budgetPct: budgetPct,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  "Thống kê",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
              if (loading)
                const Text(
                  "Đang tải…",
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              IconButton(
                onPressed: loading ? null : _load,
                tooltip: "Tải lại",
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              final isWide = w >= 720;

              if (!isWide) {
                return Column(
                  children: [
                    for (int i = 0; i < cards.length; i++) ...[
                      _StatCard(vm: cards[i], index: i),
                      if (i != cards.length - 1) const SizedBox(height: 12),
                    ],
                  ],
                );
              }

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: cards.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.25,
                ),
                itemBuilder: (_, i) => _StatCard(vm: cards[i], index: i),
              );
            },
          ),
        ],
      ),
    );
  }
}

extension on http.Response {
  bool get ok => statusCode >= 200 && statusCode < 300;
}

class _CardVM {
  final String keyName;
  final String title;
  final String? subtitle;
  final String valueText;
  final String badgeText;
  final bool good;
  final IconData icon;
  final List<Color> iconGradient;
  final bool isBudget;
  final double? budgetPct;

  _CardVM({
    required this.keyName,
    required this.title,
    this.subtitle,
    required this.valueText,
    required this.badgeText,
    required this.good,
    required this.icon,
    required this.iconGradient,
    required this.isBudget,
    required this.budgetPct,
  });
}

class _StatCard extends StatelessWidget {
  final _CardVM vm;
  final int index;

  const _StatCard({required this.vm, required this.index});

  @override
  Widget build(BuildContext context) {
    final pillBg = vm.good ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2);
    final pillText = vm.good ? const Color(0xFF059669) : const Color(0xFFEF4444);

    final pct = (vm.budgetPct ?? 0).clamp(0, 100).toDouble();
    final progressGood = vm.good;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 220 + index * 60),
      curve: Curves.easeOut,
      builder: (context, t, child) {
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 10),
            child: child,
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.88),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.7)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 18,
              offset: Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: vm.iconGradient,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 10,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(vm.icon, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vm.title,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        vm.valueText,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: pillBg,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: vm.good
                          ? const Color(0xFFA7F3D0)
                          : const Color(0xFFFECACA),
                    ),
                  ),
                  child: Text(
                    vm.badgeText,
                    style: TextStyle(
                      color: pillText,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            if (vm.subtitle != null && vm.subtitle!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                vm.subtitle!,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (vm.isBudget) ...[
              const SizedBox(height: 12),
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: pct / 100),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOut,
                    builder: (context, t, _) {
                      return FractionallySizedBox(
                        widthFactor: t,
                        alignment: Alignment.centerLeft,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: progressGood
                                  ? const [Color(0xFF34D399), Color(0xFF2DD4BF)]
                                  : const [Color(0xFFFB7185), Color(0xFFF472B6)],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "0%",
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    "100%",
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}