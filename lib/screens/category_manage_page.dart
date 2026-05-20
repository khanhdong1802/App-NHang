import 'package:flutter/material.dart';

import '../../models/category.dart';
import '../../services/category_api.dart';
import '../../utils/category_style_helper.dart';

class AppThemeColor {
  static const primaryPurple = Color(0xFF7C3AED);
  static const primaryIndigo = Color(0xFF6366F1);

  static const background = Color(0xFFF8F7FF);
  static const card = Color(0xFFFFFFFF);

  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);
  static const textMuted = Color(0xFF9CA3AF);

  static const border = Color(0xFFE5E7EB);
  static const softPurple = Color(0xFFEDE9FE);
  static const softIndigo = Color(0xFFE0E7FF);

  static const danger = Color(0xFFEF4444);
}

class CategoryManagePage extends StatefulWidget {
  const CategoryManagePage({super.key});

  @override
  State<CategoryManagePage> createState() => _CategoryManagePageState();
}

class _CategoryManagePageState extends State<CategoryManagePage> {
  final CategoryApi api = CategoryApi();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController searchController = TextEditingController();

  bool loading = true;
  bool saving = false;
  bool changed = false;

  List<Category> categories = [];
  Category? editingCategory;

  String selectedIconKey = "restaurant";
  Color selectedColor = AppThemeColor.primaryPurple;
  int selectedIconGroupIndex = 0;

  IconData get selectedIcon => _findIcon(selectedIconKey).icon;

  List<Category> get filteredCategories {
    final keyword = searchController.text.trim().toLowerCase();

    if (keyword.isEmpty) {
      return categories;
    }

    return categories.where((cat) {
      return cat.name.toLowerCase().contains(keyword);
    }).toList();
  }

  @override
  void initState() {
    super.initState();

    searchController.addListener(() {
      if (mounted) setState(() {});
    });

    _loadCategories();
  }

  @override
  void dispose() {
    nameController.dispose();
    searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() => loading = true);

    try {
      final data = await api.fetchCategories();

      if (!mounted) return;

      setState(() {
        categories = data;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Lỗi tải danh mục: $e")),
      );
    }
  }

  void _clearForm() {
    editingCategory = null;
    nameController.clear();
    selectedIconKey = "restaurant";
    selectedColor = AppThemeColor.primaryPurple;
    selectedIconGroupIndex = 0;
    setState(() {});
  }

  void _fillForm(Category cat) {
    editingCategory = cat;

    nameController.text = cat.name;
    selectedIconKey = _findIcon(cat.icon).key;
    selectedColor = _parseHexColor(cat.color) ?? AppThemeColor.primaryPurple;
    selectedIconGroupIndex = _findGroupIndexByIconKey(selectedIconKey);

    setState(() {});
  }

  Future<void> _saveCategory() async {
    final name = nameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vui lòng nhập tên danh mục")),
      );
      return;
    }

    final category = Category(
      id: editingCategory?.id ?? "",
      name: name,
      description: editingCategory?.description,
      icon: selectedIconKey,
      color: _colorToHex(selectedColor),
      limit: editingCategory?.limit,
    );

    setState(() => saving = true);

    try {
      if (editingCategory == null) {
        await api.createCategory(category);
      } else {
        await api.updateCategory(category);
      }

      changed = true;

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            editingCategory == null
                ? "Đã thêm danh mục"
                : "Đã cập nhật danh mục",
          ),
        ),
      );

      _clearForm();
      await _loadCategories();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Lỗi lưu danh mục: $e")),
      );
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  Future<void> _deleteCategory(Category cat) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            "Xóa danh mục",
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: AppThemeColor.textPrimary,
            ),
          ),
          content: Text(
            "Bạn có chắc muốn xóa danh mục \"${cat.name}\" không?",
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppThemeColor.textSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                "Hủy",
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppThemeColor.textSecondary,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppThemeColor.danger,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                "Xóa",
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await api.deleteCategory(cat.id);

      changed = true;

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Đã xóa danh mục")),
      );

      if (editingCategory?.id == cat.id) {
        _clearForm();
      }

      await _loadCategories();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Lỗi xóa danh mục: $e")),
      );
    }
  }

  Future<bool> _handleBack() async {
    Navigator.pop(context, changed);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _handleBack,
      child: Scaffold(
        backgroundColor: AppThemeColor.background,
        body: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: loading
                  ? const Center(
                child: CircularProgressIndicator(
                  color: AppThemeColor.primaryPurple,
                ),
              )
                  : RefreshIndicator(
                color: AppThemeColor.primaryPurple,
                onRefresh: _loadCategories,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
                  children: [
                    _buildEditorCard(),
                    const SizedBox(height: 16),
                    _buildSectionCard(
                      title: "Màu sắc",
                      subtitle: "Chọn màu đại diện cho danh mục",
                      child: _buildColorPicker(),
                    ),
                    const SizedBox(height: 16),
                    _buildSectionCard(
                      title: "Biểu tượng",
                      subtitle: "Chọn nhóm icon, sau đó chọn biểu tượng",
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildIconGroupTabs(),
                          const SizedBox(height: 18),
                          _buildIconGrid(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildExistingCategoriesCard(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppThemeColor.primaryPurple,
            AppThemeColor.primaryIndigo,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          child: Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => Navigator.pop(context, changed),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 8,
                  ),
                  child: Text(
                    "Hủy",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white.withOpacity(0.94),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      editingCategory == null ? "Thêm danh mục" : "Sửa danh mục",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      editingCategory == null
                          ? "Tạo danh mục chi tiêu mới"
                          : "Cập nhật thông tin danh mục",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.78),
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: saving ? null : _saveCategory,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.28),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.16),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: saving
                      ? const Padding(
                    padding: EdgeInsets.all(11),
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                      : const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditorCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  "Thông tin danh mục",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppThemeColor.textPrimary,
                  ),
                ),
              ),
              if (editingCategory != null)
                InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: saving ? null : _clearForm,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: AppThemeColor.softPurple,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: AppThemeColor.primaryPurple.withOpacity(0.25),
                      ),
                    ),
                    child: const Text(
                      "Hủy sửa",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppThemeColor.primaryPurple,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: selectedColor,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: selectedColor.withOpacity(0.32),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(
                  selectedIcon,
                  color: Colors.white,
                  size: 36,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: nameController,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => saving ? null : _saveCategory(),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppThemeColor.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: "Nhập tên danh mục",
                    hintStyle: const TextStyle(
                      color: AppThemeColor.textMuted,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    prefixIcon: const Icon(
                      Icons.edit_rounded,
                      color: AppThemeColor.textMuted,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(
                        color: AppThemeColor.border,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(
                        color: AppThemeColor.primaryPurple,
                        width: 1.4,
                      ),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppThemeColor.softPurple.withOpacity(0.55),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppThemeColor.primaryPurple.withOpacity(0.12),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: AppThemeColor.primaryPurple.withOpacity(0.75),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    editingCategory == null
                        ? "Sau khi chọn icon và màu, bấm nút tích để lưu."
                        : "Bạn đang sửa danh mục. Bấm Hủy sửa để tạo mới.",
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                      color: AppThemeColor.textSecondary,
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

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppThemeColor.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppThemeColor.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildColorPicker() {
    return Wrap(
      spacing: 13,
      runSpacing: 13,
      children: _pickColors.map((color) {
        final selected = color.value == selectedColor.value;

        return GestureDetector(
          onTap: () => setState(() => selectedColor = color),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? Colors.white : Colors.white,
                width: selected ? 3 : 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(selected ? 0.38 : 0.16),
                  blurRadius: selected ? 16 : 8,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: selected
                ? const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 25,
            )
                : null,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildIconGroupTabs() {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _iconGroups.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final group = _iconGroups[index];
          final selected = selectedIconGroupIndex == index;

          return InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () {
              setState(() => selectedIconGroupIndex = index);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected
                    ? AppThemeColor.primaryPurple
                    : const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected
                      ? AppThemeColor.primaryPurple
                      : AppThemeColor.border,
                ),
                boxShadow: selected
                    ? [
                  BoxShadow(
                    color: AppThemeColor.primaryPurple.withOpacity(0.18),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ]
                    : [],
              ),
              child: Text(
                group.title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : AppThemeColor.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildIconGrid() {
    final group = _iconGroups[selectedIconGroupIndex];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: group.icons.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
      ),
      itemBuilder: (_, index) {
        final item = group.icons[index];
        final selected = item.key == selectedIconKey;

        return GestureDetector(
          onTap: () {
            setState(() {
              selectedIconKey = item.key;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            decoration: BoxDecoration(
              color: selected ? selectedColor : const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected ? selectedColor : AppThemeColor.border,
                width: selected ? 1.5 : 1,
              ),
              boxShadow: selected
                  ? [
                BoxShadow(
                  color: selectedColor.withOpacity(0.28),
                  blurRadius: 14,
                  offset: const Offset(0, 7),
                ),
              ]
                  : [],
            ),
            child: Icon(
              item.icon,
              color: selected ? Colors.white : AppThemeColor.textSecondary,
              size: 27,
            ),
          ),
        );
      },
    );
  }

  Widget _buildExistingCategoriesCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  "Danh sách danh mục",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppThemeColor.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppThemeColor.softPurple,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  "${categories.length} mục",
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppThemeColor.primaryPurple,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: "Tìm danh mục",
              hintStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppThemeColor.textMuted,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppThemeColor.textMuted,
              ),
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 13,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppThemeColor.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppThemeColor.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: AppThemeColor.primaryPurple,
                  width: 1.4,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (filteredCategories.isEmpty)
            _buildEmptyState()
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredCategories.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, index) {
                return _buildCategoryItem(filteredCategories[index]);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 26),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppThemeColor.border),
      ),
      child: Column(
        children: [
          Icon(
            Icons.category_outlined,
            size: 42,
            color: AppThemeColor.primaryPurple.withOpacity(0.28),
          ),
          const SizedBox(height: 10),
          const Text(
            "Chưa có danh mục phù hợp",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppThemeColor.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryItem(Category cat) {
    final isEditing = editingCategory?.id == cat.id;
    final style = getCategoryStyle(cat);
    final color = style.color;
    final icon = style.icon;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _fillForm(cat),
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isEditing ? AppThemeColor.softPurple : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isEditing
                  ? AppThemeColor.primaryPurple.withOpacity(0.35)
                  : AppThemeColor.border,
              width: isEditing ? 1.4 : 1,
            ),
            boxShadow: isEditing
                ? [
              BoxShadow(
                color: AppThemeColor.primaryPurple.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 7),
              ),
            ]
                : [],
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.18),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 25,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cat.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w900,
                        color: AppThemeColor.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isEditing ? "Đang chỉnh sửa" : "Nhấn để sửa danh mục",
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: isEditing
                            ? AppThemeColor.primaryPurple
                            : AppThemeColor.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: AppThemeColor.textSecondary,
                ),
                onSelected: (value) {
                  if (value == "edit") {
                    _fillForm(cat);
                  }

                  if (value == "delete") {
                    _deleteCategory(cat);
                  }
                },
                itemBuilder: (_) {
                  return [
                    const PopupMenuItem(
                      value: "edit",
                      child: Row(
                        children: [
                          Icon(
                            Icons.edit_rounded,
                            size: 20,
                            color: AppThemeColor.primaryPurple,
                          ),
                          SizedBox(width: 10),
                          Text(
                            "Sửa",
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppThemeColor.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: "delete",
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_rounded,
                            size: 20,
                            color: AppThemeColor.danger,
                          ),
                          SizedBox(width: 10),
                          Text(
                            "Xóa",
                            style: TextStyle(
                              color: AppThemeColor.danger,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ];
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: AppThemeColor.card,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: AppThemeColor.softPurple.withOpacity(0.9),
      ),
      boxShadow: [
        BoxShadow(
          color: AppThemeColor.primaryPurple.withOpacity(0.06),
          blurRadius: 26,
          offset: const Offset(0, 12),
        ),
      ],
    );
  }
}

int _findGroupIndexByIconKey(String key) {
  for (int i = 0; i < _iconGroups.length; i++) {
    final group = _iconGroups[i];

    for (final icon in group.icons) {
      if (icon.key == key) {
        return i;
      }
    }
  }

  return 0;
}

class _CatIcon {
  final String key;
  final IconData icon;

  const _CatIcon(this.key, this.icon);
}

class _IconGroup {
  final String title;
  final List<_CatIcon> icons;

  const _IconGroup(this.title, this.icons);
}

const List<Color> _pickColors = [
  Color(0xFFE3B72F),
  Color(0xFF20C997),
  Color(0xFFF06292),
  Color(0xFF35C928),
  Color(0xFFFF7A1A),
  Color(0xFFFF5A66),
  Color(0xFFB56BD8),
  Color(0xFFD7A090),
  Color(0xFFFFB984),
  Color(0xFF67C2CE),
  Color(0xFFE87368),
  Color(0xFF7FB414),
  Color(0xFF8F83EE),
  Color(0xFFC9B514),
];

const List<_IconGroup> _iconGroups = [
  _IconGroup(
    "Đồ ăn",
    [
      _CatIcon("restaurant", Icons.restaurant),
      _CatIcon("fastfood", Icons.fastfood),
      _CatIcon("local_cafe", Icons.local_cafe),
      _CatIcon("cake", Icons.cake),
      _CatIcon("local_bar", Icons.local_bar),
      _CatIcon("icecream", Icons.icecream),
      _CatIcon("local_pizza", Icons.local_pizza),
      _CatIcon("rice_bowl", Icons.rice_bowl),
      _CatIcon("lunch_dining", Icons.lunch_dining),
      _CatIcon("egg", Icons.egg),
    ],
  ),
  _IconGroup(
    "Mua sắm",
    [
      _CatIcon("shopping_bag", Icons.shopping_bag),
      _CatIcon("shopping_cart", Icons.shopping_cart),
      _CatIcon("store", Icons.store),
      _CatIcon("local_mall", Icons.local_mall),
      _CatIcon("checkroom", Icons.checkroom),
      _CatIcon("watch", Icons.watch),
      _CatIcon("diamond", Icons.diamond),
      _CatIcon("sell", Icons.sell),
      _CatIcon("redeem", Icons.redeem),
      _CatIcon("card_giftcard", Icons.card_giftcard),
    ],
  ),
  _IconGroup(
    "Cuộc sống",
    [
      _CatIcon("home", Icons.home),
      _CatIcon("chair", Icons.chair),
      _CatIcon("bed", Icons.bed),
      _CatIcon("tv", Icons.tv),
      _CatIcon("camera_alt", Icons.camera_alt),
      _CatIcon("pets", Icons.pets),
      _CatIcon("build", Icons.build),
      _CatIcon("lightbulb", Icons.lightbulb),
      _CatIcon("cleaning_services", Icons.cleaning_services),
      _CatIcon("weekend", Icons.weekend),
    ],
  ),
  _IconGroup(
    "Cá nhân",
    [
      _CatIcon("person", Icons.person),
      _CatIcon("face", Icons.face),
      _CatIcon("favorite", Icons.favorite),
      _CatIcon("spa", Icons.spa),
      _CatIcon("music_note", Icons.music_note),
      _CatIcon("psychology", Icons.psychology),
      _CatIcon("self_improvement", Icons.self_improvement),
      _CatIcon("emoji_emotions", Icons.emoji_emotions),
      _CatIcon("accessibility_new", Icons.accessibility_new),
      _CatIcon("local_florist", Icons.local_florist),
    ],
  ),
  _IconGroup(
    "Giáo dục",
    [
      _CatIcon("school", Icons.school),
      _CatIcon("menu_book", Icons.menu_book),
      _CatIcon("edit", Icons.edit),
      _CatIcon("calculate", Icons.calculate),
      _CatIcon("science", Icons.science),
      _CatIcon("laptop", Icons.laptop),
      _CatIcon("language", Icons.language),
      _CatIcon("library_books", Icons.library_books),
      _CatIcon("history_edu", Icons.history_edu),
      _CatIcon("class", Icons.class_),
    ],
  ),
  _IconGroup(
    "Thể thao",
    [
      _CatIcon("sports_soccer", Icons.sports_soccer),
      _CatIcon("fitness_center", Icons.fitness_center),
      _CatIcon("sports_basketball", Icons.sports_basketball),
      _CatIcon("sports_tennis", Icons.sports_tennis),
      _CatIcon("pool", Icons.pool),
      _CatIcon("directions_bike", Icons.directions_bike),
      _CatIcon("sports_handball", Icons.sports_handball),
      _CatIcon("sports_martial_arts", Icons.sports_martial_arts),
      _CatIcon("sports_gymnastics", Icons.sports_gymnastics),
      _CatIcon("sports", Icons.sports),
    ],
  ),
  _IconGroup(
    "Đi lại",
    [
      _CatIcon("directions_car", Icons.directions_car),
      _CatIcon("directions_bus", Icons.directions_bus),
      _CatIcon("train", Icons.train),
      _CatIcon("flight", Icons.flight),
      _CatIcon("two_wheeler", Icons.two_wheeler),
      _CatIcon("local_taxi", Icons.local_taxi),
      _CatIcon("local_gas_station", Icons.local_gas_station),
      _CatIcon("local_parking", Icons.local_parking),
      _CatIcon("sailing", Icons.sailing),
      _CatIcon("local_shipping", Icons.local_shipping),
    ],
  ),
  _IconGroup(
    "Sức khỏe",
    [
      _CatIcon("medical_services", Icons.medical_services),
      _CatIcon("local_hospital", Icons.local_hospital),
      _CatIcon("healing", Icons.healing),
      _CatIcon("monitor_heart", Icons.monitor_heart),
      _CatIcon("medication", Icons.medication),
      _CatIcon("accessible", Icons.accessible),
      _CatIcon("health_and_safety", Icons.health_and_safety),
      _CatIcon("favorite_border", Icons.favorite_border),
      _CatIcon("emergency", Icons.emergency),
      _CatIcon("bloodtype", Icons.bloodtype),
    ],
  ),
  _IconGroup(
    "Du lịch",
    [
      _CatIcon("luggage", Icons.luggage),
      _CatIcon("beach_access", Icons.beach_access),
      _CatIcon("map", Icons.map),
      _CatIcon("hotel", Icons.hotel),
      _CatIcon("location_on", Icons.location_on),
      _CatIcon("landscape", Icons.landscape),
      _CatIcon("tour", Icons.tour),
      _CatIcon("photo_camera", Icons.photo_camera),
      _CatIcon("explore", Icons.explore),
      _CatIcon("terrain", Icons.terrain),
    ],
  ),
  _IconGroup(
    "Tài chính",
    [
      _CatIcon("attach_money", Icons.attach_money),
      _CatIcon("payments", Icons.payments),
      _CatIcon("account_balance", Icons.account_balance),
      _CatIcon("credit_card", Icons.credit_card),
      _CatIcon("wallet", Icons.wallet),
      _CatIcon("savings", Icons.savings),
      _CatIcon("trending_up", Icons.trending_up),
      _CatIcon("receipt_long", Icons.receipt_long),
      _CatIcon("request_quote", Icons.request_quote),
      _CatIcon("currency_bitcoin", Icons.currency_bitcoin),
    ],
  ),
  _IconGroup(
    "Khác",
    [
      _CatIcon("more_horiz", Icons.more_horiz),
      _CatIcon("category", Icons.category),
      _CatIcon("extension", Icons.extension),
      _CatIcon("mail", Icons.mail),
      _CatIcon("phone", Icons.phone),
      _CatIcon("work", Icons.work),
      _CatIcon("print", Icons.print),
      _CatIcon("settings", Icons.settings),
      _CatIcon("star", Icons.star),
      _CatIcon("help", Icons.help),
    ],
  ),
];

_CatIcon _findIcon(String? key) {
  for (final group in _iconGroups) {
    for (final icon in group.icons) {
      if (icon.key == key) {
        return icon;
      }
    }
  }

  return _iconGroups.first.icons.first;
}

String _colorToHex(Color color) {
  final value = color.value.toRadixString(16).padLeft(8, "0");
  return "#${value.substring(2).toUpperCase()}";
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