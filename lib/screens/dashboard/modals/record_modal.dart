import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '/models/category.dart';
import '/services/record_api.dart';
import '/utils/money_input_formatter.dart';
import '../widgets/category_grid.dart';

enum PayMode { personal, group }

class RecordModal {
  static Future<bool?> open(
      BuildContext context, {
        String? selectedCategoryId,
        String? groupId,
        int? prefilledAmount,
        String? prefilledNote,
      }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RecordModalSheet(
        selectedCategoryId: selectedCategoryId,
        groupId: groupId,
        prefilledAmount: prefilledAmount,
        prefilledNote: prefilledNote,
      ),
    );
  }
}

class _RecordModalSheet extends StatefulWidget {
  final String? selectedCategoryId;
  final String? groupId;
  final int? prefilledAmount;
  final String? prefilledNote;

  const _RecordModalSheet({
    this.selectedCategoryId,
    this.groupId,
    this.prefilledAmount,
    this.prefilledNote,
  });

  @override
  State<_RecordModalSheet> createState() => _RecordModalSheetState();
}

class _RecordModalSheetState extends State<_RecordModalSheet> {
  final api = RecordApi();

  // form
  final amountCtl = TextEditingController();
  final noteCtl = TextEditingController();
  DateTime date = DateTime.now();

  // data
  List<Category> categories = [];
  String? categoryId;

  PayMode mode = PayMode.personal;

  // group
  List<Map<String, dynamic>> groups = [];
  String? selectedGroupId;
  int groupBalance = 0;
  bool loadingGroupBalance = false;
  String? fundId;
  String? fundName;

  // UI state
  bool loading = true;
  bool saving = false;
  String tab = "category"; // "user" | "category"
  String? _errorMsg;        // lỗi hiện inline, null = không có lỗi

  /// Nếu modal được mở từ trang group, không cho đổi mode/group
  bool get isLockedToGroup => widget.groupId != null;

  @override
  void initState() {
    super.initState();
    categoryId = widget.selectedCategoryId;

    // Điền sẵn từ scan hóa đơn
    if (widget.prefilledAmount != null && widget.prefilledAmount! > 0) {
      amountCtl.text = NumberFormat.decimalPattern().format(widget.prefilledAmount);
    }
    if (widget.prefilledNote != null && widget.prefilledNote!.isNotEmpty) {
      noteCtl.text = widget.prefilledNote!;
    }

    if (isLockedToGroup) {
      mode = PayMode.group;
      selectedGroupId = widget.groupId;
      tab = "category";
    }

    // Xoá lỗi ngay khi user bắt đầu sửa số tiền
    amountCtl.addListener(() {
      if (_errorMsg != null && mounted) {
        setState(() => _errorMsg = null);
      }
    });

    _init();
  }

  Future<void> _init() async {
    try {
      // song song fetch categories và groups
      final responses = await Future.wait([
        api.fetchCategories(),
        api.fetchGroupsForMe(),
      ]);

      if (!mounted) return;

      final cats = responses[0] as List<Category>;
      final gs = responses[1] as List<Map<String, dynamic>>;

      setState(() {
        categories = cats;
        groups = gs;
        loading = false;
        if (categoryId == null && cats.isNotEmpty) categoryId = cats.first.id;
      });

      // Nếu đang ở mode group (hoặc do user chọn, hoặc do truyền từ ngoài vào)
      // thì tải thông tin balance/quỹ của group đó
      if (mode == PayMode.group && selectedGroupId != null) {
        await _loadGroupMeta(selectedGroupId!);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      _toast("Không tải được dữ liệu: $e");
    }
  }

  int _amountValue() {
    final raw = amountCtl.text.replaceAll(',', '');
    return int.tryParse(raw) ?? 0;
  }

  List<int> _quickMultipliers(int base) {
    if (base <= 0) return [];
    return [
      base * 1000,
      base * 10000,
      base * 100000,
      base * 1000000,
    ];
  }

  String _fmt(int v) => NumberFormat.decimalPattern().format(v);

  String _dateYmd(DateTime d) => DateFormat("yyyy-MM-dd").format(d);

  Future<void> _onPickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => date = picked);
  }

  Future<void> _onModeChanged(PayMode m) async {
    if (isLockedToGroup) return; // không cho đổi nếu bị khoá

    setState(() {
      mode = m;
      if (mode == PayMode.personal) {
        selectedGroupId = null;
        groupBalance = 0;
        fundId = null;
        fundName = null;
      }
      // khi chuyển sang group, tab mặc định là chọn user/group
      if (mode == PayMode.group) {
        tab = "user";
      }
    });

    if (mode == PayMode.group && selectedGroupId != null) {
      await _loadGroupMeta(selectedGroupId!);
    }
  }

  Future<void> _loadGroupMeta(String groupId) async {
    setState(() => loadingGroupBalance = true);
    try {
      final bal = await api.fetchGroupActualBalance(groupId);
      final fund = await api.pickCategorizationFund(groupId);
      if (!mounted) return;
      setState(() {
        groupBalance = bal;
        fundId = fund?["id"];
        fundName = fund?["name"];
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        groupBalance = 0;
        fundId = null;
        fundName = null;
      });
    } finally {
      if (mounted) setState(() => loadingGroupBalance = false);
    }
  }

  Future<void> _save() async {
    final amount = _amountValue();
    if (amount <= 0) return _toast("Vui lòng nhập số tiền hợp lệ!");
    if (categoryId == null || categoryId!.isEmpty) return _toast("Vui lòng chọn danh mục!");

    final cat = categories.firstWhere((c) => c.id == categoryId, orElse: () => Category(id: categoryId!, name: "Không rõ"));
    final ymd = _dateYmd(date);
    final note = noteCtl.text.trim();

    setState(() => saving = true);
    try {
      if (mode == PayMode.personal) {
        await api.withdrawPersonal(
          amount: amount,
          categoryId: categoryId!,
          categoryName: cat.name,
          note: note,
          dateYmd: ymd,
        );
      } else { // group mode
        if (selectedGroupId == null || selectedGroupId!.isEmpty) return _toast("Vui lòng chọn nhóm!");
        if (fundId == null || fundId!.isEmpty) return _toast("Nhóm cần có quỹ để phân loại chi tiêu.");
        if (amount > groupBalance) { _setError('Số dư nhóm không đủ (còn ${_fmt(groupBalance)} đ)\nVui lòng nạp thêm vào quỹ nhóm.'); return; }

        await api.createGroupExpense(
          fundId: fundId!,
          groupId: selectedGroupId!,
          amount: amount,
          categoryId: categoryId!,
          description: note,
          dateYmd: ymd,
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      // Bỏ prefix "Exception: " do Dart thêm vào, lấy message thuần túy
      final raw = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');

      // Map server message → thông báo thân thiện (hiện inline, không dùng SnackBar)
      if (raw.contains('không đủ') || raw.toLowerCase().contains('balance') || raw.contains('insufficient')) {
        _setError('Số dư của bạn hiện tại không đủ\nVui lòng nạp thêm tiền vào tài khoản.');
      } else {
        _setError(raw.isNotEmpty ? raw : 'Ghi chép thất bại, vui lòng thử lại.');
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// Hiện lỗi inline (banner cố định dưới header) thay vì SnackBar.
  void _setError(String msg) {
    if (!mounted) return;
    setState(() => _errorMsg = msg);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(color: Color(0xFF0B0B0F)),
        child: SafeArea(
          top: false,
          child: Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : Column(
              children: [
                _header(),
                // ── Error banner cố định, luôn hiện dù đang scroll ─────
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  child: _errorMsg != null
                      ? _buildErrorBanner(_errorMsg!)
                      : const SizedBox.shrink(),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
                    children: [
                      _modePicker(),
                      const SizedBox(height: 10),
                      _tabs(),
                      const SizedBox(height: 10),
                      if (tab == "user") _userOrGroupSection(),
                      if (tab == "category") _categorySection(),
                      const SizedBox(height: 14),
                      _amountSection(),
                      const SizedBox(height: 14),
                      _dateSection(),
                      const SizedBox(height: 14),
                      _noteSection(),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context, false),
            icon: const Icon(Icons.close_rounded),
          ),
          const Expanded(
            child: Text("Ghi chép", textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: saving ? null : _save,
            child: saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text("Lưu"),
          )
        ],
      ),
    );
  }

  Widget _modePicker() {
    return Row(
      children: [
        Expanded(
          child: _pill(
            selected: mode == PayMode.personal,
            text: "Tiền cá nhân",
            onTap: isLockedToGroup ? null : () => _onModeChanged(PayMode.personal),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _pill(
            selected: mode == PayMode.group,
            text: "Chi tiêu nhóm",
            onTap: isLockedToGroup ? null : () => _onModeChanged(PayMode.group),
          ),
        ),
      ],
    );
  }

  Widget _tabs() {
    final left = (mode == PayMode.group) ? "Chọn nhóm" : "Người sử dụng";
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _tabBtn(left, "user"),
        const SizedBox(width: 10),
        _tabBtn("Danh mục", "category"),
      ],
    );
  }

  Widget _tabBtn(String label, String key) {
    final selected = tab == key;
    return GestureDetector(
      onTap: () => setState(() => tab = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE9E7FF) : const Color(0xFFF2F3F6),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? const Color(0xFF4C3BCF) : Colors.black54,
          ),
        ),
      ),
    );
  }

  Widget _userOrGroupSection() {
    if (mode == PayMode.personal) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFFF3F0FF), borderRadius: BorderRadius.circular(16)),
        child: const Row(
          children: [
            CircleAvatar(radius: 18, child: Icon(Icons.person)),
            SizedBox(width: 10),
            Expanded(child: Text("Thực hiện bởi (Cá nhân)", style: TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
      );
    }

    // group
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Chi tiêu từ tài khoản nhóm", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black54)),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text("Nhóm", style: TextStyle(fontSize: 12, color: Colors.black54)),
            const Spacer(),
            DropdownButton<String>(
              value: selectedGroupId,
              hint: const Text("-- Chọn nhóm --"),
              items: groups
                  .map((g) => DropdownMenuItem(
                        value: g["_id"]?.toString(),
                        child: Text(g["name"]?.toString() ?? ""),
                      ))
                  .toList(),
              // nếu bị khoá thì không cho đổi
              onChanged: isLockedToGroup
                  ? null
                  : (v) async {
                      setState(() => selectedGroupId = v);
                      if (v != null) await _loadGroupMeta(v);
                    },
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (selectedGroupId != null)
          Text(
            loadingGroupBalance
                ? "Số dư tài khoản nhóm: Đang tải..."
                : "Số dư tài khoản nhóm: ${_fmt(groupBalance)} đ",
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        if (selectedGroupId != null)
          Text(
            "(Chi tiêu sẽ được phân loại vào quỹ: ${fundName ?? "Chưa xác định"})",
            style: const TextStyle(fontSize: 11, color: Colors.black38),
          ),
      ],
    );
  }

  Widget _categorySection() {
    final selectedCat = categories.where((c) => c.id == categoryId).isEmpty
        ? null
        : categories.firstWhere((c) => c.id == categoryId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Danh mục",
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black54)),
        const SizedBox(height: 10),
        CategoryGrid(
          categories: categories,
          selected: selectedCat,
          onTap: (cat) => setState(() => categoryId = cat.id),
        ),
      ],
    );
  }

  Widget _amountSection() {
    final base = _amountValue();
    final suggestions = _quickMultipliers(base);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Số tiền",
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black54)),
        const SizedBox(height: 8),
        TextField(
          controller: amountCtl,
          keyboardType: TextInputType.number,
          inputFormatters: [MoneyInputFormatter()],
          onChanged: (_) => setState(() {}),
          textAlign: TextAlign.right,
          decoration: InputDecoration(
            hintText: "0",
            suffixText: "đ",
            filled: true,
            fillColor: const Color(0xFFF5F6FA),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
        ),
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: suggestions.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final v = suggestions[i];
                return ActionChip(
                  label: Text(_fmt(v)),
                  onPressed: () {
                    amountCtl.text = _fmt(v);
                    setState(() {});
                  },
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _dateSection() {
    return Row(
      children: [
        const Expanded(
          child: Text("Ngày", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black54)),
        ),
        TextButton.icon(
          onPressed: _onPickDate,
          icon: const Icon(Icons.calendar_month_rounded, size: 18),
          label: Text(_dateYmd(date)),
        ),
      ],
    );
  }

  Widget _noteSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Mô tả", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black54)),
        const SizedBox(height: 8),
        TextField(
          controller: noteCtl,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: "Thêm ghi chú...",
            filled: true,
            fillColor: const Color(0xFFF5F6FA),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  Widget _pill({required bool selected, required String text, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.6 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFEEE9FF) : const Color(0xFFF2F3F6),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? const Color(0xFF4C3BCF) : Colors.black54,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Error banner ─────────────────────────────────────────
  Widget _buildErrorBanner(String msg) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.error_outline_rounded,
                color: Color(0xFFDC2626), size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              msg,
              style: const TextStyle(
                color: Color(0xFF991B1B),
                fontWeight: FontWeight.w600,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _errorMsg = null),
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(Icons.close_rounded,
                  color: Color(0xFFDC2626), size: 18),
            ),
          ),
        ],
      ),
    );
  }
}
