import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/group_api.dart';

class CreateRoomPage extends StatefulWidget {
  final String createdBy;
  final Future<String?> Function()? tokenProvider;

  const CreateRoomPage({
    super.key,
    required this.createdBy,
    this.tokenProvider,
  });

  @override
  State<CreateRoomPage> createState() => _CreateRoomPageState();
}

class _CreateRoomPageState extends State<CreateRoomPage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final _groupNameCtrl = TextEditingController();
  final _memberEmailCtrl = TextEditingController();

  final _groupNameFocus = FocusNode();
  final _memberEmailFocus = FocusNode();

  late final GroupApi api;
  Timer? _debounce;

  bool loading = false;
  bool searching = false;

  List<Map<String, dynamic>> suggestions = [];

  static const _primary = Color(0xFF6D5EF9);
  static const _secondary = Color(0xFF9B5CF6);
  static const _bg = Color(0xFFF5F6FA);
  static const _card = Colors.white;
  static const _text = Color(0xFF171A22);
  static const _muted = Color(0xFF7B8190);
  static const _border = Color(0xFFE8EAF2);

  late final AnimationController _pageCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _topAnim;
  late final Animation<Offset> _sheetAnim;

  @override
  void initState() {
    super.initState();

    api = GroupApi(tokenProvider: widget.tokenProvider);

    _pageCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );

    _fadeAnim = CurvedAnimation(
      parent: _pageCtrl,
      curve: Curves.easeOutCubic,
    );

    _topAnim = Tween<Offset>(
      begin: const Offset(0, -0.04),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _pageCtrl,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _sheetAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _pageCtrl,
        curve: const Interval(0.1, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _pageCtrl.forward();
    });

    _groupNameCtrl.addListener(() {
      if (mounted) setState(() {});
    });

    _memberEmailCtrl.addListener(() {
      if (mounted) setState(() {});
      _debounce?.cancel();

      final q = _memberEmailCtrl.text.trim();

      if (q.isEmpty) {
        if (!mounted) return;
        setState(() {
          suggestions = [];
          searching = false;
        });
        return;
      }

      _debounce = Timer(const Duration(milliseconds: 280), () {
        _searchUsers(q);
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _pageCtrl.dispose();

    _groupNameCtrl.dispose();
    _memberEmailCtrl.dispose();

    _groupNameFocus.dispose();
    _memberEmailFocus.dispose();
    super.dispose();
  }

  bool get _canSubmit => _groupNameCtrl.text.trim().length >= 2 && !loading;

  Future<void> _searchUsers(String q) async {
    if (!mounted) return;
    setState(() => searching = true);

    try {
      final result = await api.searchUsers(q);

      if (!mounted) return;
      setState(() {
        suggestions = result
            .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
            .toList();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => suggestions = []);
    } finally {
      if (!mounted) return;
      setState(() => searching = false);
    }
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;

    final ok = _formKey.currentState!.validate();
    if (!ok) return;

    FocusScope.of(context).unfocus();
    HapticFeedback.lightImpact();

    setState(() => loading = true);

    try {
      await api.createInvitation(
        name: _groupNameCtrl.text.trim(),
        createdBy: widget.createdBy,
        memberEmail: _memberEmailCtrl.text.trim().isEmpty
            ? null
            : _memberEmailCtrl.text.trim(),
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ Tạo nhóm thất bại: $e"),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  String? _validateGroupName(String? v) {
    if (v == null || v.trim().isEmpty) {
      return "Vui lòng nhập tên nhóm";
    }
    if (v.trim().length < 2) {
      return "Tên nhóm tối thiểu 2 ký tự";
    }
    return null;
  }

  String? _validateEmail(String? v) {
    final text = (v ?? '').trim();
    if (text.isEmpty) return null;

    final emailRegex = RegExp(r'^[\w\.\-]+@([\w\-]+\.)+[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(text)) {
      return "Email không hợp lệ";
    }
    return null;
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Color(0xFF9CA3AF),
        fontWeight: FontWeight.w500,
      ),
      prefixIcon: Padding(
        padding: const EdgeInsets.all(12),
        child: Container(
          decoration: BoxDecoration(
            color: _primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: _primary, size: 19),
        ),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 52, minHeight: 52),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF8F9FD),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
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
        borderSide: const BorderSide(color: _primary, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.4),
      ),
    );
  }

  Widget _buildSuggestions() {
    final q = _memberEmailCtrl.text.trim();
    if (q.isEmpty) return const SizedBox.shrink();

    if (searching) {
      return Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FD),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text(
              "Đang tìm...",
              style: TextStyle(
                color: _muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    if (suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 16,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: suggestions.length > 4 ? 4 : suggestions.length,
          separatorBuilder: (_, __) =>
          const Divider(height: 1, color: _border),
          itemBuilder: (_, i) {
            final item = suggestions[i];
            final name = (item['name'] ?? 'Không tên').toString();
            final email = (item['email'] ?? '').toString();
            final first = name.isNotEmpty ? name.trim()[0].toUpperCase() : '?';

            return InkWell(
              onTap: () {
                _memberEmailCtrl.text = email;
                setState(() => suggestions = []);
                FocusScope.of(context).unfocus();
              },
              child: Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_primary, _secondary],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          first,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
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
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _text,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _muted,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.north_west_rounded,
                      size: 18,
                      color: _muted,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildButton() {
    final enabled = _canSubmit;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: enabled
            ? const LinearGradient(colors: [_primary, _secondary])
            : null,
        color: enabled ? null : const Color(0xFFD7DBE7),
        boxShadow: enabled
            ? const [
          BoxShadow(
            color: Color(0x226D5EF9),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: enabled ? _submit : null,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              child: loading
                  ? const Row(
                key: ValueKey('loading'),
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                      AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 10),
                  Text(
                    "Đang tạo...",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              )
                  : Text(
                _memberEmailCtrl.text.trim().isEmpty
                    ? "Tạo nhóm"
                    : "Tạo nhóm & mời",
                key: const ValueKey('submit'),
                style: TextStyle(
                  color: enabled ? Colors.white : const Color(0xFF7E8697),
                  fontWeight: FontWeight.w800,
                  fontSize: 15.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: Row(
          children: [
            _CircleIconButton(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: () => Navigator.pop(context),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.14),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withOpacity(0.18)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.groups_2_rounded, color: Colors.white, size: 15),
                  SizedBox(width: 6),
                  Text(
                    "Chi tiêu chung",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHero() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 84, 16, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.18)),
            ),
            child: const Icon(
              Icons.group_add_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            "Tạo nhóm mới",
            style: TextStyle(
              color: Colors.white,
              fontSize: 29,
              height: 1.05,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSheet() {
    return Container(
      decoration: const BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 26),
        children: [
          Center(
            child: Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.10),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x10000000),
                  blurRadius: 24,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Thông tin nhóm",
                    style: TextStyle(
                      color: _text,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 18),

                  const Text(
                    "Tên nhóm",
                    style: TextStyle(
                      color: _text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _groupNameCtrl,
                    focusNode: _groupNameFocus,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) {
                      FocusScope.of(context).requestFocus(_memberEmailFocus);
                    },
                    validator: _validateGroupName,
                    decoration: _inputDecoration(
                      hint: "Ví dụ: Nhà trọ, Du lịch, Quỹ lớp",
                      icon: Icons.groups_rounded,
                      suffixIcon: _groupNameCtrl.text.trim().isEmpty
                          ? null
                          : IconButton(
                        onPressed: _groupNameCtrl.clear,
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  const Text(
                    "Mời thành viên",
                    style: TextStyle(
                      color: _text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _memberEmailCtrl,
                    focusNode: _memberEmailFocus,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    validator: _validateEmail,
                    decoration: _inputDecoration(
                      hint: "Nhập email",
                      icon: Icons.person_add_alt_1_rounded,
                      suffixIcon: _memberEmailCtrl.text.trim().isEmpty
                          ? null
                          : IconButton(
                        onPressed: () {
                          _memberEmailCtrl.clear();
                          setState(() => suggestions = []);
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ),
                  ),

                  _buildSuggestions(),

                  const SizedBox(height: 22),
                  _buildButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const topHeight = 220.0;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_primary, _secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          Positioned(
            top: -60,
            right: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.10),
              ),
            ),
          ),

          Positioned(
            top: 100,
            left: -90,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.06),
              ),
            ),
          ),

          FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _topAnim,
              child: _buildHeader(context),
            ),
          ),

          FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _topAnim,
              child: _buildHero(),
            ),
          ),

          Positioned.fill(
            top: topHeight,
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _sheetAnim,
                child: _buildSheet(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleIconButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.14),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}