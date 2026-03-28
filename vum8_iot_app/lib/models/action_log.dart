import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ActionLog {
  final String date;
  final String time;
  final String type;
  final String title;
  final String deviceId;
  final String actionText;
  final String valueText;
  final Color primaryColor;
  final bool isFail;

  ActionLog({
    required this.date,
    required this.time,
    required this.type,
    required this.title,
    required this.deviceId,
    required this.actionText,
    required this.valueText,
    required this.primaryColor,
    this.isFail = false,
  });

  factory ActionLog.fromJson(Map<String, dynamic> json, Color color) {
    DateTime createdAt = json['created_at'] != null
        ? DateTime.parse(json['created_at'].toString()).toLocal()
        : DateTime.now();

    double tempVal = double.tryParse(json['temp'].toString()) ?? 0;

    if (tempVal == -1) {
      int deviceCode = int.tryParse(json['light'].toString()) ?? 1;
      int statusCode = int.tryParse(json['humid'].toString()) ?? -1;

      // --- BƯỚC 3: CHỐT CHẶN KIỂM TRA TRỰC TIẾP CHUỖI STATUS ---
      // Lấy field 'status' từ JSON (nếu Backend có trả về kèm theo kết quả query)
      String rawStatus = (json['status'] ?? "").toString().toLowerCase();

      String deviceName = "";
      if (deviceCode == 1) deviceName = "Đèn chiếu sáng";
      else if (deviceCode == 2) deviceName = "Quạt thông gió";
      else deviceName = "Máy tạo ẩm";

      // Logic cũ dựa trên code humid ảo
      bool isTurnOn = (statusCode == 1 || statusCode == 3);

      // LOGIC MỚI (BƯỚC 3): Kết hợp cả statusCode và chuỗi rawStatus để xác định lỗi
      // Nếu statusCode là 2, 3 HOẶC chuỗi status chứa chữ "thất bại"/"fail"
      bool isFail = (statusCode == 2 || statusCode == 3 || rawStatus.contains("thất bại") || rawStatus.contains("fail"));

      // Chốt chặn cuối: Nếu status rác (-1 hoặc 4) nhưng Server trả về chuỗi thất bại
      if (statusCode == -1 || statusCode == 4) {
        if (rawStatus.contains("thành công") || rawStatus.contains("success")) {
          isFail = false;
        } else {
          isFail = true; // Mặc định nghi ngờ là lỗi nếu dữ liệu không xác định
        }
      }

      return ActionLog(
        date: DateFormat('dd/MM/yyyy').format(createdAt),
        time: DateFormat('HH:mm:ss').format(createdAt),
        type: 'device',
        title: deviceName,
        deviceId: 'ID: CTRL_${json['id']}',
        actionText: 'Hành động:',
        valueText: isTurnOn ? "Turn On" : "Turn Off",
        primaryColor: isFail ? Colors.orange : (isTurnOn ? Colors.green : Colors.redAccent),
        isFail: isFail,
      );
    } else {
      return ActionLog(
        date: DateFormat('dd/MM/yyyy').format(createdAt),
        time: DateFormat('HH:mm:ss').format(createdAt),
        type: 'sensor',
        title: 'Dữ liệu cảm biến',
        deviceId: 'ID: NODE_${json['id']}',
        actionText: 'T: ${json['temp']}°C | H: ${json['humid']}%',
        valueText: '${json['light']} Lx',
        primaryColor: color,
        isFail: false,
      );
    }
  }
}