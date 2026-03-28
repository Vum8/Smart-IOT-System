import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/app_colors.dart';

class SensorRecord {
  final int id;
  final String type;
  final String time;
  final String value;
  final String unit;
  final Color color;
  final bool isUp;

  SensorRecord({
    required this.id,
    required this.type,
    required this.time,
    required this.value,
    required this.unit,
    required this.color,
    required this.isUp,
  });

  // Chuyển đổi 1 dòng dữ liệu từ DB thành 3 bản ghi (Nhiệt, Ẩm, Ánh sáng)
  static List<SensorRecord> fromJson(Map<String, dynamic> json) {
    DateTime createdAt = json['created_at'] != null
        ? DateTime.parse(json['created_at'].toString()).toLocal()
        : DateTime.now();

    String timeStr = DateFormat('dd/MM/yyyy - HH:mm:ss').format(createdAt);

    int id = json['id'];
    String sType = json['sensor_type'] ?? 'Không xác định';

    // --- XỬ LÝ LÀM TRÒN SỐ TẠI ĐÂY ---
    double rawValue = double.tryParse(json['temp'].toString()) ?? 0.0;
    String sValue = rawValue.toStringAsFixed(1); // Chỉ lấy 1 chữ số thập phân (32.3)
    // Nếu là Ánh sáng (số nguyên), có thể dùng .round().toString() nếu không muốn hiện .0

    Color sColor = AppColors.temperature;
    String sUnit = '℃';

    if (sType == 'Độ ẩm') {
      sColor = AppColors.humidity;
      sUnit = '%';
    } else if (sType == 'Ánh sáng') {
      sColor = AppColors.light;
      sUnit = 'Lux';
      sValue = rawValue.round().toString(); // Ánh sáng thì làm tròn thành số nguyên luôn
    }

    return [
      SensorRecord(
        id: id, type: sType, time: timeStr, value: sValue,
        unit: sUnit, color: sColor, isUp: true,
      ),
    ];
  }
}