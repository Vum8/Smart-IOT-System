import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/sensor_record.dart';

class SensorService {
  final String baseUrl = "http://192.168.85.13:3000/api/sensors"; // Thay IP Server của bạn

  Future<Map<String, dynamic>> fetchRealSensors({
    int page = 1,
    String keyword = "",
    String? sensorType,
    String? date,
    String? startTime,
    String? endTime,
  }) async {
    try {
      // Xây dựng URL động giống trang History
      String url = "$baseUrl?page=$page&keyword=$keyword";
      if (date != null) url += "&date=$date";
      if (startTime != null && endTime != null) url += "&startTime=$startTime&endTime=$endTime";

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        Map<String, dynamic> body = jsonDecode(response.body);
        List<dynamic> data = body['data'];

        List<SensorRecord> records = [];
        for (var item in data) {
          records.addAll(SensorRecord.fromJson(item));
        }

        return {
          "total": body['totalPages'],
          "data": records
        };
      }
      return {"total": 1, "data": []};
    } catch (e) {
      print("❌ Lỗi Fetch Sensors: $e");
      return {"total": 1, "data": []};
    }
  }
}