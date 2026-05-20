import 'package:flutter/material.dart';

import '../models/category.dart';

class CategoryUiStyle {
  final IconData icon;
  final Color color;

  const CategoryUiStyle({
    required this.icon,
    required this.color,
  });
}

CategoryUiStyle getCategoryStyle(Category cat) {
  final fallback = _styleByName(cat.name);

  final savedIcon = _iconFromKey(cat.icon);
  final savedColor = _parseHexColor(cat.color);

  return CategoryUiStyle(
    icon: savedIcon ?? fallback.icon,
    color: savedColor ?? fallback.color,
  );
}

CategoryUiStyle _styleByName(String name) {
  switch (name) {
    case "Học phí":
      return const CategoryUiStyle(
        icon: Icons.school_rounded,
        color: Color(0xFF8B5CF6),
      );

    case "Thức ăn":
      return const CategoryUiStyle(
        icon: Icons.restaurant_rounded,
        color: Color(0xFFEF476F),
      );

    case "Khác":
      return const CategoryUiStyle(
        icon: Icons.bed_rounded,
        color: Color(0xFF3B82F6),
      );

    case "Tiền nhà":
      return const CategoryUiStyle(
        icon: Icons.home_rounded,
        color: Color(0xFFFF8A00),
      );

    case "Đi lại":
      return const CategoryUiStyle(
        icon: Icons.directions_car_rounded,
        color: Color(0xFF06B6D4),
      );

    case "Đồ dùng":
      return const CategoryUiStyle(
        icon: Icons.calculate_rounded,
        color: Color(0xFF6366F1),
      );

    default:
      return const CategoryUiStyle(
        icon: Icons.category_rounded,
        color: Color(0xFF94A3B8),
      );
  }
}

IconData? _iconFromKey(String? key) {
  if (key == null || key.isEmpty) return null;

  const icons = {
    "restaurant": Icons.restaurant,
    "fastfood": Icons.fastfood,
    "local_cafe": Icons.local_cafe,
    "cake": Icons.cake,
    "local_bar": Icons.local_bar,
    "icecream": Icons.icecream,
    "local_pizza": Icons.local_pizza,
    "rice_bowl": Icons.rice_bowl,
    "lunch_dining": Icons.lunch_dining,
    "egg": Icons.egg,

    "shopping_bag": Icons.shopping_bag,
    "shopping_cart": Icons.shopping_cart,
    "store": Icons.store,
    "local_mall": Icons.local_mall,
    "checkroom": Icons.checkroom,
    "watch": Icons.watch,
    "diamond": Icons.diamond,
    "sell": Icons.sell,
    "redeem": Icons.redeem,
    "card_giftcard": Icons.card_giftcard,

    "home": Icons.home,
    "chair": Icons.chair,
    "bed": Icons.bed,
    "tv": Icons.tv,
    "camera_alt": Icons.camera_alt,
    "pets": Icons.pets,
    "build": Icons.build,
    "lightbulb": Icons.lightbulb,
    "cleaning_services": Icons.cleaning_services,
    "weekend": Icons.weekend,

    "person": Icons.person,
    "face": Icons.face,
    "favorite": Icons.favorite,
    "spa": Icons.spa,
    "music_note": Icons.music_note,
    "psychology": Icons.psychology,
    "self_improvement": Icons.self_improvement,
    "emoji_emotions": Icons.emoji_emotions,
    "accessibility_new": Icons.accessibility_new,
    "local_florist": Icons.local_florist,

    "school": Icons.school,
    "menu_book": Icons.menu_book,
    "edit": Icons.edit,
    "calculate": Icons.calculate,
    "science": Icons.science,
    "laptop": Icons.laptop,
    "language": Icons.language,
    "library_books": Icons.library_books,
    "history_edu": Icons.history_edu,
    "class": Icons.class_,

    "sports_soccer": Icons.sports_soccer,
    "fitness_center": Icons.fitness_center,
    "sports_basketball": Icons.sports_basketball,
    "sports_tennis": Icons.sports_tennis,
    "pool": Icons.pool,
    "directions_bike": Icons.directions_bike,
    "sports_handball": Icons.sports_handball,
    "sports_martial_arts": Icons.sports_martial_arts,
    "sports_gymnastics": Icons.sports_gymnastics,
    "sports": Icons.sports,

    "directions_car": Icons.directions_car,
    "directions_bus": Icons.directions_bus,
    "train": Icons.train,
    "flight": Icons.flight,
    "two_wheeler": Icons.two_wheeler,
    "local_taxi": Icons.local_taxi,
    "local_gas_station": Icons.local_gas_station,
    "local_parking": Icons.local_parking,
    "sailing": Icons.sailing,
    "local_shipping": Icons.local_shipping,

    "medical_services": Icons.medical_services,
    "local_hospital": Icons.local_hospital,
    "healing": Icons.healing,
    "monitor_heart": Icons.monitor_heart,
    "medication": Icons.medication,
    "accessible": Icons.accessible,
    "health_and_safety": Icons.health_and_safety,
    "favorite_border": Icons.favorite_border,
    "emergency": Icons.emergency,
    "bloodtype": Icons.bloodtype,

    "luggage": Icons.luggage,
    "beach_access": Icons.beach_access,
    "map": Icons.map,
    "hotel": Icons.hotel,
    "location_on": Icons.location_on,
    "landscape": Icons.landscape,
    "tour": Icons.tour,
    "photo_camera": Icons.photo_camera,
    "explore": Icons.explore,
    "terrain": Icons.terrain,

    "attach_money": Icons.attach_money,
    "payments": Icons.payments,
    "account_balance": Icons.account_balance,
    "credit_card": Icons.credit_card,
    "wallet": Icons.wallet,
    "savings": Icons.savings,
    "trending_up": Icons.trending_up,
    "receipt_long": Icons.receipt_long,
    "request_quote": Icons.request_quote,
    "currency_bitcoin": Icons.currency_bitcoin,

    "more_horiz": Icons.more_horiz,
    "category": Icons.category,
    "extension": Icons.extension,
    "mail": Icons.mail,
    "phone": Icons.phone,
    "work": Icons.work,
    "print": Icons.print,
    "settings": Icons.settings,
    "star": Icons.star,
    "help": Icons.help,
  };

  return icons[key];
}

Color? _parseHexColor(String? hex) {
  if (hex == null || hex.isEmpty) return null;

  var value = hex.replaceAll("#", "").trim();

  if (value.length == 6) {
    value = "FF$value";
  }

  final intValue = int.tryParse(value, radix: 16);

  if (intValue == null) return null;

  return Color(intValue);
}