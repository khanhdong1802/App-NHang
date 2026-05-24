import 'package:flutter/foundation.dart';

// ══════════════════════════════════════════════════════════════
//  ChatMessage — model dùng chung, định nghĩa ở đây để cả
//  Provider lẫn Screen đều import từ một nơi.
// ══════════════════════════════════════════════════════════════
class ChatMessage {
  final String content;
  final bool isUser;
  final DateTime time;
  final bool isLoading;

  /// Loại action hiển thị bên dưới tin nhắn (null = không có).
  /// Hiện tại hỗ trợ: 'record_expense'
  final String? actionType;

  /// Dữ liệu kèm theo action (amount, description, category_id).
  final Map<String, dynamic>? actionData;

  ChatMessage({
    required this.content,
    required this.isUser,
    DateTime? time,
    this.isLoading = false,
    this.actionType,
    this.actionData,
  }) : time = time ?? DateTime.now();
}

// ══════════════════════════════════════════════════════════════
//  ChatbotProvider — giữ state chatbot xuyên suốt vòng đời app.
//  Khi user rời ChatbotScreen và quay lại, tin nhắn vẫn còn.
//  Chỉ mất khi app bị kill hoặc gọi clearChat().
// ══════════════════════════════════════════════════════════════
class ChatbotProvider extends ChangeNotifier {
  final List<ChatMessage> _messages = [];
  bool _isSending = false;

  // ── Getters ───────────────────────────────────────────────
  List<ChatMessage> get messages => _messages; // direct ref, dùng để indexOf hoạt động đúng
  bool get isSending => _isSending;

  // ── Khởi tạo ──────────────────────────────────────────────
  /// Thêm tin chào mừng nếu cuộc trò chuyện còn trống.
  /// Gọi trong initState của ChatbotScreen.
  void initWelcomeIfEmpty() {
    if (_messages.isNotEmpty) return;
    _messages.add(ChatMessage(
      content: 'Xin chào! Tôi là trợ lý tài chính AI của bạn 👋\n\n'
          'Tôi chỉ hỗ trợ các chủ đề về tài chính:\n'
          '• Chi tiêu & quản lý ngân sách cá nhân\n'
          '• Tiết kiệm & lập kế hoạch tài chính\n'
          '• Phân tích hoá đơn tự động\n'
          '• Hạn mức chi tiêu theo danh mục\n\n'
          'Bạn muốn hỏi gì về tài chính hôm nay?',
      isUser: false,
    ));
    notifyListeners();
  }

  // ── Mutations ─────────────────────────────────────────────

  void setSending(bool value) {
    if (_isSending == value) return;
    _isSending = value;
    notifyListeners();
  }

  /// Thêm một tin nhắn vào cuối danh sách.
  void addMessage(ChatMessage msg) {
    _messages.add(msg);
    notifyListeners();
  }

  /// Thêm nhiều tin nhắn cùng lúc (chỉ notify một lần).
  void addMessages(List<ChatMessage> msgs) {
    _messages.addAll(msgs);
    notifyListeners();
  }

  /// Xoá tin nhắn cuối (thường là loading bubble).
  void removeLast() {
    if (_messages.isEmpty) return;
    _messages.removeLast();
    notifyListeners();
  }

  /// Xoá tin nhắn cuối rồi thêm tin mới — dùng để thay loading bubble.
  void replaceLastWith(ChatMessage msg) {
    if (_messages.isNotEmpty) _messages.removeLast();
    _messages.add(msg);
    notifyListeners();
  }

  /// Xoá loading bubble rồi thêm nhiều tin — dùng sau scan receipt.
  void replaceLastWithMany(List<ChatMessage> msgs) {
    if (_messages.isNotEmpty) _messages.removeLast();
    _messages.addAll(msgs);
    notifyListeners();
  }

  /// Thay thế một tin nhắn cụ thể (dùng cho action buttons).
  /// So sánh bằng object identity (không cần override ==).
  void replaceMessage(ChatMessage oldMsg, ChatMessage newMsg) {
    final idx = _messages.indexOf(oldMsg);
    if (idx >= 0) {
      _messages[idx] = newMsg;
      notifyListeners();
    }
  }

  /// Xoá toàn bộ lịch sử chat.
  void clearChat() {
    _messages.clear();
    _isSending = false;
    notifyListeners();
  }
}
