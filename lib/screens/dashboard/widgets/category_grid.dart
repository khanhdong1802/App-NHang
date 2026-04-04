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

          return _CategoryPressCard(
            cat: cat,
            style: style,
            isSelected: isSelected,
            onTap: () => onTap(cat),
          );
        },
      ),
    );
  }
}

class _CategoryPressCard extends StatefulWidget {
  final Category cat;
  final _CatStyle style;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryPressCard({
    required this.cat,
    required this.style,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_CategoryPressCard> createState() => _CategoryPressCardState();
}

class _CategoryPressCardState extends State<_CategoryPressCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.style.color;

    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        transform: Matrix4.identity()
          ..translate(0.0, _pressed ? 2.0 : 0.0)
          ..scale(_pressed ? 0.965 : 1.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: widget.isSelected
              ? color.withOpacity(0.12)
              : Colors.white,
          border: Border.all(
            color: widget.isSelected ? color : const Color(0xFFE5E7EB),
            width: widget.isSelected ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: widget.isSelected
                  ? color.withOpacity(0.18)
                  : Colors.black.withOpacity(0.06),
              blurRadius: _pressed ? 8 : 16,
              offset: Offset(0, _pressed ? 4 : 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                curve: Curves.easeOut,
                width: _pressed ? 42 : 46,
                height: _pressed ? 42 : 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color,
                      color.withOpacity(0.78),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(_pressed ? 0.18 : 0.28),
                      blurRadius: _pressed ? 8 : 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(
                  widget.style.icon,
                  color: Colors.white,
                  size: _pressed ? 20 : 22,
                ),
              ),
              const SizedBox(height: 10),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOut,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: widget.isSelected
                      ? color
                      : const Color(0xFF111827),
                ),
                child: Text(
                  widget.cat.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CatStyle {
  final IconData icon;
  final Color color;
  _CatStyle(this.icon, this.color);
}

_CatStyle _catStyle(String name) {
  switch (name) {
    case "Học phí":
      return _CatStyle(Icons.school_rounded, const Color(0xFF8B5CF6));
    case "Thức ăn":
      return _CatStyle(Icons.restaurant_rounded, const Color(0xFFEF476F));
    case "Khác":
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