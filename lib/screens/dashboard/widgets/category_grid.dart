// TODO Implement this library.
import 'package:flutter/material.dart';
import '../../../../models/category.dart';

class CategoryGrid extends StatelessWidget {
  final List<Category> categories;
  final Category? selected;
  final void Function(Category cat) onTap;

  const CategoryGrid({
    super.key,
    required this.categories,
    required this.onTap,
    this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: categories.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 0.92,
        ),
        itemBuilder: (_, i) {
          final cat = categories[i];
          final style = _catStyle(cat.name);
          final isSelected = selected?.id == cat.id;

          return Material(
            color: isSelected ? style.color.withOpacity(0.12) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => onTap(cat),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isSelected ? style.color : Colors.transparent,
                    width: 1.4,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x11000000),
                      blurRadius: 14,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: style.color,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(style.icon, color: Colors.white),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      cat.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}


class _CatStyle {
  final IconData icon;
  final Color color;
  _CatStyle(this.icon, this.color);
}

// map y chang DashboardPage.jsx iconMap/gradientMap :contentReference[oaicite:18]{index=18}
_CatStyle _catStyle(String name) {
  switch (name) {
    case "Học phí":
      return _CatStyle(Icons.school_rounded, const Color(0xFF8B5CF6));
    case "Thức ăn":
      return _CatStyle(Icons.restaurant_rounded, const Color(0xFFEF476F));
    case "Tiền ngu":
      return _CatStyle(Icons.bed_rounded, const Color(0xFF3B82F6));
    case "Tiền nhà":
      return _CatStyle(Icons.home_rounded, const Color(0xFFFF8A00));
    case "Đi lại":
      return _CatStyle(Icons.directions_car_rounded, const Color(0xFF06B6D4));
    case "Đồ dùng":
      return _CatStyle(Icons.calculate_rounded, const Color(0xFF6366F1));
    default:
      return _CatStyle(Icons.calculate_rounded, const Color(0xFF94A3B8));
  }
}
