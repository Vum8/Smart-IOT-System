import 'package:flutter/material.dart';
import '../../../core/app_colors.dart';

class SensorCard extends StatefulWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  final bool isFullWidth;

  const SensorCard({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    this.isFullWidth = false,
  });

  @override
  State<SensorCard> createState() => _SensorCardState();
}

class _SensorCardState extends State<SensorCard> {
  // Hàm parse giá trị
  double? _parseValue(String valueStr) {
    final cleaned = valueStr.replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(cleaned);
  }

  // LOGIC ĐỔI MÀU CẢNH BÁO
  Color _calculateStatusColor() {
    final valueNum = _parseValue(widget.value);
    if (valueNum == null) return widget.color;

    final labelLower = widget.label.toLowerCase();

    if (labelLower.contains('nhiệt độ')) {
      if (valueNum > 35) return Colors.redAccent;
      if (valueNum < 18) return Colors.blueAccent;
    } else if (labelLower.contains('độ ẩm')) {
      if (valueNum > 75) return Colors.indigoAccent;
      if (valueNum < 35) return Colors.deepOrange;
    } else if (labelLower.contains('ánh sáng')) {
      if (valueNum > 2500) return const Color(0xFFFFD700);
      if (valueNum < 300) return const Color(0xFF6A1B9A);
    }
    return widget.color;
  }

  @override
  Widget build(BuildContext context) {
    // 1. Lấy màu cảnh báo hiện tại
    final Color statusColor = _calculateStatusColor();

    // 2. Tạo màu nền nhạt (12% độ mờ) để nhuộm màu toàn bộ thẻ
    final Color backgroundColor = statusColor.withOpacity(0.12);

    // 3. Làm màu chữ đậm hơn một chút để dễ đọc trên nền màu
    final Color textColor = Color.lerp(statusColor, Colors.black, 0.4) ?? statusColor;

    return Container(
      width: widget.isFullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white, // Lót nền trắng để nổi trên biển nước
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            backgroundColor, // Nhuộm màu ở góc dưới để người dùng dễ nhận biết
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        children: [
          // Icon nằm trong vòng tròn nhạt
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(widget.icon, color: statusColor, size: 28),
          ),
          const SizedBox(height: 10),
          Text(
            widget.value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: textColor, // Chữ đổi màu theo trạng thái
            ),
          ),
          Text(
            widget.label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}