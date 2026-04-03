import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/chatbot_provider.dart';
import '../../services/auth_service.dart';
import 'modals/record_modal.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final token = context.read<AuthService>().token;
    context.read<ChatbotProvider>().sendMessage(text, token: token);
    _controller.clear();
    _scrollToBottom();
  }

  Future<void> _pickAndScan({required ImageSource source}) async {
    final XFile? image = await _picker.pickImage(
      source: source,
      imageQuality: 85,
    );
    if (image == null) return;

    final bytes = await image.readAsBytes();
    final fileName = image.name;

    final token = context.read<AuthService>().token;
    final result = await context.read<ChatbotProvider>().scanReceipt(
      imageBytes: bytes,
      fileName: fileName,
      token: token,
    );

    _scrollToBottom();

    if (result != null && result['amount'] != null && result['amount'] > 0) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;

      final saved = await RecordModal.open(
        context,
        prefilledAmount: result['amount'],
        prefilledNote: result['description'] ?? '',
        selectedCategoryId: result['category_id'] ?? '',
      );

      // Nếu user lưu thành công
      if (saved == true && mounted) {
        context.read<ChatbotProvider>().addBotMessage(
          '✅ Đã ghi nhận chi tiêu của hóa đơn này!',
        );
        _scrollToBottom();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trợ lý tài chính'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => context.read<ChatbotProvider>().clearChat(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Consumer<ChatbotProvider>(
              builder: (context, provider, child) {
                if (provider.messages.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.smart_toy_outlined,
                            size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Xin chào! Hãy hỏi tôi về tài chính.',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount:
                  provider.messages.length + (provider.isLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == provider.messages.length) {
                      return const Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                CircularProgressIndicator(strokeWidth: 2),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Đang trả lời...',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final msg = provider.messages[index];
                    return _buildMessageBubble(msg);
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  PopupMenuButton<ImageSource>(
                    icon: Icon(Icons.camera_alt,
                        color: Theme.of(context).primaryColor),
                    onSelected: (source) => _pickAndScan(source: source),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: ImageSource.camera,
                        child: Row(
                          children: [
                            Icon(Icons.camera_alt),
                            SizedBox(width: 8),
                            Text('Chụp ảnh'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: ImageSource.gallery,
                        child: Row(
                          children: [
                            Icon(Icons.photo_library),
                            SizedBox(width: 8),
                            Text('Chọn từ thư viện'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: 'Nhập tin nhắn...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[200],
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                      textInputAction: TextInputAction.send,
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: Theme.of(context).primaryColor,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color:
          msg.isUser ? Theme.of(context).primaryColor : Colors.grey[200],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(msg.isUser ? 16 : 4),
            bottomRight: Radius.circular(msg.isUser ? 4 : 16),
          ),
        ),
        child: Text(
          msg.text,
          style: TextStyle(
            color: msg.isUser ? Colors.white : Colors.black87,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}