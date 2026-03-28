import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/app_colors.dart';

class HistoryFilterScreen extends StatefulWidget {
  final Map<String, String> currentFilter;
  const HistoryFilterScreen({super.key, required this.currentFilter});

  @override
  State<HistoryFilterScreen> createState() => _HistoryFilterScreenState();
}

class _HistoryFilterScreenState extends State<HistoryFilterScreen> {
  late DateTime _selectedDate;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late String _selectedDevice;
  late String _selectedStatus;
  bool _onlyShowErrors = false; // BIẾN MỚI: Chỉ hiện lỗi

  final List<String> _devices = ['Tất cả', 'Quạt thông gió', 'Đèn chiếu sáng', 'Máy tạo ẩm'];
  final List<String> _statuses = ['Tất cả', 'Chỉ BẬT', 'Chỉ TẮT'];

  @override
  void initState() {
    super.initState();
    _loadInitialFilters();
  }

  void _loadInitialFilters() {
    _selectedDevice = widget.currentFilter['device'] ?? 'Tất cả';
    _selectedStatus = widget.currentFilter['statusFilter'] ?? 'Tất cả';
    _onlyShowErrors = widget.currentFilter['onlyErrors'] == 'true';

    // Khôi phục Ngày
    if (widget.currentFilter['date']?.isNotEmpty ?? false) {
      try {
        _selectedDate = DateFormat('yyyy-MM-dd').parse(widget.currentFilter['date']!);
      } catch (e) { _selectedDate = DateTime.now(); }
    } else { _selectedDate = DateTime.now(); }

    // Khôi phục Giờ
    _startTime = _parseTime(widget.currentFilter['startTime'], const TimeOfDay(hour: 0, minute: 0));
    _endTime = _parseTime(widget.currentFilter['endTime'], const TimeOfDay(hour: 23, minute: 59));
  }

  TimeOfDay _parseTime(String? timeStr, TimeOfDay defaultTime) {
    if (timeStr == null || !timeStr.contains(':')) return defaultTime;
    List<String> parts = timeStr.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFD6EDFF), AppColors.background],
          stops: [0.0, 0.3],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Bộ lọc chuyên sâu',
              style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
              icon: const Icon(Icons.close_rounded, color: AppColors.textMain),
              onPressed: () => Navigator.pop(context)
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('1. Thời gian tra cứu'),
              const SizedBox(height: 12),
              _buildPickerBox(
                  DateFormat('dd/MM/yyyy').format(_selectedDate),
                  Icons.calendar_month_rounded,
                      () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2025),
                      lastDate: DateTime.now(),
                      builder: (context, child) => _buildPickerTheme(child!),
                    );
                    if (d != null) setState(() => _selectedDate = d);
                  }
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildPickerBox(_startTime.format(context), Icons.access_time_filled_rounded, () => _pickTime(true))),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.blueGrey),
                  ),
                  Expanded(child: _buildPickerBox(_endTime.format(context), Icons.access_time_filled_rounded, () => _pickTime(false))),
                ],
              ),
              const SizedBox(height: 25),

              _sectionTitle('2. Lọc theo thiết bị'),
              const SizedBox(height: 12),
              Wrap(
                  spacing: 10, runSpacing: 10,
                  children: _devices.map((e) => _customChip(e, _selectedDevice == e, () => setState(() => _selectedDevice = e))).toList()
              ),
              const SizedBox(height: 25),

              _sectionTitle('3. Trạng thái hoạt động'),
              const SizedBox(height: 12),
              Wrap(
                  spacing: 10, runSpacing: 10,
                  children: _statuses.map((e) => _customChip(e, _selectedStatus == e, () => setState(() => _selectedStatus = e))).toList()
              ),
              const SizedBox(height: 25),

              // SECTION MỚI: CHỈ HIỂN THỊ LỖI
              _sectionTitle('4. Tùy chọn nâng cao'),
              const SizedBox(height: 12),
              _buildErrorSwitch(),

              const SizedBox(height: 40),
              _buildSubmitButton(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(left: 4),
    child: Text(title.toUpperCase(),
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.blueGrey.withOpacity(0.8), letterSpacing: 1)),
  );

  Widget _buildPickerBox(String text, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(color: AppColors.primary.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
            ]
        ),
        child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(text, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMain)),
              Icon(icon, size: 20, color: AppColors.primary)
            ]
        ),
      ),
    );
  }

  Widget _customChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
                color: isSelected ? AppColors.primary.withOpacity(0.3) : Colors.black.withOpacity(0.03),
                blurRadius: 8, offset: const Offset(0, 4)
            )
          ],
        ),
        child: Text(label,
            style: TextStyle(color: isSelected ? Colors.white : AppColors.textMain, fontWeight: FontWeight.bold, fontSize: 13)),
      ),
    );
  }

  Widget _buildErrorSwitch() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _onlyShowErrors ? Colors.orange.withOpacity(0.1) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _onlyShowErrors ? Colors.orange : Colors.white, width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.report_problem_rounded, color: _onlyShowErrors ? Colors.orange : Colors.grey),
              const SizedBox(width: 12),
              const Text('Chỉ hiển thị hành động lỗi', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          Switch(
            value: _onlyShowErrors,
            activeColor: Colors.orange,
            onChanged: (val) => setState(() => _onlyShowErrors = val),
          )
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))
          ]
      ),
      child: ElevatedButton(
        onPressed: () {
          String formatTime(TimeOfDay t) => "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00";
          Navigator.pop(context, {
            'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
            'startTime': formatTime(_startTime),
            'endTime': formatTime(_endTime),
            'device': _selectedDevice,
            'statusFilter': _selectedStatus,
            'onlyErrors': _onlyShowErrors ? 'true' : 'false',
          });
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: 0,
        ),
        child: const Text('ÁP DỤNG BỘ LỌC', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1)),
      ),
    );
  }

  Widget _buildPickerTheme(Widget child) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: const ColorScheme.light(primary: AppColors.primary, onPrimary: Colors.white, onSurface: AppColors.textMain),
      ),
      child: child,
    );
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(context: context, initialTime: isStart ? _startTime : _endTime);
    if (picked != null) setState(() { if (isStart) _startTime = picked; else _endTime = picked; });
  }
}