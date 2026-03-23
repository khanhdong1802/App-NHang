import 'package:flutter/material.dart';
import '../../../../models/transaction_item.dart';

class TxRecentList extends StatelessWidget {
  final List<TransactionItem> txs;
  final VoidCallback onViewAll;

  const TxRecentList({
    super.key,
    required this.txs,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    if (txs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 18),
        child: Center(
          child: Column(
            children: [
              Text(
                "Bạn chưa có ghi chép nào!",
                style: TextStyle(color: Colors.grey),
              ),
              SizedBox(height: 6),
              Text(
                "Hãy chạm vào đây và kéo xuống để hiển thị dữ liệu mới nhất!",
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final shown = txs.take(5).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          const Text(
            "Giao dịch gần đây",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),

          ...shown.map((tx) => _TxTile(tx: tx)),

          if (txs.length > 5)
            Center(
              child: TextButton(
                onPressed: onViewAll,
                child: const Text(
                  "Xem thêm",
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TxTile extends StatelessWidget {
  final TransactionItem tx;

  const _TxTile({required this.tx});

  String _money(num v) {
    final s = v.toStringAsFixed(0);
    final chars = s.split('');
    final buf = StringBuffer();

    for (int i = 0; i < chars.length; i++) {
      final idxFromEnd = chars.length - i;
      buf.write(chars[i]);
      if (idxFromEnd > 1 && idxFromEnd % 3 == 1) {
        buf.write(',');
      }
    }

    return "${buf}đ";
  }

  @override
  Widget build(BuildContext context) {
    final isIncome = tx.transactionType == "income";
    final isExpense = tx.transactionType == "expense";
    final isContribution = tx.transactionType == "contribution";

    final sign = isIncome
        ? "+"
        : (isExpense || isContribution)
        ? "-"
        : (tx.amount >= 0 ? "+" : "-");

    final amountColor =
    (sign == "+") ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
    final iconBg =
    (sign == "+") ? const Color(0xFF10B981) : const Color(0xFFEF476F);

    final dateText = tx.transactionDate != null
        ? "${tx.transactionDate!.day.toString().padLeft(2, '0')}/"
        "${tx.transactionDate!.month.toString().padLeft(2, '0')}/"
        "${tx.transactionDate!.year}"
        : "";

    final title =
    (tx.description != null && tx.description!.trim().isNotEmpty)
        ? tx.description!.trim()
        : tx.transactionType;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                sign,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Text(
                      "$sign ${_money(tx.amount)}",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: amountColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    [
                      if (dateText.isNotEmpty) "Ngày: $dateText",
                      if (tx.status != null && tx.status!.isNotEmpty)
                        "Trạng thái: ${tx.status}",
                    ].join(" | "),
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}