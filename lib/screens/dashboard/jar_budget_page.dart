import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// TODO: sửa đúng path AuthService của bạn
import '../../services/auth_service.dart';

class JarBudgetPage extends StatefulWidget {
  const JarBudgetPage({super.key});

  @override
  State<JarBudgetPage> createState() => _JarBudgetPageState();
}

class _JarBudgetPageState extends State<JarBudgetPage> {
  final auth = AuthService();

  bool loading = true;
  String error = "";
  bool hideMoney = false;

  Map<String, dynamic>? cycle;
  List<Map<String, dynamic>> templates = [];

  /// ✅ Base URL tự đúng theo môi trường:
  /// - Flutter Web: localhost
  /// - Android Emulator: 10.0.2.2
  /// - Điện thoại thật: đổi thành IP LAN máy chạy backend (vd: 192.168.1.10)
  String get API_BASE {
    if (kIsWeb) return "http://localhost:3000";
    // TODO: nếu chạy điện thoại thật thì đổi:
    // return "http://192.168.1.10:3000";
    return "http://10.0.2.2:3000";
  }

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  // ===== Helpers =====
  String money(num n) => "${_fmt(n)} đ";

  String _fmt(num n) {
    final s = (n.round()).toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final idxFromEnd = s.length - i;
      buf.write(s[i]);
      if (idxFromEnd > 1 && idxFromEnd % 3 == 1) buf.write(".");
    }
    return buf.toString();
  }

  int parseMoney(String v) {
    final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return 0;
    return int.tryParse(digits) ?? 0;
  }

  String _iconEmoji(String? icon) {
    switch (icon) {
      case "utensils":
        return "🍜";
      case "home":
        return "🏠";
      case "car":
        return "🚗";
      case "shopping-bag":
        return "🛍️";
      case "film":
        return "🎬";
      case "heart":
        return "❤️";
      default:
        return "💰";
    }
  }

  LinearGradient _gradientFromKey(String? key) {
    // map theo preset màu bạn hay dùng
    switch (key) {
      case "from-emerald-400 to-teal-500":
        return const LinearGradient(colors: [Color(0xFF34D399), Color(0xFF14B8A6)]);
      case "from-indigo-500 to-purple-500":
        return const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFFA855F7)]);
      case "from-rose-400 to-pink-500":
        return const LinearGradient(colors: [Color(0xFFFB7185), Color(0xFFEC4899)]);
      case "from-amber-400 to-orange-500":
        return const LinearGradient(colors: [Color(0xFFFBBF24), Color(0xFFF97316)]);
      case "from-sky-400 to-blue-500":
        return const LinearGradient(colors: [Color(0xFF38BDF8), Color(0xFF3B82F6)]);
      case "from-lime-400 to-green-500":
        return const LinearGradient(colors: [Color(0xFFA3E635), Color(0xFF22C55E)]);
      default:
        return const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF7C3AED)]);
    }
  }

  Future<Map<String, String>> _authHeaders() async {
    final token = await auth.getToken();
    if (token == null || token.isEmpty) {
      throw Exception("Bạn chưa đăng nhập (thiếu accessToken).");
    }
    return {
      "Authorization": "Bearer $token",
      "Content-Type": "application/json",
    };
  }

  Map<String, dynamic>? _safeJson(String body) {
    try {
      final x = jsonDecode(body);
      if (x is Map<String, dynamic>) return x;
      return null;
    } catch (_) {
      return null;
    }
  }

  String _niceError(Object e) {
    final s = e.toString().replaceFirst("Exception: ", "");
    if (s.contains("Failed to fetch") ||
        s.contains("XMLHttpRequest") ||
        s.contains("ERR_CONNECTION_TIMED_OUT") ||
        s.contains("Connection timed out") ||
        s.contains("SocketException")) {
      return "Không kết nối được server. Kiểm tra API_BASE, backend đang chạy, và môi trường (Web/Emulator/Phone).";
    }
    return s;
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ===== API load flow =====
  Future<void> _loadAll() async {
    setState(() {
      loading = true;
      error = "";
    });

    try {
      final headers = await _authHeaders();

      // 1) templates
      final rT = await http
          .get(Uri.parse("$API_BASE/api/jars/templates"), headers: headers)
          .timeout(const Duration(seconds: 15));
      final dT = _safeJson(rT.body);
      if (rT.statusCode == 200 && dT?["success"] == true) {
        final list = (dT?["templates"] as List? ?? []).cast<dynamic>();
        templates = list.map((e) => Map<String, dynamic>.from(e)).toList();
      }

      // 2) cycle current
      final r1 = await http
          .get(Uri.parse("$API_BASE/api/jars/cycle/current"), headers: headers)
          .timeout(const Duration(seconds: 15));
      if (r1.statusCode == 401) throw Exception("401: Token hết hạn hoặc không hợp lệ.");
      final d1 = _safeJson(r1.body);
      final baseCycle = (d1?["cycle"] == null) ? null : Map<String, dynamic>.from(d1!["cycle"]);
      final id = baseCycle?["_id"]?.toString();
      if (id == null || id.isEmpty) {
        cycle = null;
        throw Exception("Không lấy được chu kỳ hiện tại.");
      }

      // 3) nếu chưa có buckets => apply-allocation
      final buckets = (baseCycle?["buckets"] as List?) ?? [];
      if (buckets.isEmpty) {
        await http
            .post(Uri.parse("$API_BASE/api/jars/cycle/$id/apply-allocation"), headers: headers)
            .timeout(const Duration(seconds: 15));
      }

      // 4) overview
      final r2 = await http
          .get(Uri.parse("$API_BASE/api/jars/cycle/$id/overview"), headers: headers)
          .timeout(const Duration(seconds: 15));
      if (!r2.statusCode.toString().startsWith("2")) {
        cycle = {...?baseCycle, "_id": id};
        throw Exception("Không tải được thống kê chi tiết (overview).");
      }
      final d2 = _safeJson(r2.body);
      final overviewCycle =
      (d2?["cycle"] == null) ? <String, dynamic>{} : Map<String, dynamic>.from(d2!["cycle"]);

      cycle = {...?baseCycle, ...overviewCycle, "_id": id};
    } catch (e) {
      error = _niceError(e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // ===== Merge buckets =====
  List<Map<String, dynamic>> get mergedBuckets {
    final buckets = (cycle?["buckets"] as List?) ?? [];
    final bucketList = buckets.cast<dynamic>().map((x) => Map<String, dynamic>.from(x)).toList();
    final daysLeft = (cycle?["daysLeft"] ?? 0) as num;

    return templates.map((t) {
      final tid = t["_id"]?.toString();

      final b = bucketList.firstWhere(
            (x) => x["template_id"]?.toString() == tid,
        orElse: () => <String, dynamic>{},
      );

      final monthlyLimit = (b["monthlyLimit"] ?? t["monthlyLimit"] ?? 0);
      final spent = (b["spent"] ?? 0);

      final limitNum =
      (monthlyLimit is num) ? monthlyLimit : num.tryParse(monthlyLimit.toString()) ?? 0;
      final spentNum = (spent is num) ? spent : num.tryParse(spent.toString()) ?? 0;

      final remaining = (limitNum - spentNum) < 0 ? 0 : (limitNum - spentNum);
      final suggestPerDay = (daysLeft > 0) ? (remaining / daysLeft).round() : 0;

      return {
        "template_id": tid,
        "name": t["name"],
        "icon": t["icon"],
        "color": t["color"],
        "allocateType": t["allocateType"],
        "allocateValue": t["allocateValue"],
        "monthlyLimit": limitNum,
        "spent": spentNum,
        "remaining": remaining,
        "suggestPerDay": suggestPerDay,
      };
    }).toList();
  }

  num get usedLimit => mergedBuckets.fold<num>(0, (s, b) => s + ((b["monthlyLimit"] ?? 0) as num));

  // ===== Open Fund modal =====
  Future<void> _openFundJar() async {
    final id = cycle?["_id"]?.toString() ?? "";
    if (id.isEmpty) return;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (_) {
        return FundJarSheet(
          baseUrl: API_BASE,
          cycleId: id,
          authHeaders: _authHeaders,
        );
      },
    );

    if (ok == true) _loadAll();
  }

  // ===== Open Create Bucket =====
  Future<void> _openCreateBucket() async {
    final id = cycle?["_id"]?.toString() ?? "";
    if (id.isEmpty) return;

    final totalIn = (cycle?["fundedAmount"] ?? 0) as num;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (_) {
        return CreateBucketSheet(
          baseUrl: API_BASE,
          cycleId: id,
          totalIn: totalIn,
          usedLimit: usedLimit,
          authHeaders: _authHeaders,
        );
      },
    );

    if (ok == true) _loadAll();
  }

  // ===== Open Bucket Detail =====
  Future<void> _openBucketDetail(Map<String, dynamic> bucket) async {
    final id = cycle?["_id"]?.toString() ?? "";
    if (id.isEmpty) return;

    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (_) {
        return BucketDetailSheet(
          baseUrl: API_BASE,
          cycleId: id,
          bucket: bucket,
          authHeaders: _authHeaders,
          onChanged: () => _loadAll(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalIn = (cycle?["fundedAmount"] ?? 0) as num;
    final totalOut = (cycle?["spentTotal"] ?? 0) as num;
    final daysLeft = (cycle?["daysLeft"] ?? 0) as num;
    final monthKey = cycle?["monthKey"]?.toString() ?? "--";

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Header gradient
            Container(
              padding: const EdgeInsets.fromLTRB(16, 54, 16, 18),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF7C3AED), Color(0xFF06B6D4)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(34),
                  bottomRight: Radius.circular(34),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // top row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          InkWell(
                            onTap: () => Navigator.pop(context),
                            borderRadius: BorderRadius.circular(999),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                border: Border.all(color: Colors.white.withOpacity(0.2)),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            "Quản lý Hũ Chi Tiêu",
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        onPressed: () => setState(() => hideMoney = !hideMoney),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.white.withOpacity(0.15),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                        ),
                        icon: Icon(hideMoney ? Icons.visibility : Icons.visibility_off, size: 18),
                        label: Text(hideMoney ? "Hiện số" : "Ẩn số", style: const TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),
                  if (loading)
                    const Text("Đang tải dữ liệu...", style: TextStyle(color: Colors.white70, fontSize: 12)),
                  if (!loading && error.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              error,
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: _loadAll,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: Colors.white.withOpacity(0.2)),
                              ),
                              child: const Text("Thử lại",
                                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                            ),
                          )
                        ],
                      ),
                    ),

                  const SizedBox(height: 14),

                  // totals
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          title: "Tổng tiền vào",
                          value: hideMoney ? "••••" : money(totalIn),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          title: "Tổng tiền ra",
                          value: hideMoney ? "••••" : money(totalOut),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Chu kỳ còn: ${daysLeft.toInt()} ngày",
                          style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      Text("Tháng: $monthKey", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // actions
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: (cycle?["_id"] == null || loading) ? null : _openFundJar,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black87,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            elevation: 0,
                          ),
                          child: const Text("Nạp vào hũ", style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton(
                        onPressed: (cycle?["_id"] == null || loading) ? null : _openCreateBucket,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.white.withOpacity(0.25)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        child: const Text("Tạo mục", style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // buckets
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
              child: Column(
                children: [
                  if (mergedBuckets.isEmpty && !loading)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFF1F5F9)),
                        boxShadow: const [
                          BoxShadow(color: Color(0x11000000), blurRadius: 12, offset: Offset(0, 6))
                        ],
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Chưa có mục nào", style: TextStyle(fontWeight: FontWeight.w700)),
                          SizedBox(height: 6),
                          Text(
                            "Hãy bấm Tạo mục để thêm “Ăn uống”, “Tiền nhà”, “Đi lại”…",
                            style: TextStyle(color: Colors.black54, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  for (final b in mergedBuckets)
                    _BucketCard(
                      name: (b["name"] ?? "").toString(),
                      emoji: _iconEmoji((b["icon"] ?? "").toString()),
                      hideMoney: hideMoney,
                      limit: (b["monthlyLimit"] ?? 0) as num,
                      spent: (b["spent"] ?? 0) as num,
                      remaining: (b["remaining"] ?? 0) as num,
                      suggestPerDay: (b["suggestPerDay"] ?? 0) as num,
                      money: money,
                      gradient: _gradientFromKey(b["color"]?.toString()),
                      onTap: () => _openBucketDetail(b),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),

      // ✅ FAB mở CreateBucket luôn
      floatingActionButton: FloatingActionButton(
        onPressed: (cycle?["_id"] == null || loading) ? null : _openCreateBucket,
        backgroundColor: const Color(0xFF6D28D9),
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ================= UI components =================

class _StatCard extends StatelessWidget {
  final String title;
  final String value;

  const _StatCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _BucketCard extends StatelessWidget {
  final String name;
  final String emoji;
  final bool hideMoney;
  final num limit;
  final num spent;
  final num remaining;
  final num suggestPerDay;
  final String Function(num) money;
  final VoidCallback onTap;
  final LinearGradient gradient;

  const _BucketCard({
    required this.name,
    required this.emoji,
    required this.hideMoney,
    required this.limit,
    required this.spent,
    required this.remaining,
    required this.suggestPerDay,
    required this.money,
    required this.onTap,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (limit > 0) ? ((spent / limit) * 100).clamp(0, 100).round() : 0;
    final isDanger = pct >= 90;
    final isWarning = pct >= 70 && pct < 90;

    final pctColor = isDanger ? Colors.red : (isWarning ? Colors.orange : Colors.black87);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFF1F5F9)),
          boxShadow: const [BoxShadow(color: Color(0x11000000), blurRadius: 12, offset: Offset(0, 6))],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: gradient,
                  ),
                  alignment: Alignment.center,
                  child: Text(emoji, style: const TextStyle(fontSize: 18)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text(
                        "Hạn mức: ${hideMoney ? "••••" : money(limit)}",
                        style: const TextStyle(color: Colors.black54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text("$pct%", style: TextStyle(fontWeight: FontWeight.w800, color: pctColor)),
                    const Text("Đã dùng", style: TextStyle(color: Colors.black54, fontSize: 11)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: (pct / 100).toDouble(),
                minHeight: 8,
                backgroundColor: const Color(0xFFF1F5F9),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Còn lại: ${hideMoney ? "••••" : money(remaining)}",
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
                Text(
                  "Gợi ý/ngày: ${hideMoney ? "••••" : money(suggestPerDay)}",
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =======================
// FundJarModal (React) -> FundJarSheet (Flutter)
// =======================
class FundJarSheet extends StatefulWidget {
  final String baseUrl;
  final String cycleId;
  final Future<Map<String, String>> Function() authHeaders;

  const FundJarSheet({
    super.key,
    required this.baseUrl,
    required this.cycleId,
    required this.authHeaders,
  });

  @override
  State<FundJarSheet> createState() => _FundJarSheetState();
}

class _FundJarSheetState extends State<FundJarSheet> {
  final TextEditingController _amountCtl = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool loading = false;
  bool showSuggest = false;
  List<int> suggests = [];

  int parseMoney(String v) {
    final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return 0;
    return int.tryParse(digits) ?? 0;
  }

  String fmt(num n) {
    final s = (n.round()).toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final idxFromEnd = s.length - i;
      buf.write(s[i]);
      if (idxFromEnd > 1 && idxFromEnd % 3 == 1) buf.write(".");
    }
    return buf.toString();
  }

  List<int> buildMoneySuggest(String raw) {
    final n = parseMoney(raw);
    if (n <= 0) return [];
    return [1000, 10000, 1000000].map((m) => n * m).take(5).toList();
  }

  void _onChangeAmount(String v) {
    final s = buildMoneySuggest(v);
    setState(() {
      suggests = s;
      showSuggest = s.isNotEmpty;
    });
  }

  Map<String, dynamic>? _safeJson(String body) {
    try {
      final x = jsonDecode(body);
      if (x is Map<String, dynamic>) return x;
      return null;
    } catch (_) {
      return null;
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> submit() async {
    final fund = parseMoney(_amountCtl.text);

    if (widget.cycleId.isEmpty) {
      _snack("Thiếu cycleId");
      return;
    }
    if (fund <= 0) {
      _snack("Nhập số tiền nạp hợp lệ");
      return;
    }

    setState(() => loading = true);
    try {
      final headers = await widget.authHeaders();

      // POST /fund
      final r = await http
          .post(
        Uri.parse("${widget.baseUrl}/api/jars/cycle/${widget.cycleId}/fund"),
        headers: headers,
        body: jsonEncode({"amount": fund}),
      )
          .timeout(const Duration(seconds: 15));

      final d = _safeJson(r.body);
      if (!r.statusCode.toString().startsWith("2") || d?["success"] != true) {
        final msg = (d?["message"] ?? "Nạp thất bại").toString();
        throw Exception(msg);
      }

      // POST /apply-allocation
      await http
          .post(
        Uri.parse("${widget.baseUrl}/api/jars/cycle/${widget.cycleId}/apply-allocation"),
        headers: headers,
      )
          .timeout(const Duration(seconds: 15));

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _snack(e.toString().replaceFirst("Exception: ", ""));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    _amountCtl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preview = parseMoney(_amountCtl.text);

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        setState(() => showSuggest = false);
      },
      child: Container(
        color: Colors.transparent,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 14,
              bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(28),
                topRight: Radius.circular(28),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // HEADER
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Nạp vào hũ tháng",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      InkWell(
                        onTap: () => Navigator.pop(context, false),
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Icon(Icons.close, size: 18),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Nhập số tiền bạn muốn nạp từ số dư cá nhân vào hũ tháng này.",
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 14),

                  const Text(
                    "Số tiền nạp",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black54),
                  ),
                  const SizedBox(height: 8),

                  Stack(
                    children: [
                      TextField(
                        controller: _amountCtl,
                        focusNode: _focusNode,
                        keyboardType: TextInputType.number,
                        onChanged: _onChangeAmount,
                        decoration: InputDecoration(
                          hintText: "Ví dụ: 3.000.000",
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(color: Color(0xFFC7D2FE), width: 2),
                          ),
                        ),
                      ),

                      if (showSuggest && suggests.isNotEmpty)
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 62,
                          child: Material(
                            elevation: 10,
                            borderRadius: BorderRadius.circular(14),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: const Color(0xFFE5E7EB)),
                                  color: Colors.white,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    for (final s in suggests)
                                      InkWell(
                                        onTap: () {
                                          _amountCtl.text = fmt(s);
                                          _amountCtl.selection = TextSelection.fromPosition(
                                            TextPosition(offset: _amountCtl.text.length),
                                          );
                                          setState(() => showSuggest = false);
                                          FocusScope.of(context).unfocus();
                                        },
                                        child: Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                          child: Text("${fmt(s)} đ", style: const TextStyle(fontSize: 14)),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 8),
                  Text("Xem trước: ${fmt(preview)} đ", style: const TextStyle(fontSize: 11, color: Colors.black54)),
                  const SizedBox(height: 14),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: loading ? null : submit,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        elevation: 0,
                      ),
                      child: Text(
                        loading ? "Đang nạp..." : "Xác nhận nạp",
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =======================
// CreateBucketModal (React) -> CreateBucketSheet (Flutter)
// =======================
class _IconPreset {
  final String key;
  final String label;
  final String emoji;
  const _IconPreset(this.key, this.label, this.emoji);
}

class _ColorPreset {
  final String key;
  final List<Color> colors;
  const _ColorPreset(this.key, this.colors);
}

class CreateBucketSheet extends StatefulWidget {
  final String baseUrl;
  final String cycleId;
  final num totalIn;
  final num usedLimit;
  final Future<Map<String, String>> Function() authHeaders;

  const CreateBucketSheet({
    super.key,
    required this.baseUrl,
    required this.cycleId,
    required this.totalIn,
    required this.usedLimit,
    required this.authHeaders,
  });

  @override
  State<CreateBucketSheet> createState() => _CreateBucketSheetState();
}

class _CreateBucketSheetState extends State<CreateBucketSheet> {
  final _nameCtl = TextEditingController();
  final _limitCtl = TextEditingController();
  final _allocCtl = TextEditingController();

  bool loading = false;

  final icons = const [
    _IconPreset("utensils", "Ăn uống", "🍜"),
    _IconPreset("home", "Nhà ở", "🏠"),
    _IconPreset("car", "Đi lại", "🚗"),
    _IconPreset("shopping-bag", "Mua sắm", "🛍️"),
    _IconPreset("film", "Giải trí", "🎬"),
    _IconPreset("heart", "Sức khỏe", "❤️"),
  ];

  final colors = const [
    _ColorPreset("from-emerald-400 to-teal-500", [Color(0xFF34D399), Color(0xFF14B8A6)]),
    _ColorPreset("from-indigo-500 to-purple-500", [Color(0xFF6366F1), Color(0xFFA855F7)]),
    _ColorPreset("from-rose-400 to-pink-500", [Color(0xFFFB7185), Color(0xFFEC4899)]),
    _ColorPreset("from-amber-400 to-orange-500", [Color(0xFFFBBF24), Color(0xFFF97316)]),
    _ColorPreset("from-sky-400 to-blue-500", [Color(0xFF38BDF8), Color(0xFF3B82F6)]),
    _ColorPreset("from-lime-400 to-green-500", [Color(0xFFA3E635), Color(0xFF22C55E)]),
  ];

  String iconKey = "utensils";
  String colorKey = "from-emerald-400 to-teal-500";
  String allocateType = "fixed"; // fixed | percent

  bool showLimitSuggest = false;
  List<int> limitSuggest = [];

  bool showAllocSuggest = false;
  List<int> allocSuggest = [];

  int parseMoney(String v) {
    final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return 0;
    return int.tryParse(digits) ?? 0;
  }

  String fmt(num n) {
    final s = (n.round()).toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final idxFromEnd = s.length - i;
      buf.write(s[i]);
      if (idxFromEnd > 1 && idxFromEnd % 3 == 1) buf.write(".");
    }
    return buf.toString();
  }

  List<int> buildMoneySuggest(String raw, {required int max}) {
    final n = parseMoney(raw);
    if (n <= 0) return [];
    return [1000, 10000, 1000000].map((m) => n * m).where((v) => v <= max).take(5).toList();
  }

  int get limitNumber => parseMoney(_limitCtl.text);
  int get allocNumber => parseMoney(_allocCtl.text);

  int get remainingLimit {
    final r = (widget.totalIn - widget.usedLimit).round();
    return r < 0 ? 0 : r;
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> submit() async {
    final name = _nameCtl.text.trim();
    if (name.isEmpty) return _snack("Nhập tên mục");
    if (limitNumber <= 0) return _snack("Hạn mức tháng phải > 0");
    if (limitNumber > remainingLimit) return _snack("Vượt ngân sách (${fmt(remainingLimit)} đ)");

    if (allocateType == "percent") {
      final p = int.tryParse(_allocCtl.text.trim()) ?? 0;
      if (p < 0 || p > 100) return _snack("Giá trị % phải từ 0 đến 100");
    } else {
      if (allocNumber < 0) return _snack("Giá trị phân bổ không hợp lệ");
      if (allocNumber > limitNumber) return _snack("Phân bổ cố định không được vượt hạn mức tháng");
    }

    setState(() => loading = true);
    try {
      final headers = await widget.authHeaders();

      // POST /api/jars/templates
      final body = {
        "name": name,
        "icon": iconKey,
        "color": colorKey,
        "allocateType": allocateType,
        "allocateValue": allocateType == "percent"
            ? (int.tryParse(_allocCtl.text.trim()) ?? 0)
            : allocNumber,
        "monthlyLimit": limitNumber,
      };

      final r = await http
          .post(
        Uri.parse("${widget.baseUrl}/api/jars/templates"),
        headers: headers,
        body: jsonEncode(body),
      )
          .timeout(const Duration(seconds: 15));

      final d = jsonDecode(r.body);
      if (!r.statusCode.toString().startsWith("2") || d["success"] != true) {
        throw Exception(d["message"] ?? "Tạo mục thất bại");
      }

      // apply-allocation để bucket mới xuất hiện ngay trong cycle
      await http
          .post(
        Uri.parse("${widget.baseUrl}/api/jars/cycle/${widget.cycleId}/apply-allocation"),
        headers: headers,
      )
          .timeout(const Duration(seconds: 15));

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _snack(e.toString().replaceFirst("Exception: ", ""));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _limitCtl.dispose();
    _allocCtl.dispose();
    super.dispose();
  }

  InputDecoration _dec(String hint) => InputDecoration(
    hintText: hint,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: Color(0xFFC7D2FE), width: 2),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final maxLimit = remainingLimit;

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        setState(() {
          showLimitSuggest = false;
          showAllocSuggest = false;
        });
      },
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 14,
            bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Tạo mục chi tiêu", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      InkWell(
                        onTap: () => Navigator.pop(context, false),
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(999)),
                          child: const Icon(Icons.close, size: 18),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  const Text("Tên mục", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black54)),
                  const SizedBox(height: 8),
                  TextField(controller: _nameCtl, decoration: _dec("Ví dụ: Ăn uống")),
                  const SizedBox(height: 14),

                  const Text("Hạn mức tháng", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black54)),
                  const SizedBox(height: 8),
                  Stack(
                    children: [
                      TextField(
                        controller: _limitCtl,
                        keyboardType: TextInputType.number,
                        decoration: _dec("800,000"),
                        onChanged: (v) {
                          final s = buildMoneySuggest(v, max: maxLimit);
                          setState(() {
                            limitSuggest = s;
                            showLimitSuggest = s.isNotEmpty;
                          });
                        },
                      ),
                      if (showLimitSuggest)
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 62,
                          child: Material(
                            elevation: 10,
                            borderRadius: BorderRadius.circular(14),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE5E7EB)), color: Colors.white),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    for (final s in limitSuggest)
                                      InkWell(
                                        onTap: () {
                                          _limitCtl.text = fmt(s);
                                          _limitCtl.selection = TextSelection.fromPosition(TextPosition(offset: _limitCtl.text.length));
                                          setState(() => showLimitSuggest = false);
                                          FocusScope.of(context).unfocus();
                                        },
                                        child: Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                          child: Text("${fmt(s)} đ"),
                                        ),
                                      )
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text("Có thể phân bổ tối đa: ${fmt(maxLimit)} đ", style: const TextStyle(fontSize: 11, color: Colors.black54)),
                  const SizedBox(height: 14),

                  const Text(
                    "Chọn icon",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black54),
                  ),
                  const SizedBox(height: 6),

                  GridView.builder(
                    itemCount: icons.length,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,        // gọn hơn (từ 3 -> 4)
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 1.15,   // ô thấp hơn, gọn hơn
                    ),
                    itemBuilder: (_, idx) {
                      final i = icons[idx];
                      final selected = iconKey == i.key;

                      return InkWell(
                        onTap: () => setState(() => iconKey = i.key),
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected ? const Color(0xFF6366F1) : const Color(0xFFE5E7EB),
                              width: selected ? 1.6 : 1,
                            ),
                            color: selected ? const Color(0xFFEFF6FF) : Colors.white,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(i.emoji, style: const TextStyle(fontSize: 18)),
                              const SizedBox(height: 4),
                              Text(
                                i.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 12),

                  // ===== COLOR (giống UI web: grid + preview) =====
                  const Text(
                    "Chọn màu",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black54),
                  ),
                  const SizedBox(height: 6),

                  GridView.builder(
                    itemCount: colors.length,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 2.8, // thanh nhỏ như hình bạn gửi
                    ),
                    itemBuilder: (_, idx) {
                      final c = colors[idx];
                      final selected = colorKey == c.key;

                      return InkWell(
                        onTap: () => setState(() => colorKey = c.key),
                        borderRadius: BorderRadius.circular(18),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOut,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: c.colors),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: selected ? const Color(0xFF6366F1) : Colors.transparent,
                              width: 2,
                            ),
                            boxShadow: selected
                                ? [
                              BoxShadow(
                                color: const Color(0xFF6366F1).withOpacity(0.18),
                                blurRadius: 10,
                                offset: const Offset(0, 6),
                              )
                            ]
                                : null,
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 10),

// preview màu đang chọn (giống div preview ở web)
                  Builder(
                    builder: (context) {
                      final selected = colors.firstWhere(
                            (x) => x.key == colorKey,
                        orElse: () => colors.first,
                      );

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        height: 34,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: selected.colors),
                          borderRadius: BorderRadius.circular(18),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 12),



                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Cách phân bổ", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black54)),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE5E7EB)), borderRadius: BorderRadius.circular(18)),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: allocateType,
                                  isExpanded: true,
                                  items: const [
                                    DropdownMenuItem(value: "fixed", child: Text("Cố định (đ)")),
                                    DropdownMenuItem(value: "percent", child: Text("Theo %")),
                                  ],
                                  onChanged: (v) {
                                    if (v == null) return;
                                    setState(() {
                                      allocateType = v;
                                      _allocCtl.clear();
                                      showAllocSuggest = false;
                                    });
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Giá trị ${allocateType == "percent" ? "(%)" : "(đ)"}",
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black54)),
                            const SizedBox(height: 8),
                            if (allocateType == "fixed")
                              Stack(
                                children: [
                                  TextField(
                                    controller: _allocCtl,
                                    keyboardType: TextInputType.number,
                                    decoration: _dec("500,000"),
                                    onChanged: (v) {
                                      final max = (limitNumber <= 0) ? 999999999 : limitNumber;
                                      final s = buildMoneySuggest(v, max: max);
                                      setState(() {
                                        allocSuggest = s;
                                        showAllocSuggest = s.isNotEmpty;
                                      });
                                    },
                                  ),
                                  if (showAllocSuggest)
                                    Positioned(
                                      left: 0,
                                      right: 0,
                                      top: 62,
                                      child: Material(
                                        elevation: 10,
                                        borderRadius: BorderRadius.circular(14),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(14),
                                          child: Container(
                                            decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE5E7EB)), color: Colors.white),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                for (final s in allocSuggest)
                                                  InkWell(
                                                    onTap: () {
                                                      _allocCtl.text = fmt(s);
                                                      _allocCtl.selection = TextSelection.fromPosition(TextPosition(offset: _allocCtl.text.length));
                                                      setState(() => showAllocSuggest = false);
                                                      FocusScope.of(context).unfocus();
                                                    },
                                                    child: Container(
                                                      width: double.infinity,
                                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                                      child: Text("${fmt(s)} đ"),
                                                    ),
                                                  )
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              )
                            else
                              TextField(
                                controller: _allocCtl,
                                keyboardType: TextInputType.number,
                                decoration: _dec("20"),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: loading ? null : submit,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        elevation: 0,
                      ),
                      child: Text(loading ? "Đang tạo..." : "Tạo mục", style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =======================
// BucketDetailModal (React) -> BucketDetailSheet (Flutter)
// =======================
class BucketDetailSheet extends StatefulWidget {
  final String baseUrl;
  final String cycleId;
  final Map<String, dynamic> bucket;
  final Future<Map<String, String>> Function() authHeaders;
  final VoidCallback onChanged;

  const BucketDetailSheet({
    super.key,
    required this.baseUrl,
    required this.cycleId,
    required this.bucket,
    required this.authHeaders,
    required this.onChanged,
  });

  @override
  State<BucketDetailSheet> createState() => _BucketDetailSheetState();
}

class _BucketDetailSheetState extends State<BucketDetailSheet> {
  final _amountCtl = TextEditingController();
  final _noteCtl = TextEditingController();

  bool checking = false;
  bool saving = false;
  bool deleting = false;

  bool showSuggest = false;
  List<int> suggests = [];

  Map<String, dynamic>? meta;

  int parseMoney(String v) {
    final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return 0;
    return int.tryParse(digits) ?? 0;
  }

  String fmt(num n) {
    final s = (n.round()).toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final idxFromEnd = s.length - i;
      buf.write(s[i]);
      if (idxFromEnd > 1 && idxFromEnd % 3 == 1) buf.write(".");
    }
    return "${buf.toString()} đ";
  }

  List<int> buildMoneySuggest(String raw, int max) {
    final n = parseMoney(raw);
    if (n <= 0) return [];
    return [1000, 10000, 1000000].map((m) => n * m).where((v) => v <= max).take(5).toList();
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Map<String, dynamic> levelUI(String? level) {
    if (level == "danger") {
      return {"text": "🔴 Nguy hiểm", "bg": const Color(0xFFFFE4E6), "bd": const Color(0xFFFECACA), "tx": const Color(0xFFBE123C)};
    }
    if (level == "warning") {
      return {"text": "🟡 Cẩn thận", "bg": const Color(0xFFFFFBEB), "bd": const Color(0xFFFDE68A), "tx": const Color(0xFFB45309)};
    }
    return {"text": "🟢 An toàn", "bg": const Color(0xFFECFDF5), "bd": const Color(0xFFBBF7D0), "tx": const Color(0xFF047857)};
  }

  Future<void> checkLimit(String raw) async {
    final amount = parseMoney(raw);
    final templateId = widget.bucket["template_id"]?.toString();
    final remaining = (widget.bucket["remaining"] ?? 0) as num;

    if (widget.cycleId.isEmpty || templateId == null || amount <= 0 || remaining <= 0) {
      setState(() => meta = null);
      return;
    }

    setState(() => checking = true);
    try {
      final headers = await widget.authHeaders();

      final r = await http
          .post(
        Uri.parse("${widget.baseUrl}/api/jars/cycle/${widget.cycleId}/check-limit"),
        headers: headers,
        body: jsonEncode({
          "templateId": templateId,
          "amountToday": amount,
        }),
      )
          .timeout(const Duration(seconds: 15));

      final d = jsonDecode(r.body);
      if (r.statusCode == 200 && d["success"] == true) {
        setState(() => meta = Map<String, dynamic>.from(d["meta"] ?? {}));
      } else {
        setState(() => meta = null);
      }
    } finally {
      if (mounted) setState(() => checking = false);
    }
  }

  Future<void> saveExpense() async {
    final amount = parseMoney(_amountCtl.text);
    final note = _noteCtl.text.trim();
    final templateId = widget.bucket["template_id"]?.toString();

    if (amount <= 0) return _snack("Nhập số tiền chi hợp lệ");
    if (templateId == null) return _snack("Thiếu templateId");

    setState(() => saving = true);
    try {
      final headers = await widget.authHeaders();

      final r = await http
          .post(
        Uri.parse("${widget.baseUrl}/api/jars/cycle/${widget.cycleId}/expense"),
        headers: headers,
        body: jsonEncode({
          "templateId": templateId,
          "amount": amount,
          "note": note,
        }),
      )
          .timeout(const Duration(seconds: 15));

      final d = jsonDecode(r.body);
      if (!r.statusCode.toString().startsWith("2") || d["success"] != true) {
        throw Exception(d["message"] ?? "Lưu thất bại");
      }

      widget.onChanged();
      _snack("Đã lưu chi tiêu");
      setState(() {
        _amountCtl.clear();
        _noteCtl.clear();
        meta = null;
        showSuggest = false;
      });
    } catch (e) {
      _snack(e.toString().replaceFirst("Exception: ", ""));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> deleteTemplate() async {
    final templateId = widget.bucket["template_id"]?.toString();
    if (templateId == null) return _snack("Không có template để xóa");

    setState(() => deleting = true);
    try {
      final headers = await widget.authHeaders();

      final r = await http
          .delete(
        Uri.parse("${widget.baseUrl}/api/jars/templates/$templateId"),
        headers: headers,
      )
          .timeout(const Duration(seconds: 15));

      final d = jsonDecode(r.body);
      if (!r.statusCode.toString().startsWith("2") || d["success"] != true) {
        throw Exception(d["message"] ?? "Xóa thất bại");
      }

      // apply-allocation để cập nhật cycle
      await http
          .post(
        Uri.parse("${widget.baseUrl}/api/jars/cycle/${widget.cycleId}/apply-allocation"),
        headers: headers,
      )
          .timeout(const Duration(seconds: 15));

      widget.onChanged();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _snack(e.toString().replaceFirst("Exception: ", ""));
    } finally {
      if (mounted) setState(() => deleting = false);
    }
  }

  @override
  void dispose() {
    _amountCtl.dispose();
    _noteCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.bucket["name"]?.toString() ?? "—";
    final colorKey = widget.bucket["color"]?.toString();
    final monthlyLimit = (widget.bucket["monthlyLimit"] ?? 0) as num;
    final remaining = (widget.bucket["remaining"] ?? 0) as num;

    final ui = levelUI(meta?["level"]?.toString());
    final thresholds = (meta?["thresholds"] is Map) ? Map<String, dynamic>.from(meta?["thresholds"]) : null;

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        setState(() => showSuggest = false);
      },
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: EdgeInsets.only(bottom: 16 + MediaQuery.of(context).viewInsets.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // header gradient
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    decoration: BoxDecoration(
                      gradient: _gradientFromKey(colorKey),
                      borderRadius: const BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Mục chi tiêu", style: TextStyle(color: Colors.white70, fontSize: 12)),
                                  const SizedBox(height: 2),
                                  Text(name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                                ],
                              ),
                            ),
                            if (widget.bucket["template_id"] != null)
                              TextButton(
                                onPressed: deleting ? null : deleteTemplate,
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  backgroundColor: Colors.white.withOpacity(0.15),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                ),
                                child: Text(deleting ? "Đang xóa..." : "Xóa"),
                              ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () => Navigator.pop(context, false),
                              borderRadius: BorderRadius.circular(999),
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Icon(Icons.close, color: Colors.white, size: 18),
                              ),
                            )
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _MiniHeaderCard(title: "Hạn mức tháng", value: fmt(monthlyLimit)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _MiniHeaderCard(title: "Còn lại", value: fmt(remaining)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Chi tiêu hôm nay", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black54)),
                        const SizedBox(height: 8),
                        Stack(
                          children: [
                            TextField(
                              controller: _amountCtl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: "Ví dụ: 80,000",
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  borderSide: const BorderSide(color: Color(0xFFC7D2FE), width: 2),
                                ),
                              ),
                              onChanged: (v) {
                                final s = buildMoneySuggest(v, remaining.toInt());
                                setState(() {
                                  suggests = s;
                                  showSuggest = s.isNotEmpty;
                                });
                                checkLimit(v);
                              },
                            ),
                            if (showSuggest && suggests.isNotEmpty)
                              Positioned(
                                left: 0,
                                right: 0,
                                top: 62,
                                child: Material(
                                  elevation: 10,
                                  borderRadius: BorderRadius.circular(14),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: Container(
                                      decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE5E7EB)), color: Colors.white),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          for (final s in suggests)
                                            InkWell(
                                              onTap: () {
                                                final formatted = fmt(s).replaceAll(" đ", "");
                                                _amountCtl.text = formatted;
                                                _amountCtl.selection = TextSelection.fromPosition(TextPosition(offset: _amountCtl.text.length));
                                                setState(() => showSuggest = false);
                                                FocusScope.of(context).unfocus();
                                                checkLimit(formatted);
                                              },
                                              child: Container(
                                                width: double.infinity,
                                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                                child: Text("${fmt(s)}"),
                                              ),
                                            )
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Xem trước: ${fmt(parseMoney(_amountCtl.text))}", style: const TextStyle(fontSize: 11, color: Colors.black54)),
                            if (checking) const Text("Đang kiểm tra…", style: TextStyle(fontSize: 11, color: Colors.black54)),
                          ],
                        ),

                        const SizedBox(height: 12),
                        const Text("Ghi chú", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black54)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _noteCtl,
                          decoration: InputDecoration(
                            hintText: "Ví dụ: ăn trưa",
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: const BorderSide(color: Color(0xFFC7D2FE), width: 2),
                            ),
                          ),
                        ),

                        if (meta != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: ui["bg"] as Color,
                              border: Border.all(color: ui["bd"] as Color),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    ui["text"] as String,
                                    style: TextStyle(fontWeight: FontWeight.w800, color: ui["tx"] as Color),
                                  ),
                                ),
                                if (thresholds != null)
                                  Text(
                                    "An toàn ≤ ${fmt(thresholds["safeMax"] ?? 0)} • Cảnh báo ≤ ${fmt(thresholds["warningMax"] ?? 0)}",
                                    style: TextStyle(fontSize: 11, color: ui["tx"] as Color),
                                  ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: saving ? null : saveExpense,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                              backgroundColor: const Color(0xFF4F46E5),
                              foregroundColor: Colors.white,
                              elevation: 0,
                            ),
                            child: Text(saving ? "Đang lưu..." : "Lưu chi tiêu", style: const TextStyle(fontWeight: FontWeight.w800)),
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  LinearGradient _gradientFromKey(String? key) {
    switch (key) {
      case "from-emerald-400 to-teal-500":
        return const LinearGradient(colors: [Color(0xFF34D399), Color(0xFF14B8A6)]);
      case "from-indigo-500 to-purple-500":
        return const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFFA855F7)]);
      case "from-rose-400 to-pink-500":
        return const LinearGradient(colors: [Color(0xFFFB7185), Color(0xFFEC4899)]);
      case "from-amber-400 to-orange-500":
        return const LinearGradient(colors: [Color(0xFFFBBF24), Color(0xFFF97316)]);
      case "from-sky-400 to-blue-500":
        return const LinearGradient(colors: [Color(0xFF38BDF8), Color(0xFF3B82F6)]);
      case "from-lime-400 to-green-500":
        return const LinearGradient(colors: [Color(0xFFA3E635), Color(0xFF22C55E)]);
      default:
        return const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF7C3AED)]);
    }
  }
}

class _MiniHeaderCard extends StatelessWidget {
  final String title;
  final String value;

  const _MiniHeaderCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
