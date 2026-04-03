import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/chatbot_service.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime time;

  ChatMessage({
    required this.text,
    required this.isUser,
    DateTime? time,
  }) : time = time ?? DateTime.now();
}

class ChatbotProvider extends ChangeNotifier {
  final List<ChatMessage> _messages = [];
  final List<Map<String, dynamic>> _history = [];
  bool _isLoading = false;

  List<ChatMessage> get messages => _messages;
  bool get isLoading => _isLoading;

  Future<void> sendMessage(String text, {String? token}) async {
    _messages.add(ChatMessage(text: text, isUser: true));
    _isLoading = true;
    notifyListeners();

    try {
      final reply = await ChatbotService.sendMessage(
        message: text,
        history: _history,
        token: token,
      );

      _history.add({'role': 'user', 'content': text});
      _history.add({'role': 'assistant', 'content': reply});

      _messages.add(ChatMessage(text: reply, isUser: false));
    } catch (e) {
      _messages.add(ChatMessage(
        text: 'Lỗi: Không thể kết nối chatbot.',
        isUser: false,
      ));
    }

    _isLoading = false;
    notifyListeners();
  }

  Map<String, dynamic>? _lastScanResult;
  Map<String, dynamic>? get lastScanResult => _lastScanResult;

  Future<Map<String, dynamic>?> scanReceipt({
    required Uint8List imageBytes,
    required String fileName,
    String? token,
  }) async {
    _messages.add(ChatMessage(text: 'Đang quét hóa đơn...', isUser: true));
    _isLoading = true;
    notifyListeners();

    try {
      final result = await ChatbotService.scanReceipt(
        imageBytes: imageBytes,
        fileName: fileName,
        token: token,
      );

      _lastScanResult = result;

      final amount = result['amount'] ?? 0;
      final desc = result['description'] ?? '';
      final items = (result['items'] as List?)?.join(', ') ?? '';
      final catName = result['category_name'] ?? '';

      String reply = '📋 Kết quả quét hóa đơn:\n'
          '💰 Tổng tiền: ${_formatMoney(amount)} đ\n'
          '📝 Mô tả: $desc';
      if (catName.isNotEmpty) {
        reply += '\n📁 Danh mục: $catName';
      }
      if (items.isNotEmpty) {
        reply += '\n🛒 Các mục: $items';
      }

      _messages.add(ChatMessage(text: reply, isUser: false));
      _isLoading = false;
      notifyListeners();

      return result;
    } catch (e) {
      _messages.add(ChatMessage(
        text: 'Lỗi: Không thể quét hóa đơn. Vui lòng thử lại.',
        isUser: false,
      ));
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  String _formatMoney(dynamic amount) {
    final n = (amount is int) ? amount : int.tryParse(amount.toString()) ?? 0;
    return n.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (m) => ',',
    );
  }

  void addBotMessage(String text) {
    _messages.add(ChatMessage(text: text, isUser: false));
    notifyListeners();
  }

  void clearChat() {
    _messages.clear();
    _history.clear();
    notifyListeners();
  }
}