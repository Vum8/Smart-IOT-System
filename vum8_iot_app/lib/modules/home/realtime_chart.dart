import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/app_colors.dart';

class RealtimeChart extends StatelessWidget {
  final List<FlSpot> tempSpots;
  final List<FlSpot> humidSpots;
  final List<FlSpot> lightSpots;
  final double minX;
  final double maxX;

  const RealtimeChart({
    super.key,
    required this.tempSpots,
    required this.humidSpots,
    required this.lightSpots,
    required this.minX,
    required this.maxX,
  });

  final Color tempColor = AppColors.chartTemp;
  final Color humidColor = AppColors.chartHumid;
  final Color lightColor = AppColors.chartLight;

  String _formatTime(double value) {
    DateTime date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
    return "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 440,
      padding: const EdgeInsets.fromLTRB(10, 25, 20, 15),
      decoration: BoxDecoration(
        // Gradient nội bộ tạo độ sâu như biển nước
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            const Color(0xFFE3F2FD).withOpacity(0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.8), width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.08),
            blurRadius: 25,
            offset: const Offset(0, 12),
          )
        ],
      ),
      child: Column(
        children: [
          Text(
            "DỮ LIỆU CẢM BIẾN THEO THỜI GIAN",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              color: AppColors.textMain.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 30),
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 40, right: 5),
                  child: LineChart(
                    duration: Duration.zero,
                    LineChartData(
                      minY: 0,
                      maxY: 5500, // Tăng nhẹ để tránh chạm đỉnh
                      minX: minX,
                      maxX: maxX,
                      clipData: const FlClipData(left: true, top: true, right: false, bottom: true),
                      lineTouchData: _buildTouchData(),
                      gridData: FlGridData(
                        show: true,
                        horizontalInterval: 1000,
                        drawVerticalLine: false, // Xóa lưới dọc cho thoáng
                        getDrawingHorizontalLine: (v) => FlLine(
                          color: AppColors.primary.withOpacity(0.1),
                          strokeWidth: 1,
                          dashArray: [6, 6], // Lưới đứt đoạn tinh tế
                        ),
                      ),
                      titlesData: _buildTitlesData(),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        _buildLineBar(tempSpots, tempColor, isSmallValue: true),
                        _buildLineBar(humidSpots, humidColor, isSmallValue: true),
                        _buildLineBar(lightSpots, lightColor, isSmallValue: false),
                      ],
                    ),
                  ),
                ),
                // Label thời gian được đóng khung nhẹ
                Positioned(
                  bottom: 0,
                  left: 40,
                  child: _buildTimeLabel("BẮT ĐẦU", minX),
                ),
                Positioned(
                  bottom: 0,
                  right: 40,
                  child: _buildTimeLabel("HIỆN TẠI", maxX),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          _buildLegend(),
        ],
      ),
    );
  }

  Widget _buildTimeLabel(String title, double value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(title, style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.blueGrey.withOpacity(0.7))),
          Text(_formatTime(value), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.textMain)),
        ],
      ),
    );
  }

  LineTouchData _buildTouchData() {
    return LineTouchData(
      handleBuiltInTouches: true,
      touchTooltipData: LineTouchTooltipData(
        getTooltipColor: (spot) => AppColors.textMain.withOpacity(0.9),
        tooltipRoundedRadius: 12,
        tooltipPadding: const EdgeInsets.all(12),
        getTooltipItems: (List<LineBarSpot> touchedSpots) {
          return touchedSpots.map((spot) {
            Color displayColor = spot.barIndex == 0 ? tempColor : (spot.barIndex == 1 ? humidColor : lightColor);
            String label = spot.barIndex == 0 ? "Nhiệt độ: " : (spot.barIndex == 1 ? "Độ ẩm: " : "Ánh sáng: ");
            String unit = spot.barIndex == 0 ? "°C" : (spot.barIndex == 1 ? "%" : " Lux");
            double realValue = (spot.barIndex == 0 || spot.barIndex == 1) ? spot.y / 50 : spot.y;

            return LineTooltipItem(
              "${_formatTime(spot.x)}\n$label${realValue.toStringAsFixed(1)}$unit",
              TextStyle(color: displayColor, fontWeight: FontWeight.bold, fontSize: 13),
            );
          }).toList();
        },
      ),
    );
  }

  FlTitlesData _buildTitlesData() {
    return FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 35,
          interval: 1000,
          getTitlesWidget: (v, m) {
            int displayVal = (v / 50).toInt();
            if (displayVal > 100) return const SizedBox();
            return Text('$displayVal', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey.withOpacity(0.5)));
          },
        ),
      ),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 40,
          interval: 1000,
          getTitlesWidget: (v, m) => Text('${v.toInt()}', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey.withOpacity(0.5))),
        ),
      ),
    );
  }

  LineChartBarData _buildLineBar(List<FlSpot> spots, Color color, {required bool isSmallValue}) {
    List<FlSpot> finalSpots = isSmallValue ? spots.map((s) => FlSpot(s.x, s.y * 50)).toList() : spots;

    return LineChartBarData(
      spots: finalSpots,
      isCurved: true,
      curveSmoothness: 0.2,
      color: color,
      barWidth: 3.5,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      // Hiệu ứng bóng đổ cho đường line phát sáng
      shadow: Shadow(
        color: color.withOpacity(0.4),
        blurRadius: 8,
        offset: const Offset(0, 4),
      ),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          colors: [color.withOpacity(0.25), color.withOpacity(0.0)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.03),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _legItem(tempColor, "Nhiệt độ"),
          _legItem(humidColor, "Độ ẩm"),
          _legItem(lightColor, "Ánh sáng"),
        ],
      ),
    );
  }

  Widget _legItem(Color c, String l) {
    return Row(children: [
      Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
              color: c,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: c.withOpacity(0.4), blurRadius: 4)]
          )
      ),
      const SizedBox(width: 8),
      Text(l, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMain)),
    ]);
  }
}