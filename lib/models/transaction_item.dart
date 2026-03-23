class TransactionItem {
  final String id;
  final String transactionType; // income / expense / withdraw / contribution / groupExpense...
  final num amount;

  final String? description;
  final DateTime? transactionDate;
  final String? status;

  final String? categoryId;
  final String? categoryName;
  final String? groupId;
  final String? groupName;

  final String? userId;
  final String? userName;

  TransactionItem({
    required this.id,
    required this.transactionType,
    required this.amount,
    this.description,
    this.transactionDate,
    this.status,
    this.categoryId,
    this.categoryName,
    this.groupId,
    this.groupName,
    this.userId,
    this.userName,
  });

  static num _parseNum(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    return num.tryParse(v.toString()) ?? 0;
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }

  static String? _parseId(dynamic v) {
    if (v == null) return null;
    if (v is Map) {
      return (v["_id"] ?? v["id"])?.toString();
    }
    return v.toString();
  }

  static String? _parseName(dynamic v) {
    if (v == null) return null;
    if (v is Map) {
      return (v["name"] ?? v["fullName"] ?? v["title"])?.toString();
    }
    return null;
  }

  factory TransactionItem.fromJson(Map<String, dynamic> json) {
    String? uid;
    String? uname;
    final u = json["user_id"];
    if (u is Map) {
      uid = (u["_id"] ?? u["id"] ?? u["userId"])?.toString();
      uname = (u["name"] ?? u["fullName"] ?? u["username"])?.toString();
    } else if (u != null) {
      uid = u.toString();
    }

    final catRaw = json["category_id"];
    final catId = _parseId(catRaw);
    final catName =
        json["category_name"]?.toString() ??
            _parseName(catRaw);

    final groupRaw = json["group_id"];
    final gid = _parseId(groupRaw);
    final gname =
        json["group_name"]?.toString() ??
            _parseName(groupRaw);

    final rawDate =
        json["transaction_date"] ??
            json["transactionDate"] ??
            json["createdAt"];

    final date = _parseDate(rawDate);

    return TransactionItem(
      id: (json["_id"] ?? json["id"] ?? "").toString(),
      transactionType:
      (json["transaction_type"] ?? json["transactionType"] ?? "")
          .toString(),
      amount: _parseNum(json["amount"]),
      description: json["description"]?.toString(),
      transactionDate: date,
      status: json["status"]?.toString(),
      categoryId: catId,
      categoryName: catName,
      groupId: gid,
      groupName: gname,
      userId: uid,
      userName: uname,
    );
  }
}