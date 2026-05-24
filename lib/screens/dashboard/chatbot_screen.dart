import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';

// ChatMessage và ChatbotProvider được import từ một nơi duy nhất
import '../../providers/chatbot_provider.dart';
import 'modals/record_modal.dart';

// ══════════════════════════════════════════════════════════════
//  SCREEN
// ══════════════════════════════════════════════════════════════
class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen>
    with TickerProviderStateMixin {
  // ── UI-only state (không ảnh hưởng lịch sử chat) ──────────
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _storage = const FlutterSecureStorage();
  final _picker = ImagePicker();
  late AnimationController _pulseController;

  // ── Config ─────────────────────────────────────────────────
  static String get _baseUrl =>
      kIsWeb ? 'http://localhost:3000/api' : 'http://10.0.2.2:3000/api';

  // ── Gradient / bubble colors ───────────────────────────────
  static const _gradStart = Color(0xFF6C3DE8);
  static const _gradMid   = Color(0xFF4A55D4);
  static const _gradEnd   = Color(0xFF2C3E9E);
  static const _bubbleBot = Color(0xFF3D2D8E);
  static const _glassCard = Color(0x22FFFFFF);

  // ── Quick suggestions ─────────────────────────────────────
  static const _suggestions = [
    ('💰', 'Phân tích chi tiêu tháng này'),
    ('📊', 'Lời khuyên tiết kiệm tiền'),
    ('📷', 'Scan hoá đơn'),
    ('📋', 'Cách đặt hạn mức ngân sách'),
  ];

  // ══════════════════════════════════════════════════════════
  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    // Khởi tạo tin chào mừng nếu chưa có (giữ nguyên nếu đã có)
    // Dùng addPostFrameCallback để Provider đã sẵn sàng
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ChatbotProvider>().initWelcomeIfEmpty();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════
  //  CLIENT-SIDE FILTER
  // ══════════════════════════════════════════════════════════
  static const _offTopicKeywords = [
    'code', 'lập trình', 'javascript', 'python', 'html',
    'thời tiết', 'nhiệt độ', 'mưa', 'nắng',
    'phim', 'nhạc', 'bài hát', 'game', 'trò chơi',
    'bóng đá', 'thể thao', 'world cup',
    'tình yêu', 'người yêu', 'chia tay',
  ];

  bool _isOffTopic(String message) {
    final lower = message.toLowerCase();
    return _offTopicKeywords.any((kw) => lower.contains(kw));
  }

  // ══════════════════════════════════════════════════════════
  //  SEND MESSAGE
  // ══════════════════════════════════════════════════════════
  Future<void> _sendMessage(String text) async {
    final bot = context.read<ChatbotProvider>();
    if (text.trim().isEmpty || bot.isSending) return;

    final trimmed = text.trim();

    // Build lịch sử trước khi thêm tin mới
    final history = bot.messages
        .where((m) => !m.isLoading)
        .map((m) => {
              'role': m.isUser ? 'user' : 'assistant',
              'content': m.content,
            })
        .toList();

    final userMsg = ChatMessage(content: trimmed, isUser: true);

    // ── Client-side off-topic filter ──────────────────────
    if (_isOffTopic(trimmed)) {
      bot.addMessages([
        userMsg,
        ChatMessage(
          content:
              'Xin lỗi, tôi chỉ hỗ trợ câu hỏi về tài chính cá nhân 💰\n\n'
              'Thử hỏi tôi về:\n'
              '• Chi tiêu & ngân sách\n'
              '• Tiết kiệm & đầu tư cơ bản\n'
              '• Phân tích hoá đơn',
          isUser: false,
        ),
      ]);
      _controller.clear();
      _scrollToBottom();
      return;
    }

    // ── Gửi lên server ────────────────────────────────────
    final loadingMsg = ChatMessage(content: '', isUser: false, isLoading: true);
    bot.addMessages([userMsg, loadingMsg]);
    bot.setSending(true);
    _controller.clear();
    _scrollToBottom();

    try {
      final token = await _storage.read(key: 'token');

      final res = await http
          .post(
            Uri.parse('$_baseUrl/chatbot/send'),
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'message': trimmed, 'history': history}),
          )
          .timeout(const Duration(seconds: 30));

      final data = jsonDecode(res.body) as Map<String, dynamic>;

      if (res.statusCode >= 400) {
        final errMsg =
            data['error'] ?? data['message'] ?? 'Lỗi server (${res.statusCode})';
        bot.replaceLastWith(
            ChatMessage(content: '❌ $errMsg', isUser: false));
        return;
      }

      final reply = data['reply'] as String? ??
          data['message'] as String? ??
          'Xin lỗi, có lỗi xảy ra. Vui lòng thử lại.';
      bot.replaceLastWith(ChatMessage(content: reply, isUser: false));
    } on TimeoutException {
      bot.replaceLastWith(ChatMessage(
        content:
            '⏱ Server phản hồi quá lâu (>30 giây).\nVui lòng thử lại sau giây lát.',
        isUser: false,
      ));
    } on http.ClientException catch (e) {
      debugPrint('ClientException: $e');
      bot.replaceLastWith(ChatMessage(
        content:
            '❌ Không thể kết nối server.\nVui lòng kiểm tra server backend đã chạy chưa.',
        isUser: false,
      ));
    } on FormatException catch (e) {
      debugPrint('FormatException: $e');
      bot.replaceLastWith(ChatMessage(
        content:
            '❌ Server trả về phản hồi không hợp lệ.\nVui lòng kiểm tra logs server.',
        isUser: false,
      ));
    } catch (e) {
      debugPrint('Chat unknown error: $e');
      bot.replaceLastWith(ChatMessage(
        content: '❌ Lỗi: ${e.runtimeType}\nVui lòng thử lại.',
        isUser: false,
      ));
    } finally {
      bot.setSending(false);
      _scrollToBottom();
    }
  }

  // ══════════════════════════════════════════════════════════
  //  SCAN RECEIPT
  // ══════════════════════════════════════════════════════════
  Future<void> _scanReceipt() async {
    // Capture provider TRƯỚC async gap để tránh use_build_context_synchronously
    final bot = context.read<ChatbotProvider>();

    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final loadingMsg = ChatMessage(
      content: '📷 Đang phân tích hoá đơn...',
      isUser: false,
      isLoading: true,
    );
    bot.addMessage(loadingMsg);
    _scrollToBottom();

    try {
      final token = await _storage.read(key: 'token');
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/chatbot/scan-receipt'),
      );
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      // fromBytes — hoạt động trên cả Web lẫn Mobile
      final bytes = await picked.readAsBytes();
      final ext   = picked.name.split('.').last.toLowerCase();
      request.files.add(http.MultipartFile.fromBytes(
        'image',
        bytes,
        filename: picked.name,
        contentType: MediaType('image', _imageMime(ext)),
      ));

      final streamed = await request.send().timeout(const Duration(seconds: 30));
      final res = await http.Response.fromStream(streamed);

      if (res.statusCode >= 400) {
        final err = jsonDecode(res.body);
        throw Exception(err['error'] ?? 'Lỗi server (${res.statusCode})');
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final summary = _formatScanResult(data);
      final scannedAmount = (data['amount'] as num? ?? 0).round();

      final resultMessages = <ChatMessage>[
        ChatMessage(content: summary, isUser: false),
        // Hỏi ghi chép nếu đọc được số tiền
        if (scannedAmount > 0)
          ChatMessage(
            content: 'Bạn có muốn ghi chép lại khoản chi tiêu này không? 📝',
            isUser: false,
            actionType: 'record_expense',
            actionData: {
              'amount': scannedAmount,
              'description': (data['description'] as String? ?? '').trim(),
              'category_id': (data['category_id'] as String? ?? ''),
            },
          ),
      ];

      bot.replaceLastWithMany(resultMessages);
    } on TimeoutException {
      bot.replaceLastWith(ChatMessage(
        content: '⏱ Phân tích hoá đơn mất quá nhiều thời gian. Thử lại nhé.',
        isUser: false,
      ));
    } on http.ClientException {
      bot.replaceLastWith(ChatMessage(
        content: '❌ Không thể kết nối server để scan hoá đơn.',
        isUser: false,
      ));
    } catch (e) {
      debugPrint('Scan receipt error: $e');
      bot.replaceLastWith(ChatMessage(
        content: '❌ Không thể scan hoá đơn: $e',
        isUser: false,
      ));
    }
    _scrollToBottom();
  }

  // ══════════════════════════════════════════════════════════
  //  ACTION: GHI CHÉP SAU KHI SCAN
  // ══════════════════════════════════════════════════════════
  Future<void> _onRecordExpense(ChatMessage msg) async {
    if (!mounted) return;

    // Capture provider TRƯỚC async gap
    final bot = context.read<ChatbotProvider>();

    final data        = msg.actionData!;
    final amount      = data['amount'] as int? ?? 0;
    final description = (data['description'] as String? ?? '').trim();
    final categoryId  = (data['category_id'] as String? ?? '').trim();

    final ok = await RecordModal.open(
      context,
      prefilledAmount:    amount > 0 ? amount : null,
      prefilledNote:      description.isNotEmpty ? description : null,
      selectedCategoryId: categoryId.isNotEmpty  ? categoryId  : null,
    );

    if (!mounted) return;

    if (ok == true) {
      bot.replaceMessage(
        msg,
        ChatMessage(content: '✅ Đã ghi chép chi tiêu thành công!', isUser: false),
      );
      _scrollToBottom();
    }
    // Nếu user đóng modal không lưu → giữ nguyên nút để thử lại
  }

  void _onSkipRecord(ChatMessage msg) {
    context.read<ChatbotProvider>().replaceMessage(
      msg,
      ChatMessage(content: 'OK, bỏ qua lần này nhé 👌', isUser: false),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  HELPERS
  // ══════════════════════════════════════════════════════════
  String _formatScanResult(Map<String, dynamic> data) {
    final amount      = data['amount'];
    final description = data['description'] ?? '';
    final items       = (data['items'] as List?)?.cast<String>() ?? [];
    final catName     = data['category_name'] ?? '';

    if (amount == null || amount == 0) {
      return '📋 Không đọc được hoá đơn.\nVui lòng chụp rõ hơn và thử lại.';
    }

    final sb = StringBuffer();
    sb.writeln('📋 Kết quả scan hoá đơn:\n');
    sb.writeln('💰 Tổng tiền: ${_formatMoney(amount as num)}');
    if (description.toString().isNotEmpty) sb.writeln('📝 Nội dung: $description');
    if (catName.toString().isNotEmpty)     sb.writeln('🏷️  Danh mục: $catName');
    if (items.isNotEmpty) {
      sb.writeln('\nCác mục:');
      for (final item in items) { sb.writeln('  • $item'); }
    }
    return sb.toString().trim();
  }

  String _imageMime(String ext) {
    switch (ext) {
      case 'jpg':
      case 'jpeg': return 'jpeg';
      case 'png':  return 'png';
      case 'webp': return 'webp';
      case 'gif':  return 'gif';
      default:     return 'jpeg';
    }
  }

  String _formatMoney(num v) {
    final s = v.round().toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return '$bufđ';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ══════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    // watch để rebuild khi messages hoặc isSending thay đổi
    final bot = context.watch<ChatbotProvider>();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            _buildBotAvatar(size: 36),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('AI Finance Bot',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
                Text('Tư vấn tài chính cá nhân',
                    style: TextStyle(color: Color(0xBBFFFFFF), fontSize: 11)),
              ],
            ),
          ],
        ),
        actions: [
          // Nút xoá lịch sử chat
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: Colors.white70, size: 22),
            tooltip: 'Xoá lịch sử chat',
            onPressed: () => _confirmClearChat(context),
          ),
        ],
      ),

      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_gradStart, _gradMid, _gradEnd],
            stops: [0.0, 0.45, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: bot.messages.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        itemCount: bot.messages.length,
                        itemBuilder: (_, i) =>
                            _buildMessageItem(bot.messages[i]),
                      ),
              ),
              if (!bot.isSending) _buildQuickSuggestions(),
              _buildInputBar(bot.isSending),
            ],
          ),
        ),
      ),
    );
  }

  // ── Xác nhận xoá lịch sử ─────────────────────────────────
  void _confirmClearChat(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xoá lịch sử chat?'),
        content: const Text('Toàn bộ tin nhắn sẽ bị xoá. Tiếp tục?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<ChatbotProvider>().clearChat();
              // Thêm lại welcome message
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) context.read<ChatbotProvider>().initWelcomeIfEmpty();
              });
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  WIDGETS
  // ══════════════════════════════════════════════════════════

  Widget _buildBotAvatar({double size = 44}) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (_, child) {
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF9B6DFF), Color(0xFF5B5BD6)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF9B6DFF)
                    .withValues(alpha: 0.3 + 0.2 * _pulseController.value),
                blurRadius: 8 + 6 * _pulseController.value,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Icon(Icons.smart_toy_rounded,
              color: Colors.white, size: size * 0.5),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildBotAvatar(size: 80),
          const SizedBox(height: 24),
          const Text('Trợ lý Tài chính AI',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text('Hỏi về chi tiêu, ngân sách, tiết kiệm...',
              style: TextStyle(color: Color(0xBBFFFFFF), fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildMessageItem(ChatMessage msg) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            msg.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!msg.isUser) ...[
            _buildBotAvatar(size: 32),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: msg.isLoading
                ? _buildLoadingBubble()
                : _buildBubble(msg),
          ),
          if (msg.isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0x44FFFFFF),
              child: const Icon(Icons.person_rounded,
                  color: Colors.white, size: 18),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBubble(ChatMessage msg) {
    final isUser    = msg.isUser;
    final hasAction = msg.actionType != null;

    return Container(
      constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * (hasAction ? 0.82 : 0.72)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isUser ? const Color(0xFFFFFFFF) : _bubbleBot,
        border: hasAction
            ? Border.all(
                color: const Color(0xFF9B6DFF).withValues(alpha: 0.45),
                width: 1.2)
            : null,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: Radius.circular(isUser ? 20 : 4),
          bottomRight: Radius.circular(isUser ? 4 : 20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            msg.content,
            style: TextStyle(
              color: isUser ? const Color(0xFF3D2D8E) : Colors.white,
              fontSize: 14,
              height: 1.5,
              fontWeight: FontWeight.w400,
            ),
          ),
          if (msg.actionType == 'record_expense') ...[
            const SizedBox(height: 12),
            _buildRecordButtons(msg),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingBubble() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: _bubbleBot,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
          bottomRight: Radius.circular(20),
          bottomLeft: Radius.circular(4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          return AnimatedBuilder(
            animation: _pulseController,
            builder: (_, _) {
              final delay = i * 0.25;
              final t = (_pulseController.value - delay).clamp(0.0, 1.0);
              return Container(
                margin: EdgeInsets.only(right: i < 2 ? 5 : 0),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.4 + 0.6 * t),
                  shape: BoxShape.circle,
                ),
              );
            },
          );
        }),
      ),
    );
  }

  // ── Action buttons (ghi chép / bỏ qua) ───────────────────
  Widget _buildRecordButtons(ChatMessage msg) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: () => _onRecordExpense(msg),
            icon: const Icon(Icons.edit_note_rounded, size: 16),
            label: const Text('Ghi chép',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton(
            onPressed: () => _onSkipRecord(msg),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: const BorderSide(color: Colors.white30),
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Bỏ qua',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickSuggestions() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _suggestions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final (emoji, label) = _suggestions[i];
          return GestureDetector(
            onTap: () => label == 'Scan hoá đơn'
                ? _scanReceipt()
                : _sendMessage(label),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _glassCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24),
              ),
              child: Text('$emoji $label',
                  style:
                      const TextStyle(color: Colors.white, fontSize: 12.5)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputBar(bool isSending) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
      decoration: BoxDecoration(
        color: const Color(0x33FFFFFF),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildCircleBtn(
            icon: Icons.image_outlined,
            onTap: _scanReceipt,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: _sendMessage,
              decoration: const InputDecoration(
                hintText: 'Hỏi về chi tiêu, ngân sách...',
                hintStyle: TextStyle(color: Color(0x88FFFFFF), fontSize: 14),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          const SizedBox(width: 6),
          _buildCircleBtn(
            icon: isSending
                ? Icons.hourglass_top_rounded
                : Icons.send_rounded,
            color: const Color(0xFF9B6DFF),
            onTap: () => _sendMessage(_controller.text),
          ),
        ],
      ),
    );
  }

  Widget _buildCircleBtn({
    required IconData icon,
    Color color = Colors.white24,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}
