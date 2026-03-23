import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:doanmonhoc/providers/chat_provider.dart';
import 'package:doanmonhoc/services/auth_service.dart';

class GroupChatScreen extends StatefulWidget {
  final String groupId;

  const GroupChatScreen({super.key, required this.groupId});

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  String? _token;
  String? _userId;
  bool _booting = true;

  Future<void> _scrollToBottom() async {
    if (!_scrollCtrl.hasClients) return;
    await Future.delayed(const Duration(milliseconds: 10));
    if (!_scrollCtrl.hasClients) return;
    _scrollCtrl.animateTo(
      _scrollCtrl.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final chat = context.read<ChatProvider>();
      final auth = context.read<AuthService>();

      // ✅ lấy token + userId từ RAM (nếu AuthService đã set) hoặc fallback từ storage
      final token = auth.token ?? await auth.getToken();
      final userMap = auth.currentUser ?? await auth.getUserFromStorage();

      final userId = auth.currentUserId ??
          (userMap?["_id"] ?? userMap?["id"])?.toString();

      if (token == null || token.isEmpty) {
        debugPrint("❌ Missing token (AuthService)");
        if (mounted) setState(() => _booting = false);
        return;
      }
      if (userId == null || userId.isEmpty) {
        debugPrint("❌ Missing userId (AuthService)");
        if (mounted) setState(() => _booting = false);
        return;
      }

      if (!mounted) return;
      setState(() {
        _token = token;
        _userId = userId;
        _booting = false;
      });

      // ✅ connect socket + load history
      chat.connectSocket(userId: userId, groupId: widget.groupId);
      await chat.loadMessages(widget.groupId, token);

      await _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final currentUserId = _userId;

    // Auto scroll khi có tin nhắn mới
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (chat.messages.isNotEmpty) _scrollToBottom();
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text("Group Chat"),
      ),
      body: Column(
        children: [
          Expanded(
            child: _booting
                ? const Center(child: CircularProgressIndicator())
                : (currentUserId == null || _token == null)
                ? const Center(
              child: Text(
                "Thiếu thông tin đăng nhập (token/user). Vui lòng đăng nhập lại.",
              ),
            )
                : ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(12),
              itemCount: chat.messages.length,
              itemBuilder: (context, index) {
                final msg = chat.messages[index];
                final isMe = msg.senderId == currentUserId;
                final displayName =
                isMe ? "Bạn" : (msg.senderName ?? "Thành viên");

                return Align(
                  alignment: isMe
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: isMe
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      if (!isMe)
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 6,
                            right: 6,
                            bottom: 2,
                          ),
                          child: Text(
                            displayName,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      Container(
                        margin:
                        const EdgeInsets.symmetric(vertical: 2),
                        padding: const EdgeInsets.all(10),
                        constraints:
                        const BoxConstraints(maxWidth: 280),
                        decoration: BoxDecoration(
                          color:
                          isMe ? Colors.blue : Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          msg.content,
                          style: TextStyle(
                            color:
                            isMe ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: "Nhập tin nhắn...",
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onSubmitted: (_) => _handleSend(context),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed:
                  (currentUserId == null) ? null : () => _handleSend(context),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Future<void> _handleSend(BuildContext context) async {
    final chat = context.read<ChatProvider>();
    final auth = context.read<AuthService>();

    final content = _controller.text.trim();
    if (content.isEmpty) return;

    // Ưu tiên _userId, fallback đọc AuthService (phòng trường hợp state chưa set kịp)
    final senderId = _userId ??
        auth.currentUserId ??
        ((await auth.getUserFromStorage())?["_id"]?.toString());

    if (senderId == null || senderId.isEmpty) {
      debugPrint("❌ Missing senderId");
      return;
    }

    chat.sendMessage(
      groupId: widget.groupId,
      senderId: senderId,
      content: content,
      senderName: "Bạn",
    );

    _controller.clear();
    await _scrollToBottom();
  }
}
