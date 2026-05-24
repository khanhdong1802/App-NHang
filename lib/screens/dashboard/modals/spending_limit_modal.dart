import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../../services/api_config.dart';

class SpendingLimitModal {
  /// Mở modal đặt / chỉnh sửa hạn mức chi tiêu.
  /// [currentLimit] là dữ liệu từ fetchSpendingLimitData (có thể null/empty khi chưa có hạn mức).
  static Future<bool?> open(
    BuildContext context, {
    required String userId,
    Map<String, dynamic>? currentLimit,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SpendingLimitSheet(
        userId: userId,
        currentLimit: currentLimit,
      ),
    );
  }
}

class _SpendingLimitSheet extends StatefulWidget {
  final String userId;
  final Map<String, dynamic>? currentLimit;

  const _SpendingLimitSheet({required this.userId, this.currentLimit});

  @override
  State<_SpendingLimitSheet> createState() => _SpendingLimitSheetState();
}

class _SpendingLimitSheetState extends State<_SpendingLimitSheet> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl   = TextEditingController();
  int    _months       = 1;
  double _alertPercent = 80;
  bool   _loading      = false;
  String? _error;

  bool get _hasExisting =>
      (widget.currentLimit?['amount'] as num? ?? 0) > 0;

  @override
  void initState() {
    super.initState();
    if (_hasExisting) {
      final d = widget.currentLimit!;
      _amountCtrl.text = (d['amount'] as num).round().toString();
      _noteCtrl.text   = (d['note'] as String? ?? '');
      _months          = (d['months'] as num? ?? 1).toInt().clamp(1, 12);
      _alertPercent    = (d['alert_percent'] as num? ?? 80).toDouble();
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  // ─── helpers ────────────────────────────────────────────────────────────────

  String _money(num v) {
    final s = v.abs().round().toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return "${buf}đ";
  }

  // ─── submit ─────────────────────────────────────────────────────────────────

  /// Lấy limitId từ currentLimit (nếu có) để quyết định PATCH hay POST.
  String? get _existingLimitId =>
      widget.currentLimit?['limit_id']?.toString();

  Future<void> _submit() async {
    final raw = _amountCtrl.text.trim().replaceAll('.', '').replaceAll(',', '');
    if (raw.isEmpty) {
      setState(() => _error = "Vui lòng nhập số tiền hạn mức");
      return;
    }
    final amount = num.tryParse(raw);
    if (amount == null || amount <= 0) {
      setState(() => _error = "Số tiền không hợp lệ");
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      final http.Response res;

      if (_hasExisting && _existingLimitId != null) {
        // ── CẬP NHẬT hạn mức hiện tại (giữ start_date → giữ nguyên spent) ──
        final uri = Uri.parse(
          "${ApiConfig.baseUrl}${ApiConfig.apiPrefix}"
          "/spending-limit/spending-limits/$_existingLimitId",
        );
        res = await http.patch(
          uri,
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "amount":        amount,
            "months":        _months,
            "note":          _noteCtrl.text.trim(),
            "alert_percent": _alertPercent.round(),
          }),
        );
        if (!mounted) return;
        if (res.statusCode == 200) {
          Navigator.pop(context, true);
          return;
        }
      } else {
        // ── TẠO MỚI hạn mức (tháng đầu tiên đặt) ──
        final uri = Uri.parse(
          "${ApiConfig.baseUrl}${ApiConfig.apiPrefix}"
          "/spending-limit/spending-limits",
        );
        res = await http.post(
          uri,
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "user_id":       widget.userId,
            "amount":        amount,
            "months":        _months,
            "note":          _noteCtrl.text.trim(),
            "alert_percent": _alertPercent.round(),
          }),
        );
        if (!mounted) return;
        if (res.statusCode == 201) {
          Navigator.pop(context, true);
          return;
        }
      }

      // Xử lý lỗi chung
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      setState(() => _error = body['message'] ?? "Lỗi server (${res.statusCode})");

    } catch (e) {
      if (mounted) setState(() => _error = "Lỗi kết nối: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ─── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final d       = widget.currentLimit ?? {};
    final spent   = (d['spent']   as num? ?? 0);
    final amount  = (d['amount']  as num? ?? 0);
    final percent = (d['percent'] as num? ?? 0).toDouble();
    final status  = (d['status']  as String? ?? '');
    final isExceeded = status == 'exceeded' || percent >= 100;
    final isWarning  = !isExceeded && status == 'warning';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        24, 16, 24,
        MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── handle ──
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── tiêu đề ──
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7C3AED), Color(0xFF6366F1)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.tune_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Text(
                  _hasExisting ? "Chỉnh sửa hạn mức" : "Đặt hạn mức chi tiêu",
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── card trạng thái hiện tại ──
            if (_hasExisting) ...[
              _StatusCard(
                spent: spent,
                amount: amount,
                percent: percent,
                isExceeded: isExceeded,
                isWarning: isWarning,
                money: _money,
              ),
              const SizedBox(height: 20),
              Text(
                "Đặt hạn mức mới (sẽ thay thế hạn mức hiện tại)",
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
            ],

            // ── input số tiền ──
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: "Số tiền hạn mức (VND) *",
                hintText: "Ví dụ: 5000000",
                prefixIcon: const Icon(Icons.attach_money_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
              ),
            ),
            const SizedBox(height: 16),

            // ── chọn kỳ hạn ──
            Text(
              "Kỳ hạn",
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [1, 3, 6, 12].map((m) {
                final selected = _months == m;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _months = m),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: EdgeInsets.only(right: m == 12 ? 0 : 8),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFF7C3AED)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFF7C3AED)
                              : Colors.grey.shade200,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          "$m tháng",
                          style: TextStyle(
                            color: selected
                                ? Colors.white
                                : Colors.grey.shade700,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // ── slider cảnh báo ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Cảnh báo khi đạt",
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    "${_alertPercent.round()}%",
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: Color(0xFF7C3AED),
                    ),
                  ),
                ),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: const Color(0xFF7C3AED),
                thumbColor: const Color(0xFF7C3AED),
                inactiveTrackColor: Colors.grey.shade200,
                overlayColor: const Color(0x227C3AED),
              ),
              child: Slider(
                value: _alertPercent,
                min: 50,
                max: 100,
                divisions: 10,
                onChanged: (v) => setState(() => _alertPercent = v),
              ),
            ),
            const SizedBox(height: 8),

            // ── ghi chú ──
            TextField(
              controller: _noteCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: "Ghi chú (tuỳ chọn)",
                hintText: 'Ví dụ: Hạn mức tháng ${DateTime.now().month}',
                prefixIcon: const Icon(Icons.note_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
              ),
            ),

            // ── lỗi ──
            if (_error != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: Color(0xFFDC2626),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // ── nút lưu ──
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _loading ? null : _submit,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(
                  _loading
                      ? "Đang lưu..."
                      : _hasExisting
                          ? "Cập nhật hạn mức"
                          : "Lưu hạn mức",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  disabledBackgroundColor: const Color(0xFFD8B4FE),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
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

// ─── Widget card trạng thái hiện tại ──────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  final num spent;
  final num amount;
  final double percent;
  final bool isExceeded;
  final bool isWarning;
  final String Function(num) money;

  const _StatusCard({
    required this.spent,
    required this.amount,
    required this.percent,
    required this.isExceeded,
    required this.isWarning,
    required this.money,
  });

  Color get _bgColor => isExceeded
      ? const Color(0xFFFEF2F2)
      : isWarning
          ? const Color(0xFFFFFBEB)
          : const Color(0xFFF0FDF4);

  Color get _borderColor => isExceeded
      ? const Color(0xFFFECACA)
      : isWarning
          ? const Color(0xFFFDE68A)
          : const Color(0xFFBBF7D0);

  Color get _barColor => isExceeded
      ? const Color(0xFFEF4444)
      : isWarning
          ? const Color(0xFFF59E0B)
          : const Color(0xFF10B981);

  Color get _pillBg => isExceeded
      ? const Color(0xFFFEE2E2)
      : isWarning
          ? const Color(0xFFFEF9C3)
          : const Color(0xFFD1FAE5);

  Color get _pillText => isExceeded
      ? const Color(0xFFDC2626)
      : isWarning
          ? const Color(0xFFB45309)
          : const Color(0xFF059669);

  String get _pillLabel => isExceeded
      ? "🚨 Vượt hạn mức"
      : isWarning
          ? "⚠️ Gần hạn mức"
          : "✅ An toàn";

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Hạn mức tháng này",
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _pillBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _pillLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _pillText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Đã chi", style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                  Text(
                    money(spent),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text("Hạn mức", style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                  Text(
                    money(amount),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: (percent / 100).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(_barColor),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "${percent.round()}% đã sử dụng",
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
