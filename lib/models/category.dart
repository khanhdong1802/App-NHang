class Category {
  final String id;
  final String name;
  final String? icon;
  final num? limit;

  Category({
    required this.id,
    required this.name,
    this.icon,
    this.limit,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    num? parseLimit(dynamic value) {
      if (value is num) return value;
      if (value is String) return num.tryParse(value);
      return null;
    }

    return Category(
      id: (json['_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      icon: json['icon']?.toString(),
      limit: parseLimit(json['limit']),
    );
  }
}
