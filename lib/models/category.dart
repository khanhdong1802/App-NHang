class Category {
  final String id;
  final String name;
  final String? description;
  final String? icon;
  final String? color;
  final num? limit;

  Category({
    required this.id,
    required this.name,
    this.description,
    this.icon,
    this.color,
    this.limit,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    num? parseLimit(dynamic value) {
      if (value is num) return value;
      if (value is String) return num.tryParse(value);
      return null;
    }

    return Category(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      description: json['description']?.toString(),
      icon: json['icon']?.toString(),
      color: json['color']?.toString(),
      limit: parseLimit(json['limit']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "name": name,
      "description": description,
      "icon": icon,
      "color": color,
      "limit": limit,
    };
  }
}