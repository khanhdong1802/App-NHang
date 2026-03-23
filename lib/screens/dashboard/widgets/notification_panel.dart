import 'package:flutter/material.dart';

class NotificationPanel extends StatelessWidget {
  final List<Map<String, dynamic>> notifications;
  final Future<void> Function(String notiId) onAccept;
  final Future<void> Function(String notiId) onReject;

  const NotificationPanel({
    super.key,
    required this.notifications,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: notifications.isEmpty
          ? const Padding(
        padding: EdgeInsets.all(12),
        child: Center(child: Text("Hiện chưa có thông báo nào.")),
      )
          : Column(
        children: notifications.map((n) {
          final id = (n["_id"] ?? "").toString();
          final groupName = (n["groupName"] ?? "").toString();
          final pending = (n["status"]?.toString() == "pending");

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bạn được mời vào nhóm "$groupName"', style: const TextStyle(fontWeight: FontWeight.w700)),
                if (pending) ...[
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => onReject(id),
                        child: const Text("Từ chối"),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => onAccept(id),
                        child: const Text("Chấp nhận"),
                      ),
                    ],
                  )
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
