class Message {
  final String id;
  final String groupId;
  final String senderId;
  final String senderName;
  final String? senderAvatar;
  final String content;
  final String type;
  final DateTime createdAt;

  Message({
    required this.id,
    required this.groupId,
    required this.senderId,
    required this.senderName,
    this.senderAvatar,
    required this.content,
    required this.type,
    required this.createdAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    final sender = json['senderId'];

    String senderId;
    String senderName;
    String? senderAvatar;

    if (sender is Map) {
      senderId = sender['_id']?.toString() ?? '';
      senderName = sender['name'] ?? 'Unknown';
      senderAvatar = sender['avatar'];
    } else {
      senderId = sender?.toString() ?? '';
      senderName = 'You';
      senderAvatar = null;
    }

    return Message(
      id: json['_id'].toString(),
      groupId: json['groupId'].toString(),
      senderId: senderId,
      senderName: senderName,
      senderAvatar: senderAvatar,
      content: json['content'] ?? '',
      type: json['type'] ?? 'text',
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}
