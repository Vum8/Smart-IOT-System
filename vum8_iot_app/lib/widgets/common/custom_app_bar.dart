import 'package:flutter/material.dart';
import '../../core/app_colors.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final int currentIndex;

  const CustomAppBar({super.key, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent, // Giữ transparent để thấy Gradient nền Profile
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,

      // Icon Leading: Dùng màu Primary (Xanh Vum8)
      leading: Icon(
          Icons.grid_view_rounded,
          color: AppColors.primary,
          size: 24
      ),

      title: Text(
          _getTitle(),
          style: const TextStyle(
            color: AppColors.textMain, // Sử dụng màu Đen xanh mới cho sắc nét
            fontSize: 18,
            fontWeight: FontWeight.w900, // Đậm nhất để làm điểm nhấn
            letterSpacing: -0.2,
          )
      ),

      actions: [
        _buildActionIcon(),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildActionIcon() {
    // Màu Icon action dùng màu textMain để đồng bộ
    if (currentIndex == 2) {
      return IconButton(
        icon: const Icon(Icons.filter_list_rounded, color: AppColors.textMain),
        onPressed: () => print("Mở lọc"),
      );
    }

    if (currentIndex == 3) {
      return IconButton(
        icon: const Icon(Icons.settings_outlined, color: AppColors.textMain),
        onPressed: () => print("Cài đặt"),
      );
    }

    return IconButton(
      icon: const Icon(Icons.more_vert_rounded, color: AppColors.textMain),
      onPressed: () {},
    );
  }

  String _getTitle() {
    switch (currentIndex) {
      case 0: return "Vum8 Smart Home";
      case 1: return "Dữ liệu cảm biến";
      case 2: return "Lịch sử hoạt động";
      case 3: return "Thông tin cá nhân";
      default: return "";
    }
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}