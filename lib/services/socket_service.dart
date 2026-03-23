import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/foundation.dart';

class SocketService {
  static final SocketService instance = SocketService._internal();
  SocketService._internal();
  factory SocketService() => instance;

  IO.Socket? _socket;
  bool get isConnected => _socket?.connected ?? false;

  void connect({
    required String serverUrl,
    required String userId,
    required String groupId,
    required VoidCallback onConnected,
    required VoidCallback onDisconnected,
  }) {
    _socket?.dispose();

    _socket = IO.io(
      serverUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .build(),
    );

    _socket!.onConnect((_) {
      _socket!.emit('joinGroup', {
        'groupId': groupId,
        'userId': userId,
      });
      onConnected();
    });

    _socket!.onDisconnect((_) {
      debugPrint('🔴 Socket disconnected');
      onDisconnected();
    });
  }

  void onNewMessage(Function(Map<String, dynamic>) callback) {
    _socket?.off('newMessage');
    _socket?.on('newMessage', (data) {
      debugPrint('📨 NewMessage socket: $data');
      callback(Map<String, dynamic>.from(data));
    });
  }

  void sendMessage({
    required String groupId,
    required String senderId,
    required String content,
    String type = 'text',
  }) {
    if (_socket == null || !_socket!.connected) {
      debugPrint('❌ Socket not connected. Cannot send message');
      return;
    }

    _socket!.emit('sendMessage', {
      'groupId': groupId,
      'senderId': senderId,
      'content': content,
      'type': type,
    });
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }
}
