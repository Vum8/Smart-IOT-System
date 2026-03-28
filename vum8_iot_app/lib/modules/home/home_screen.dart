import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;

import '../../core/app_colors.dart';
import 'device_card.dart';
import 'realtime_chart.dart';
import 'sensor_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late IO.Socket socket;

  List<FlSpot> tempSpots = [];
  List<FlSpot> humidSpots = [];
  List<FlSpot> lightSpots = [];

  double _currentX = 0;
  final double _viewportWidthMs = 20000;
  late AnimationController _flowController;

  Map<String, bool> deviceStates = {
    "Quạt thông gió": false,
    "Đèn chiếu sáng": false,
    "Máy tạo ẩm": false
  };

  Map<String, bool> previousStates = {};

  Map<String, bool> processingDevices = {
    "Quạt thông gió": false,
    "Đèn chiếu sáng": false,
    "Máy tạo ẩm": false
  };

  bool isHardwareOnline = false;
  Timer? _onlineCheckTimer;

  @override
  void initState() {
    super.initState();
    _currentX = DateTime.now().millisecondsSinceEpoch.toDouble();
    _initSocket();

    _flowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(() {
      if (!mounted) return;
      setState(() {
        _currentX = DateTime.now().millisecondsSinceEpoch.toDouble();
        double threshold = _currentX - 60000;
        tempSpots.removeWhere((spot) => spot.x < threshold);
        humidSpots.removeWhere((spot) => spot.x < threshold);
        lightSpots.removeWhere((spot) => spot.x < threshold);
      });
    });
    _flowController.repeat();
  }

  void _initSocket() {
    socket = IO.io('http://10.0.2.2:3000', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    socket.connect();

    socket.onConnect((_) {
      debugPrint('✅ Kết nối Server thành công');
      socket.emit('request_data', '1');
    });

    socket.on('sensor_update', (data) {
      if (mounted) {
        setState(() => isHardwareOnline = true);
        _resetOnlineTimer();

        _addNewDataPoint(
          double.parse(data['temp'].toString()),
          double.parse(data['hum'].toString()),
          double.parse(data['light'].toString()),
        );
      }
    });

    socket.on('device_status_ack', (data) {
      String deviceKey = data['device'];
      String rawStatus = data['status']?.toString().toUpperCase() ?? "OFF";

      String? displayName;
      if (deviceKey == "light") displayName = "Đèn chiếu sáng";
      if (deviceKey == "temp") displayName = "Quạt thông gió";
      if (deviceKey == "humid") displayName = "Máy tạo ẩm";

      if (displayName != null && mounted) {
        final String name = displayName;
        setState(() {
          processingDevices[name] = false;
          if (rawStatus == "FAIL" || rawStatus == "ERROR") {
            if (previousStates.containsKey(name)) {
              deviceStates[name] = previousStates[name]!;
            }
            _showErrorSnackBar("Lỗi: $name không phản hồi!");
          } else {
            deviceStates[name] = (rawStatus == "ON");
          }
        });
      }
    });

    socket.onDisconnect((_) {
      if (mounted) setState(() => isHardwareOnline = false);
    });
  }

  void _resetOnlineTimer() {
    _onlineCheckTimer?.cancel();
    _onlineCheckTimer = Timer(const Duration(seconds: 10), () {
      if (mounted) setState(() => isHardwareOnline = false);
    });
  }

  void _addNewDataPoint(double t, double h, double l) {
    double now = DateTime.now().millisecondsSinceEpoch.toDouble();
    if (!mounted) return;
    setState(() {
      tempSpots.add(FlSpot(now, t));
      humidSpots.add(FlSpot(now, h));
      lightSpots.add(FlSpot(now, l));
    });
  }

  Future<void> _toggleDevice(String name, String deviceKey) async {
    if (!isHardwareOnline) {
      _showErrorSnackBar("Mạch đang Offline!");
      return;
    }

    bool oldState = deviceStates[name] ?? false;
    setState(() {
      processingDevices[name] = true;
      previousStates[name] = oldState;
      deviceStates[name] = !oldState;
    });

    socket.emit('control_device', {
      'device': deviceKey,
      'action': oldState ? "0" : "1"
    });

    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && processingDevices[name] == true) {
        setState(() {
          processingDevices[name] = false;
          if (previousStates.containsKey(name)) {
            deviceStates[name] = previousStates[name]!;
          }
        });
        _showErrorSnackBar("Máy chủ không phản hồi!");
      }
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _onlineCheckTimer?.cancel();
    socket.dispose();
    _flowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String curT = tempSpots.isNotEmpty ? "${tempSpots.last.y.toStringAsFixed(1)}°C" : "--";
    String curH = humidSpots.isNotEmpty ? "${humidSpots.last.y.toStringAsFixed(0)}%" : "--";
    double lastL = lightSpots.isNotEmpty ? lightSpots.last.y : 0;

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        // HIỆU ỨNG BIỂN NƯỚC NHẸ: Dùng xanh cực nhạt xuyên suốt để tạo độ sâu mà không bị gắt
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFE3F2FD), // Xanh nhạt nhất (như mặt nước)
            Color(0xFFF0F7FF), // Xanh trắng (như đáy nước)
          ],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            // TRẢ LẠI VỊ TRÍ GỐC: Không dùng kToolbarHeight để tránh bị tụt sâu
            const SizedBox(height: 24),

            // --- TRẠNG THÁI HỆ THỐNG (Chiếc thuyền nổi nhẹ) ---
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03), // Đổ bóng rất mờ để tạo độ nổi tự nhiên
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  )
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, size: 10, color: isHardwareOnline ? Colors.green : Colors.red),
                  const SizedBox(width: 8),
                  Text(
                    isHardwareOnline ? "Hệ thống: Trực tuyến" : "Hệ thống: Ngoại tuyến",
                    style: TextStyle(
                        color: isHardwareOnline ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 13
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // --- CÁC CARD SENSOR ---
            Row(
              children: [
                Expanded(child: SensorCard(value: curT, label: "Nhiệt độ", icon: Icons.thermostat, color: AppColors.temperature)),
                const SizedBox(width: 12),
                Expanded(child: SensorCard(value: curH, label: "Độ ẩm", icon: Icons.water_drop, color: AppColors.humidity)),
              ],
            ),
            const SizedBox(height: 12),
            SensorCard(value: "${lastL.toStringAsFixed(0)} Lux", label: "Ánh sáng", icon: Icons.wb_sunny_outlined, color: AppColors.light, isFullWidth: true),

            const SizedBox(height: 32),

            // Đồ thị
            RealtimeChart(
              tempSpots: tempSpots,
              humidSpots: humidSpots,
              lightSpots: lightSpots,
              minX: _currentX - _viewportWidthMs,
              maxX: _currentX,
            ),

            const SizedBox(height: 32),

            // Grid thiết bị
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.82,
              children: [
                DeviceCard(title: "Quạt thông gió", icon: Icons.wind_power, isOn: deviceStates["Quạt thông gió"] ?? false, isProcessing: processingDevices["Quạt thông gió"] ?? false, onChanged: (v) => _toggleDevice("Quạt thông gió", "temp")),
                DeviceCard(title: "Đèn chiếu sáng", icon: Icons.lightbulb_outline, isOn: deviceStates["Đèn chiếu sáng"] ?? false, isProcessing: processingDevices["Đèn chiếu sáng"] ?? false, onChanged: (v) => _toggleDevice("Đèn chiếu sáng", "light")),
                DeviceCard(title: "Máy tạo ẩm", icon: Icons.cloud_queue, isOn: deviceStates["Máy tạo ẩm"] ?? false, isProcessing: processingDevices["Máy tạo ẩm"] ?? false, onChanged: (v) => _toggleDevice("Máy tạo ẩm", "humid")),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // Hàm _sectionTitle được giữ lại bên dưới để tránh lỗi build,
  // nhưng không còn được gọi trong Column nữa để màn hình sạch hơn.
  Widget _sectionTitle(String title) => Row(
    children: [
      Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
              color: const Color(0xFF1495FF),
              borderRadius: BorderRadius.circular(2)
          )
      ),
      const SizedBox(width: 8),
      Text(
          title,
          style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textMain
          )
      ),
    ],
  );
}