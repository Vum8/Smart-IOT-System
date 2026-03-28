import 'package:flutter/material.dart';
import '../../../core/app_colors.dart';
import 'package:intl/intl.dart';

class FilterBottomSheet extends StatefulWidget {
  const FilterBottomSheet({super.key});

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  String selectedType = 'Tất cả giá trị';
  String selectedDuration = '30 phút';
  DateTime? selectedDate;
  TimeOfDay? startTime;
  TimeOfDay? endTime;

  final List<String> types = ['Tất cả giá trị', 'Nhiệt độ', 'Ánh sáng', 'Độ ẩm'];
  final List<String> durations = ['30 phút', '60 phút'];

  // --- LOGIC GIỮ NGUYÊN CỦA VŨ ---
  Map<String, String?> _calculateAutoTime() {
    DateTime now = DateTime.now();
    int minutes = selectedDuration == '30 phút' ? 30 : 60;
    DateTime start = now.subtract(Duration(minutes: minutes));

    return {
      'startTime': DateFormat('HH:mm:ss').format(start),
      'endTime': DateFormat('HH:mm:ss').format(now),
      'date': DateFormat('yyyy-MM-dd').format(now),
    };
  }

  // --- PICKER THEME ĐỒNG BỘ MÀU LOGO ---
  Widget _pickerTheme(BuildContext context, Widget child) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: const ColorScheme.light(
          primary: AppColors.primary,
          onPrimary: AppColors.white,
          onSurface: AppColors.textMain,
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: AppColors.primary),
        ),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    String dateText = selectedDate != null
        ? DateFormat('dd/MM/yyyy').format(selectedDate!)
        : "Chọn ngày tháng năm";

    String timeText = (startTime != null && endTime != null)
        ? "${startTime!.format(context)} - ${endTime!.format(context)}"
        : "Chọn khoảng giờ thủ công";

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        // ĐỔI MÀU: Nền loang nhẹ xanh biển sâu cho đồng bộ
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white,
            const Color(0xFFE3F2FD).withOpacity(0.8),
          ],
        ),
        borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30)
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.15),
            blurRadius: 30,
            offset: const Offset(0, -10),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thanh kéo giả (Handle bar) cho đúng chất BottomSheet
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Lọc dữ liệu', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textMain)),
              IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.grey),
                  onPressed: () => Navigator.pop(context)
              ),
            ],
          ),
          const SizedBox(height: 20),

          _sectionLabel('Loại cảm biến'),
          Wrap(spacing: 10, runSpacing: 10, children: types.map((type) => _buildTypeChip(type)).toList()),
          const SizedBox(height: 24),

          _sectionLabel('Lọc nhanh hôm nay'),
          _buildDurationToggle(),
          const SizedBox(height: 24),

          _sectionLabel('Tùy chỉnh thời gian'),
          _buildDropdownField(
            text: dateText,
            icon: Icons.calendar_today_rounded,
            isSelected: selectedDate != null,
            onTap: () => _selectDate(context),
          ),
          const SizedBox(height: 12),
          _buildDropdownField(
            text: timeText,
            icon: Icons.access_time_filled_rounded,
            isSelected: startTime != null && endTime != null,
            onTap: () => _selectTimeRange(context),
          ),
          const SizedBox(height: 35),

          // NÚT TÌM KIẾM ĐỔI MÀU ĐỒNG BỘ
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _handleSearch,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 8,
                shadowColor: AppColors.primary.withOpacity(0.4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              child: const Text('ÁP DỤNG BỘ LỌC', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  // --- WIDGET HỖ TRỢ ĐÃ ĐƯỢC LÀM ĐẸP ---

  Widget _sectionLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 12, left: 4),
    child: Text(label.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.blueGrey.withOpacity(0.7), letterSpacing: 1)),
  );

  Widget _buildTypeChip(String label) {
    bool isActive = selectedType == label;
    return GestureDetector(
      onTap: () => setState(() => selectedType = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: isActive ? AppColors.primary.withOpacity(0.3) : Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
          border: Border.all(color: isActive ? AppColors.primary : Colors.white),
        ),
        child: Text(
            label,
            style: TextStyle(
                color: isActive ? Colors.white : AppColors.textMain,
                fontWeight: FontWeight.bold,
                fontSize: 13
            )
        ),
      ),
    );
  }

  Widget _buildDurationToggle() {
    return Row(
      children: durations.map((duration) {
        bool isActive = selectedDuration == duration;
        return Padding(
          padding: const EdgeInsets.only(right: 12),
          child: GestureDetector(
            onTap: () => setState(() {
              selectedDuration = duration;
              selectedDate = null;
              startTime = null;
              endTime = null;
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                  color: isActive ? AppColors.primary.withOpacity(0.1) : Colors.white,
                  border: Border.all(color: isActive ? AppColors.primary : Colors.white, width: 1.5),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5, offset: const Offset(0, 2))
                  ]
              ),
              child: Text(
                  duration,
                  style: TextStyle(
                      color: isActive ? AppColors.primary : AppColors.textMain,
                      fontWeight: FontWeight.w900
                  )
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDropdownField({required String text, required IconData icon, required bool isSelected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: isSelected ? AppColors.primary.withOpacity(0.5) : Colors.white),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))
            ]
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, color: isSelected ? AppColors.primary : Colors.grey, size: 20),
                const SizedBox(width: 12),
                Text(text, style: TextStyle(color: isSelected ? Colors.black : AppColors.textSecondary, fontSize: 14, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
              ],
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey, size: 14),
          ],
        ),
      ),
    );
  }

  // --- LOGIC HÀM XỬ LÝ (GIỮ NGUYÊN) ---
  void _handleSearch() {
    String? finalDate;
    String? finalStart;
    String? finalEnd;

    if (selectedDuration.isNotEmpty) {
      final autoTime = _calculateAutoTime();
      finalDate = autoTime['date'];
      finalStart = autoTime['startTime'];
      finalEnd = autoTime['endTime'];
    } else {
      finalDate = selectedDate != null ? DateFormat('yyyy-MM-dd').format(selectedDate!) : null;
      finalStart = startTime != null ? "${startTime!.hour.toString().padLeft(2, '0')}:${startTime!.minute.toString().padLeft(2, '0')}:00" : null;
      finalEnd = endTime != null ? "${endTime!.hour.toString().padLeft(2, '0')}:${endTime!.minute.toString().padLeft(2, '0')}:00" : null;
    }

    Navigator.pop(context, {
      'type': selectedType,
      'date': finalDate,
      'startTime': finalStart,
      'endTime': finalEnd,
    });
  }

  // Các hàm Picker giữ nguyên của Vũ...
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) => _pickerTheme(context, child!),
    );
    if (picked != null) {
      setState(() {
        selectedDate = picked;
        selectedDuration = '';
      });
    }
  }

  Future<void> _selectTimeRange(BuildContext context) async {
    final TimeOfDay? pickedStart = await showTimePicker(
      context: context,
      initialTime: startTime ?? TimeOfDay.now(),
      builder: (context, child) => _pickerTheme(context, child!),
    );

    if (pickedStart != null) {
      if (!mounted) return;
      final TimeOfDay? pickedEnd = await showTimePicker(
        context: context,
        initialTime: endTime ?? pickedStart,
        builder: (context, child) => _pickerTheme(context, child!),
      );

      if (pickedEnd != null) {
        setState(() {
          startTime = pickedStart;
          endTime = pickedEnd;
          selectedDuration = '';
        });
      }
    }
  }
}