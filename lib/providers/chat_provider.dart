import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/message.dart';
import '../services/socket_service.dart';

class ChatProvider extends ChangeNotifier {
  // =======================
  // CONFIG BASE URL
  // =======================
  final String baseUrl = kIsWeb ? 'http://127.0.0.1:3000' : 'http://10.0.2.2:3000';

  // =======================
  // STATE
  // =======================
  final List<Message> _messages = [];
  List<Message> get messages => _messages;

  final SocketService _socketService = SocketService();

  bool _socketConnected = false;
  bool _loading = false;

  bool get isSocketConnected => _socketConnected;
  bool get isLoading => _loading;

  String? _selfUserId;

  // ✅ chống reconnect spam
  String? _connectedUserId;
  String? _connectedGroupId;

  // ✅ tránh add listener nhiều lần
  bool _listening = false;

  // =======================
  // LOAD MESSAGE HISTORY
  // =======================
  Future<void> loadMessages(String groupId, String token) async {
    try {
      _loading = true;
      notifyListeners();

      final res = await http.get(
        Uri.parse('$baseUrl/api/message/$groupId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode != 200) {
        throw Exception('Load messages failed');
      }

      final List data = jsonDecode(res.body);

      _messages
        ..clear()
        ..addAll(data.map((e) => Message.fromJson(e)));

    } catch (e) {
      debugPrint('❌ loadMessages error: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // =======================
  // CONNECT SOCKET
  // =======================
  void connectSocket({
    required String userId,
    required String groupId,
  }) {
    _selfUserId = userId;

    // ✅ nếu đang connect đúng user + group rồi => khỏi connect lại
    if (_socketConnected &&
        _connectedUserId == userId &&
        _connectedGroupId == groupId) {
      return;
    }

    // ✅ nếu khác user/group => disconnect cũ rồi connect mới
    if (_socketConnected) {
      _socketService.disconnect();
      _socketConnected = false;
    }

    _connectedUserId = userId;
    _connectedGroupId = groupId;

    _socketService.connect(
      serverUrl: baseUrl,
      userId: userId, // ✅ socket_service của bạn yêu cầu
      groupId: groupId,
      onConnected: () {
        debugPrint('✅ ChatProvider: socket connected');
        _socketConnected = true;
        notifyListeners();
      },
      onDisconnected: () {
        debugPrint('⚠️ ChatProvider: socket disconnected');
        _socketConnected = false;
        notifyListeners();
      },
    );

    // ✅ chỉ đăng ký listener 1 lần, tránh bị add nhiều lần khi reconnect
    if (!_listening) {
      _listening = true;

      _socketService.onNewMessage((data) {
        try {
          final serverMsg = Message.fromJson(data);

          // ✅ DEDUPE/REPLACE: nếu tin cuối là local mình vừa add, replace nó
          if (_messages.isNotEmpty) {
            final last = _messages.last;

            final lastIsLocal = last.id.toString().startsWith('local-');
            final sameSender = last.senderId == serverMsg.senderId;
            final sameContent = last.content.trim() == serverMsg.content.trim();
            final isMine = (_selfUserId != null && serverMsg.senderId == _selfUserId);

            if (lastIsLocal && sameSender && sameContent && isMine) {
              _messages[_messages.length - 1] = serverMsg;
              notifyListeners();
              return;
            }
          }

          _messages.add(serverMsg);
          notifyListeners();
        } catch (e) {
          debugPrint('❌ Parse message error: $e');
        }
      });
    }
  }

  // =======================
  // SEND MESSAGE (OPTIMISTIC)
  // =======================
  void sendMessage({
    required String groupId,
    required String senderId,
    required String content,
    String senderName = "Bạn",
  }) {
    final text = content.trim();
    if (text.isEmpty) return;

    if (!_socketConnected) {
      debugPrint('❌ ChatProvider: socket chưa connected');
      return;
    }

    // ✅ 1) Optimistic UI: add local message ngay lập tức
    final localMsg = Message(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      groupId: groupId,
      senderId: senderId,
      senderName: senderName,
      senderAvatar: null,
      content: text,
      type: 'text',
      createdAt: DateTime.now(),
    );

    _messages.add(localMsg);
    notifyListeners();

    // ✅ 2) Emit socket
    _socketService.sendMessage(
      groupId: groupId,
      senderId: senderId,
      content: text,
    );
  }

  // ✅ gọi khi logout/đổi user để sạch sẽ
  void forceDisconnect() {
    _socketService.disconnect();
    _socketConnected = false;
    _connectedUserId = null;
    _connectedGroupId = null;
    _selfUserId = null;
    notifyListeners();
  }

  // =======================
  // CLEANUP
  // =======================
  @override
  void dispose() {
    _socketService.disconnect();
    _socketConnected = false;
    super.dispose();
  }
}
