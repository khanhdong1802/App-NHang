class GroupTransaction {
  final String id;
  final String transactionType; // expense, groupExpense, contribution, income, withdraw...
  final num amount;
  final String status; // completed, approved, pending...
  final String description;
  final DateTime? transactionDate;
  final DateTime? createdAt;
  final String? userName;

  GroupTransaction({
    required this.id,
    required this.transactionType,
    required this.amount,
    required this.status,
    required this.description,
    required this.transactionDate,
    required this.createdAt,
    required this.userName,
  });

  factory GroupTransaction.fromJson(Map<String, dynamic> j) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      try {
        return DateTime.parse(v.toString());
      } catch (_) {
        return null;
      }
    }

    final user = j["user_id"];
    String? name;
    if (user is Map && user["name"] != null) name = user["name"].toString();

    return GroupTransaction(
      id: (j["_id"] ?? "").toString(),
      transactionType: (j["transaction_type"] ?? j["type"] ?? "groupExpense").toString(),
      amount: (j["amount"] is num) ? j["amount"] : num.tryParse((j["amount"] ?? "0").toString()) ?? 0,
      status: (j["status"] ?? "").toString(),
      description: (j["description"] ?? "").toString(),
      transactionDate: parseDate(j["transaction_date"]),
      createdAt: parseDate(j["createdAt"]),
      userName: name,
    );
  }
}
