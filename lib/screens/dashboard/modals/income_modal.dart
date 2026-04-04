import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../../../services/api_config.dart';
import '../../../utils/money_input_formatter.dart';

enum IncomeMode { personal, group }

class IncomeModal extends StatefulWidget {
  final String? groupId; // optional: mở sẵn theo group
  const IncomeModal({super.key, this.groupId});

  static Future<bool?> open(BuildContext context, {String? groupId}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => IncomeModal(groupId: groupId),
    );
  }

  @override
  State<IncomeModal> createState() => _IncomeModalState();
}

class _IncomeModalState extends State<IncomeModal> {
  final _storage = const FlutterSecureStorage();

  static const Color _primary = Color(0xFF6D5EF9);
  static const Color _primaryDark = Color(0xFF5B4DF4);
  static const Color _sheetTop = Color(0xFFF6F3FF);
  static const Color _sheetBottom = Color(0xFFFCFBFF);
  static const Color _border = Color(0xFFE8E3F7);
  static const Color _softBg = Color(0xFFF3F0FF);
  static const Color _title = Color(0xFF16171D);
  static const Color _textSoft = Color(0xFF6B7280);
  static const Color _successSoft = Color(0xFFEEF2FF);
  static const Color _errorBg = Color(0xFFFFF1F2);
  static const Color _errorBorder = Color(0xFFFFE4E6);
  static const Color _errorText = Color(0xFFB91C1C);

  IncomeMode mode = IncomeMode.personal;

  // form
  final amountCtl = TextEditingController();
  final noteCtl = TextEditingController();
  String source = "";
  DateTime date = DateTime.now();

  // group
  List<Map<String, dynamic>> groups = [];
  List<Map<String, dynamic>> groupFunds = [];
  String selectedGroupId = "";
  String selectedFundName = "";
  final newFundCtl = TextEditingController();

  bool loading = false;
  String? errorMessage;

  final predefinedSources = const ["Lương", "Bán đồ", "Quà", "Khác"];

  bool get isLockedToGroup => widget.groupId != null && widget.groupId!.isNotEmpty;

  @override
  void initState() {
    super.initState();

    if (isLockedToGroup) {
      mode = IncomeMode.group;
      selectedGroupId = widget.groupId!;
    }

    _loadGroups();
  }

  @override
  void dispose() {
    amountCtl.dispose();
    noteCtl.dispose();
    newFundCtl.dispose();
    super.dispose();
  }

  int _currentAmountValue() {
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

  String _fmt(int v) {
    final s = v.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final idxFromEnd = s.length - i;
      buffer.write(s[i]);
      if (idxFromEnd > 1 && idxFromEnd % 3 == 1) {
        buffer.write(',');
      }
    }
    return buffer.toString();
  }

  Future<String?> _getUserId() async {
    final raw = await _storage.read(key: "user");
    if (raw == null || raw.isEmpty) return null;
    final u = jsonDecode(raw) as Map<String, dynamic>;
    return (u["_id"] ?? u["id"])?.toString();
  }

  Future<String?> _getToken() async {
    return await _storage.read(key: "token");
  }

  Future<void> _loadGroups() async {
    final userId = await _getUserId();
    if (userId == null) return;

    try {
      final uri = Uri.parse(
        "${ApiConfig.baseUrl}${ApiConfig.apiPrefix}/group/groups?userId=$userId",
      );
      final res = await http.get(uri);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final list = (data["groups"] ?? []) as List<dynamic>;
        if (mounted) {
          setState(() {
            groups = list.map((e) => Map<String, dynamic>.from(e)).toList();
          });
        }

        if (mode == IncomeMode.group && selectedGroupId.isNotEmpty) {
          await _loadGroupFunds();
        }
      }
    } catch (_) {
      // ignore, vẫn cho UI chạy
    }
  }

  Future<void> _loadGroupFunds() async {
    if (selectedGroupId.isEmpty) {
      if (mounted) setState(() => groupFunds = []);
      return;
    }
    try {
      final uri = Uri.parse(
        "${ApiConfig.baseUrl}${ApiConfig.apiPrefix}/group/group-funds?groupId=$selectedGroupId",
      );
      final res = await http.get(uri);

      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final funds = (data is Map<String, dynamic>)
            ? (data["funds"] ?? []) as List<dynamic>
            : <dynamic>[];
        setState(() {
          groupFunds = funds
              .where((f) => f != null && (f as Map).containsKey("name"))
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        });
      } else {
        setState(() => groupFunds = []);
      }
    } catch (_) {
      if (mounted) setState(() => groupFunds = []);
    }
  }

  Future<void> _addFund() async {
    if (newFundCtl.text.trim().isEmpty || selectedGroupId.isEmpty) return;

    final payload = {
      "group_id": selectedGroupId,
      "name": newFundCtl.text.trim(),
    };

    try {
      setState(() => loading = true);
      final token = await _getToken();

      final uri = Uri.parse(
        "${ApiConfig.baseUrl}${ApiConfig.apiPrefix}/group/group-funds",
      );
      final res = await http.post(
        uri,
        headers: {
          "Content-Type": "application/json",
          if (token != null) "Authorization": "Bearer $token",
        },
        body: jsonEncode(payload),
      );

      final data = jsonDecode(res.body);
      if (!mounted) return;

      if (res.statusCode == 200 || res.statusCode == 201) {
        if (data is Map<String, dynamic> && (data["_id"] != null)) {
          setState(() {
            groupFunds.add(Map<String, dynamic>.from(data));
            selectedFundName = (data["name"] ?? "").toString();
            newFundCtl.clear();
          });
        }
      } else {
        _showSnack(data["message"]?.toString() ?? "Không thể thêm quỹ mới");
      }
    } catch (_) {
      _showSnack("Lỗi khi thêm quỹ mới");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _save() async {
    final userId = await _getUserId();
    if (userId == null) {
      if (mounted) setState(() => errorMessage = "Bạn chưa đăng nhập.");
      return;
    }

    final amount = num.tryParse(amountCtl.text.replaceAll(',', '')) ?? 0;
    if (amount <= 0 || source.isEmpty) {
      _showSnack("Vui lòng nhập số tiền hợp lệ và chọn nguồn thu!");
      return;
    }

    if (mode == IncomeMode.group) {
      if (selectedGroupId.isEmpty || selectedFundName.trim().isEmpty) {
        _showSnack("Vui lòng chọn nhóm và quỹ nhóm!");
        return;
      }
    }

    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final token = await _getToken();
      if (token == null) {
        if (mounted) {
          setState(() => errorMessage = "Lỗi xác thực. Vui lòng đăng nhập lại.");
        }
        return;
      }

      final dateStr =
          "${date.year.toString().padLeft(4, "0")}-${date.month.toString().padLeft(2, "0")}-${date.day.toString().padLeft(2, "0")}";

      final payload = <String, dynamic>{
        "amount": amount,
        "source": source,
        "received_date": dateStr,
        "note": noteCtl.text.trim(),
        "status": "pending",
      };

      late Uri uri;
      if (mode == IncomeMode.personal) {
        payload["user_id"] = userId;
        uri = Uri.parse("${ApiConfig.baseUrl}${ApiConfig.apiPrefix}/auth/Income");
      } else {
        payload["group_id"] = selectedGroupId;
        payload["fund_name"] = selectedFundName.trim();
        payload["member_id"] = userId;
        payload["payment_method"] = "cash";
        uri = Uri.parse(
          "${ApiConfig.baseUrl}${ApiConfig.apiPrefix}/group/group-contributions",
        );
      }

      final res = await http.post(
        uri,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode(payload),
      );

      final data = jsonDecode(res.body);

      if (!mounted) return;
      if (res.statusCode == 200 || res.statusCode == 201) {
        Navigator.pop(context, true);
        _showSnack("Lưu thu nhập thành công!");
      } else {
        setState(() {
          errorMessage = data["message"]?.toString() ?? "Đã xảy ra lỗi khi lưu";
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => errorMessage = "Lỗi khi gửi dữ liệu đến máy chủ");
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget _quickSuggestRow() {
    final base = _currentAmountValue();
    if (base <= 0) return const SizedBox.shrink();

    final suggestions = _quickMultipliers(base);

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: suggestions.map((v) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                backgroundColor: _successSoft,
                side: const BorderSide(color: _border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                label: Text(
                  _fmt(v),
                  style: const TextStyle(
                    color: _primaryDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onPressed: () {
                  amountCtl.text = _fmt(v);
                  setState(() {});
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        initialChildSize: 0.88,
        minChildSize: 0.55,
        maxChildSize: 0.95,
        builder: (_, scrollCtl) {
          return Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_sheetTop, _sheetBottom],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              border: Border.all(color: Colors.white.withOpacity(0.9)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 24,
                  offset: Offset(0, -8),
                ),
              ],
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 46,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD8D2F3),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 12),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.75),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: _border),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0C000000),
                          blurRadius: 18,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _border),
                          ),
                          child: IconButton(
                            onPressed: loading ? null : () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded, color: _title),
                          ),
                        ),
                        const Expanded(
                          child: Column(
                            children: [
                              Text(
                                "Ghi thu nhập",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: _title,
                                ),
                              ),
                              SizedBox(height: 2),

                            ],
                          ),
                        ),
                        Container(
                          height: 42,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [_primary, _primaryDark],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x336D5EF9),
                                blurRadius: 14,
                                offset: Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: loading ? null : _save,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 18),
                            ),
                            child: Text(
                              loading ? "Đang lưu..." : "Lưu",
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: _softBg,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: _border),
                    ),
                    child: Row(
                      children: [
                        _segBtn(
                          "Cá nhân",
                          mode == IncomeMode.personal,
                          isLockedToGroup
                              ? null
                              : () {
                            setState(() {
                              mode = IncomeMode.personal;
                              errorMessage = null;
                            });
                          },
                        ),
                        _segBtn(
                          "Nhóm",
                          mode == IncomeMode.group,
                          isLockedToGroup
                              ? null
                              : () async {
                            setState(() {
                              mode = IncomeMode.group;
                              errorMessage = null;
                            });
                            await _loadGroups();
                            await _loadGroupFunds();
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                if (errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _errorBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _errorBorder),
                      ),
                      child: Text(
                        errorMessage!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: _errorText,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 8),

                Expanded(
                  child: ListView(
                    controller: scrollCtl,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.80),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: _border),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x0A000000),
                              blurRadius: 18,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _fieldTitle("Số tiền"),
                            _moneyField(),
                            _quickSuggestRow(),

                            const SizedBox(height: 16),
                            _fieldTitle("Nguồn thu"),
                            _sourceDropdown(),

                            const SizedBox(height: 16),
                            _fieldTitle("Ngày nhận"),
                            _datePicker(),

                            if (mode == IncomeMode.group) ...[
                              const SizedBox(height: 16),
                              _fieldTitle("Chọn nhóm"),
                              _groupDropdown(),

                              const SizedBox(height: 16),
                              _fieldTitle("Chọn quỹ nhóm"),
                              _fundDropdown(),

                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: newFundCtl,
                                      decoration: _inputDeco("Tên quỹ mới"),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Container(
                                    height: 50,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [_primary, _primaryDark],
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: ElevatedButton(
                                      onPressed: (loading ||
                                          newFundCtl.text.trim().isEmpty ||
                                          selectedGroupId.isEmpty)
                                          ? null
                                          : _addFund,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                      ),
                                      child: const Text(
                                        "Thêm quỹ",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],

                            const SizedBox(height: 16),
                            _fieldTitle("Ghi chú thêm (nếu có)"),
                            TextField(
                              controller: noteCtl,
                              maxLines: 4,
                              decoration: _inputDeco("Thêm ghi chú..."),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _segBtn(String text, bool active, VoidCallback? onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Opacity(
          opacity: onTap == null ? 0.55 : 1,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              gradient: active
                  ? const LinearGradient(colors: [_primary, _primaryDark])
                  : null,
              color: active ? null : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
              boxShadow: active
                  ? const [
                BoxShadow(
                  color: Color(0x226D5EF9),
                  blurRadius: 12,
                  offset: Offset(0, 5),
                )
              ]
                  : null,
            ),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : _textSoft,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _fieldTitle(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      t,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 13.5,
        color: _title,
      ),
    ),
  );

  InputDecoration _inputDeco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(
      color: Color(0xFF9CA3AF),
      fontWeight: FontWeight.w500,
    ),
    filled: true,
    fillColor: Colors.white.withOpacity(0.96),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: _border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: _border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: _primary, width: 1.5),
    ),
  );

  Widget _moneyField() {
    return TextField(
      controller: amountCtl,
      keyboardType: TextInputType.number,
      inputFormatters: [MoneyInputFormatter()],
      decoration: _inputDeco("0").copyWith(
        suffixText: "đ",
        suffixStyle: const TextStyle(
          fontSize: 12,
          color: Color(0xFF6B7280),
          fontWeight: FontWeight.w600,
        ),
      ),
      textAlign: TextAlign.right,
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _sourceDropdown() {
    return DropdownButtonFormField<String>(
      value: source.isEmpty ? null : source,
      decoration: _inputDeco("Chọn nguồn thu"),
      items: predefinedSources
          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
          .toList(),
      onChanged: (v) => setState(() => source = v ?? ""),
    );
  }

  Widget _datePicker() {
    final dateStr =
        "${date.year.toString().padLeft(4, "0")}-${date.month.toString().padLeft(2, "0")}-${date.day.toString().padLeft(2, "0")}";
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) setState(() => date = picked);
      },
      borderRadius: BorderRadius.circular(18),
      child: InputDecorator(
        decoration: _inputDeco(""),
        child: Text(
          dateStr,
          style: const TextStyle(
            color: _title,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _groupDropdown() {
    return DropdownButtonFormField<String>(
      value: selectedGroupId.isEmpty ? null : selectedGroupId,
      decoration: _inputDeco("Chọn nhóm"),
      items: groups
          .map(
            (g) => DropdownMenuItem(
          value: g["_id"]?.toString() ?? "",
          child: Text((g["name"] ?? "").toString()),
        ),
      )
          .toList(),
      onChanged: isLockedToGroup
          ? null
          : (v) async {
        setState(() {
          selectedGroupId = v ?? "";
          selectedFundName = "";
        });
        await _loadGroupFunds();
      },
    );
  }

  Widget _fundDropdown() {
    return DropdownButtonFormField<String>(
      value: selectedFundName.isEmpty ? null : selectedFundName,
      decoration: _inputDeco("Chọn quỹ nhóm"),
      items: groupFunds
          .where((f) => (f["name"] ?? "").toString().isNotEmpty)
          .map(
            (f) => DropdownMenuItem(
          value: f["name"].toString(),
          child: Text(f["name"].toString()),
        ),
      )
          .toList(),
      onChanged: (v) => setState(() => selectedFundName = v ?? ""),
    );
  }
}