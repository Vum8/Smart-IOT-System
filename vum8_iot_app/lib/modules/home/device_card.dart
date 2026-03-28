import 'package:flutter/material.dart';
import '../../../core/app_colors.dart';

class DeviceCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isOn;
  final bool isProcessing;
  final Function(bool) onChanged;

  const DeviceCard({
    super.key,
    required this.title,
    required this.icon,
    required this.isOn,
    required this.isProcessing,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Tinh chỉnh màu sắc theo trạng thái On/Off
    final Color activeColor = AppColors.primary;
    final Color inactiveColor = AppColors.textSecondary.withOpacity(0.4);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300), // Hiệu ứng chuyển màu mượt mà
      decoration: BoxDecoration(
        // Khi ON: Nhuộm màu xanh cực nhạt. Khi OFF: Trắng tinh khôi
        color: isOn ? activeColor.withOpacity(0.08) : Colors.white,
        borderRadius: BorderRadius.circular(20), // Bo góc 20 cho đồng bộ SensorCard
        border: Border.all(
          color: isOn ? activeColor.withOpacity(0.3) : AppColors.border.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isOn ? activeColor.withOpacity(0.1) : Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon thiết bị với vòng tròn nền
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isOn ? activeColor.withOpacity(0.15) : Colors.grey.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 24,
              color: isOn ? activeColor : inactiveColor,
            ),
          ),
          const SizedBox(height: 10),

          // Tên thiết bị
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isOn ? FontWeight.bold : FontWeight.w500,
                color: isOn ? activeColor.withOpacity(0.8) : AppColors.textMain,
              ),
            ),
          ),
          const SizedBox(height: 6),

          // Trạng thái điều khiển
          isProcessing
              ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          )
              : Transform.scale(
            scale: 0.75, // Tăng nhẹ kích thước switch cho dễ bấm
            child: Switch(
              value: isOn,
              onChanged: onChanged,
              activeColor: Colors.white,
              activeTrackColor: activeColor,
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: Colors.grey.shade300,
            ),
          ),
        ],
      ),
    );
  }
}