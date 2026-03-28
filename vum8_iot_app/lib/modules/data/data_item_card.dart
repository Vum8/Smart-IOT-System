import 'package:flutter/material.dart';
import '../../../core/app_colors.dart';
import '../../../models/sensor_record.dart';

class DataItemCard extends StatelessWidget {
  final SensorRecord record;

  const DataItemCard({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    // Lấy màu đặc trưng từ record (ví dụ: đỏ cho nhiệt độ, vàng cho ánh sáng)
    final Color itemColor = record.color;

    // Tạo một màu nền cực nhạt dựa trên màu cảm biến để nhuộm nhẹ Card
    final Color tintColor = itemColor.withOpacity(0.05);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      height: 95,
      decoration: BoxDecoration(
        color: Colors.white,
        // Hiệu ứng loang màu nhẹ từ trắng sang màu của cảm biến
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, tintColor],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: itemColor.withOpacity(0.12), // Bóng đổ mang sắc thái cảm biến
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
        border: Border.all(color: itemColor.withOpacity(0.1), width: 1),
      ),
      child: Row(
        children: [
          // --- THANH CHỈ THỊ MÀU BÊN TRÁI ---
          Container(
            width: 6,
            margin: const EdgeInsets.symmetric(vertical: 15), // Thu ngắn lại cho tinh tế
            decoration: BoxDecoration(
              color: itemColor,
              borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(10), bottomRight: Radius.circular(10)),
            ),
          ),
          const SizedBox(width: 15),

          // --- PHẦN THÔNG TIN (LOẠI & THỜI GIAN) ---
          Expanded(
            flex: 3,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.type,
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3436)), // Màu xám đen sâu cho sang
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined,
                        size: 14, color: itemColor.withOpacity(0.7)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        record.time,
                        style: TextStyle(
                            color: itemColor.withOpacity(0.8),
                            fontSize: 12,
                            fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // --- PHẦN GIÁ TRỊ VÀ UNIT ---
          Flexible(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: RichText(
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        children: [
                          TextSpan(
                              text: record.value,
                              style: TextStyle(
                                  color: itemColor,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.5)),
                          const TextSpan(text: ' '),
                          TextSpan(
                            text: record.unit,
                            style: const TextStyle(
                                color: AppColors.textMain,
                                fontSize: 14,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Icon mũi tên lên/xuống đồng bộ màu
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: itemColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      record.isUp ? Icons.arrow_upward : Icons.arrow_downward,
                      color: itemColor,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}