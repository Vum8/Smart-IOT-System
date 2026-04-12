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
    // 1. Xử lý thời gian chuẩn GMT+7
    DateTime createdAt = json['created_at'] != null
        ? DateTime.parse(json['created_at'].toString()).toLocal()
        : DateTime.now();

    // 2. ĐỌC DỮ LIỆU TỪ BACKEND (Sử dụng các Key đã "dọn rác")
    // Thay vì json['humid'], ta dùng đúng tên 'status_code'
    int sCode = int.tryParse(json['status_code']?.toString() ?? "4") ?? 4;

    // Thay vì json['light'], ta dùng đúng tên 'device_type'
    int dType = int.tryParse(json['device_type']?.toString() ?? "1") ?? 1;

    String rawStatus = (json['status'] ?? "").toString().toLowerCase();
    String deviceNameFromDB = json['device_name'] ?? "";

    // 3. XÁC ĐỊNH TÊN THIẾT BỊ (Ưu tiên tên từ DB join sang)
    String displayTitle = deviceNameFromDB.isNotEmpty
        ? deviceNameFromDB
        : (dType == 1
              ? "Đèn chiếu sáng"
              : (dType == 2 ? "Quạt thông gió" : "Máy tạo ẩm"));

    // 4. LOGIC XÁC ĐỊNH TRẠNG THÁI (Dựa trên status_code mới)
    // 1 & 3 là các mã dành cho hành động Bật (Thành công/Thất bại)
    bool isTurnOn = (sCode == 1 || sCode == 3);

    // 2 & 3 là các mã dành cho Thất bại
    bool isFail =
        (sCode == 2 ||
        sCode == 3 ||
        rawStatus.contains("thất bại") ||
        rawStatus.contains("fail"));

    return ActionLog(
      date: DateFormat('dd/MM/yyyy').format(createdAt),
      time: DateFormat('HH:mm:ss').format(createdAt),
      type: 'device', // Trang lịch sử giờ chỉ có thiết bị
      title: displayTitle,
      deviceId: 'ID: CTRL_${json['id']}',
      actionText: 'Hành động:',
      valueText: isTurnOn ? "Turn On" : "Turn Off",
      // Màu sắc: Lỗi = Cam | Bật = Xanh | Tắt = Đỏ
      primaryColor: isFail
          ? Colors.orange
          : (isTurnOn ? Colors.green : Colors.redAccent),
      isFail: isFail,
    );
  }
}
