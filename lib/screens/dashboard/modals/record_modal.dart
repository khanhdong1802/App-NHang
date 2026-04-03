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
        if (amount > groupBalance) return _toast("Số dư nhóm không đủ: ${_fmt(groupBalance)} đ");

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
      _toast("Ghi chép thất bại: $e");
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
              separatorBuilder: (_, __) => const SizedBox(width: 8),
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
}

/// Chip danh mục (tối giản, bạn có thể map icon/gradient theo tên như React)
class _CategoryChip extends StatelessWidget {
  final String name;
  final bool selected;
  final VoidCallback onTap;
  const _CategoryChip({required this.name, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bg = selected ? const Color(0xFF7C3AED) : const Color(0xFFE8EAF0);
    final fg = selected ? Colors.white : Colors.black87;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 78,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
          boxShadow: selected
              ? [BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 12, offset: const Offset(0, 6))]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.category_rounded, color: fg),
            const SizedBox(height: 6),
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
          ],
        ),
      ),
    );
  }
}
