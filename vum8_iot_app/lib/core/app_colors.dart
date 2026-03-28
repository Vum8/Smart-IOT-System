import 'package:flutter/material.dart';

class AppColors {
  // --- MÀU CHỦ ĐẠO (BRANDING) ---
  // Xanh dương đặc trưng của Logo Vum8
  static const Color primary = Color(0xFF1495FF);

  // MÀU NỀN: Chỉnh lại sang tông Blue-White cực nhạt để làm nổi bật Card trắng
  static const Color background = Color(0xFFF8FAFF);
  static const Color white = Colors.white;

  // --- MÀU CẢM BIẾN & THIẾT BỊ ---
  // Giữ nguyên các tông tươi sáng để biểu đồ không bị tối
  static const Color temperature = Color(0xFF1CDC6C); // Xanh lá (Sạch)
  static const Color humidity = Color(0xFF1495FF);    // Xanh dương (Nước)
  static const Color light = Color(0xFFFF5252);       // Đỏ hồng (Ánh sáng)

  // --- MÀU VĂN BẢN (CHUẨN FIGMA) ---
  static const Color textMain = Color(0xFF515357);      // Chữ chính (Đậm)
  static const Color textSecondary = Color(0xFF949597); // Chữ phụ
  static const Color textLight = Color(0xFFA0A1A4);     // Chữ mờ/Hint

  // --- ĐƯỜNG KẺ & ĐỔ BÓNG ---
  static const Color border = Color(0xFFF2F2F2);        // Viền Card cực nhạt
  static const Color shadow = Color(0x3F000000);        // Đổ bóng 25% Opacity

  // --- MÀU BIỂU ĐỒ (SẮC ĐỘ CAO) ---
  static const Color chartTemp = Color(0xFF00E676);
  static const Color chartHumid = Color(0xFF2196F3);
  static const Color chartLight = Color(0xFFFF4081);

  // --- GRADIENT (Cho các Header hoặc Nút bấm nếu cần) ---
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF1495FF), Color(0xFF64B5F6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}