import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../services/api_config.dart';
import '../../services/dashboard_api.dart';
import 'modals/spending_limit_modal.dart';

class SpendingLimitsPage extends StatefulWidget {
  const SpendingLimitsPage({super.key});

  @override
  State<SpendingLimitsPage> createState() => _SpendingLimitsPageState();
}

class _SpendingLimitsPageState extends State<SpendingLimitsPage> {
  final _api = DashboardApi();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _limits = [];
  String? _userId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      _userId = await _api.getUserId();
      if (_userId == null) throw Exception('Không xác định được người dùng');

      final uri = Uri.parse(
        '${ApiConfig.baseUrl}${ApiConfig.apiPrefix}'
        '/spending-limit/spending-limits/$_userId/summary',
      );
      final res = await http.get(uri);
      if (!mounted) return;

      if (res.statusCode != 200) throw Exception('Lỗi server (${res.statusCode})');

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final data = (body['data'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();

      setState(() { _limits = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _openModal({Map<String, dynamic>? limit}) async {
    if (_userId == null) return;

    // Chuẩn bị currentLimit cho modal nếu đang edit
    Map<String, dynamic>? currentLimit;
    String? prefilledCategoryId;
    String? prefilledCategoryName;

    if (limit != null) {
      final cat = limit['category'] as Map<String, dynamic>?;
      prefilledCategoryId   = cat?['_id']?.toString();
      prefilledCategoryName = cat?['name']?.toString();
      currentLimit = {
        'limit_id':      limit['limit_id']?.toString(),
        'amount':        limit['amount'],
        'spent':         limit['spent'],
        'remaining':     limit['remaining'],
        'percent':       limit['percent'],
        'status':        limit['status'],
        'note':          limit['note'] ?? '',
        'months':        limit['months'] ?? 1,
        'alert_percent': limit['alert_percent'] ?? 80,
        'category_id':   prefilledCategoryId,
        'category_name': prefilledCategoryName,
      };
    }

    final ok = await SpendingLimitModal.open(
      context,
      userId: _userId!,
      currentLimit:          currentLimit,
      prefilledCategoryId:   prefilledCategoryId,
      prefilledCategoryName: prefilledCategoryName,
    );

    if (ok == true && mounted) _load();
  }

  // ── helpers ──────────────────────────────────────────────
  String _fmt(num v) => NumberFormat.decimalPattern('vi').format(v.round());

  String _fmtDate(dynamic raw) {
    if (raw == null) return '';
    try {
      return DateFormat('dd/MM/yyyy').format(DateTime.parse(raw.toString()).toLocal());
    } catch (_) {
      return '';
    }
  }

  Color _statusColor(String status) => switch (status) {
    'exceeded' => const Color(0xFFEF4444),
    'warning'  => const Color(0xFFF59E0B),
    _          => const Color(0xFF10B981),
  };

  Color _statusBg(String status) => switch (status) {
    'exceeded' => const Color(0xFFFEF2F2),
    'warning'  => const Color(0xFFFFFBEB),
    _          => const Color(0xFFF0FDF4),
  };

  Color _barColor(String status) => switch (status) {
    'exceeded' => const Color(0xFFEF4444),
    'warning'  => const Color(0xFFF59E0B),
    _          => const Color(0xFF10B981),
  };

  String _statusLabel(String status) => switch (status) {
    'exceeded' => '🚨 Vượt hạn mức',
    'warning'  => '⚠️ Gần hạn mức',
    _          => '✅ An toàn',
  };

  // ── build ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Hạn mức chi tiêu',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
            tooltip: 'Làm mới',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _limits.isEmpty
                      ? _buildEmpty()
                      : _buildList(),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openModal(),
        backgroundColor: const Color(0xFF7C3AED),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Thêm hạn mức',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
          const SizedBox(height: 12),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: _load, child: const Text('Thử lại')),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
        const Column(
          children: [
            Icon(Icons.tune_rounded, size: 64, color: Color(0xFFD1D5DB)),
            SizedBox(height: 16),
            Text(
              'Chưa có hạn mức nào',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)),
            ),
            SizedBox(height: 8),
            Text(
              'Nhấn "+ Thêm hạn mức" để bắt đầu\nquản lý ngân sách theo danh mục',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF9CA3AF), height: 1.5),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildList() {
    // Tách thành 3 nhóm: exceeded → warning → safe
    final exceeded = _limits.where((l) => l['status'] == 'exceeded').toList();
    final warning  = _limits.where((l) => l['status'] == 'warning').toList();
    final safe     = _limits.where((l) => l['status'] == 'safe').toList();
    final sorted   = [...exceeded, ...warning, ...safe];

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: sorted.length + 1,
      itemBuilder: (_, i) {
        if (i == 0) return _buildSummaryBar(exceeded.length, warning.length, safe.length);
        return _buildLimitCard(sorted[i - 1]);
      },
    );
  }

  Widget _buildSummaryBar(int exceeded, int warning, int safe) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Row(
        children: [
          _summaryChip(Icons.check_circle_rounded, '$safe An toàn', const Color(0xFF10B981), const Color(0xFFF0FDF4)),
          const SizedBox(width: 8),
          _summaryChip(Icons.warning_amber_rounded, '$warning Cảnh báo', const Color(0xFFF59E0B), const Color(0xFFFFFBEB)),
          const SizedBox(width: 8),
          _summaryChip(Icons.cancel_rounded, '$exceeded Vượt', const Color(0xFFEF4444), const Color(0xFFFEF2F2)),
        ],
      ),
    );
  }

  Widget _summaryChip(IconData icon, String text, Color color, Color bg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildLimitCard(Map<String, dynamic> limit) {
    final cat      = limit['category'] as Map<String, dynamic>?;
    final catName  = cat?['name']?.toString() ?? 'Tổng chi tiêu';
    final amount   = (limit['amount'] as num? ?? 0);
    final spent    = (limit['spent']  as num? ?? 0);
    final remaining = (limit['remaining'] as num? ?? 0);
    final percent  = (limit['percent'] as num? ?? 0).toDouble().clamp(0.0, 100.0);
    final status   = limit['status'] as String? ?? 'safe';
    final endDate  = _fmtDate(limit['end_date']);
    final note     = limit['note'] as String? ?? '';

    return GestureDetector(
      onTap: () => _openModal(limit: limit),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _statusColor(status).withValues(alpha: 0.25)),
          boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, 4))],
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: _statusBg(status),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.category_rounded, color: _statusColor(status), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(catName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        if (endDate.isNotEmpty)
                          Text('Đến $endDate', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusBg(status),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _statusLabel(status),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _statusColor(status)),
                    ),
                  ),
                ],
              ),
            ),

            // Progress bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: percent / 100,
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade100,
                  valueColor: AlwaysStoppedAnimation(_barColor(status)),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${percent.round()}% đã dùng',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                  Text('Còn lại ${_fmt(remaining.clamp(0, double.infinity))} đ',
                      style: TextStyle(fontSize: 11, color: _statusColor(status), fontWeight: FontWeight.w700)),
                ],
              ),
            ),

            // Số liệu chi tiết
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: Row(
                children: [
                  _statItem('Đã chi', _fmt(spent), Colors.grey.shade800),
                  _divider(),
                  _statItem('Hạn mức', _fmt(amount), const Color(0xFF7C3AED)),
                  _divider(),
                  _statItem('Còn lại', _fmt(remaining.clamp(0, double.infinity)),
                      remaining < 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981)),
                ],
              ),
            ),

            if (note.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
                ),
                child: Text('📝 $note',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
          Text('đ', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        width: 1, height: 36,
        color: Colors.grey.shade100,
      );
}
