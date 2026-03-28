import 'package:flutter/material.dart';
import 'dart:async';

import '../../core/app_colors.dart';
import '../../core/sensor_service.dart';
import '../../models/sensor_record.dart';
import '../../modules/data/data_item_card.dart';
import '../../modules/data/filter_bottom_sheet.dart';

class DataScreen extends StatefulWidget {
  const DataScreen({super.key});

  @override
  State<DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends State<DataScreen> {
  final SensorService _sensorService = SensorService();

  // --- QUẢN LÝ DỮ LIỆU ---
  List<SensorRecord> allRecords = [];
  int currentPage = 1;
  int totalPages = 1;
  bool isLoading = false;
  String searchQuery = "";

  // --- QUẢN LÝ BỘ LỌC (FILTER) ---
  String? filterType;
  String? filterDate;
  String? filterStart;
  String? filterEnd;

  // --- QUẢN LÝ THỜI GIAN (TIMERS) ---
  Timer? _refreshTimer;    // Timer cập nhật tự động 2s
  Timer? _searchDebounce; // Timer hoãn tìm kiếm khi gõ phím

  @override
  void initState() {
    super.initState();
    _fetchData(); // Load lần đầu

    // Tự động cập nhật 2s một lần nếu không bận Tìm kiếm/Lọc
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (currentPage == 1 &&
          searchQuery.isEmpty &&
          filterType == null &&
          filterDate == null &&
          !isLoading) {
        _fetchData();
      }
    });
  }

  // --- HÀM MỚI: VỪA RESET BỘ LỌC, VỪA LOAD LẠI DỮ LIỆU ---
  void _resetAndRefresh() {
    setState(() {
      filterType = null;
      filterDate = null;
      filterStart = null;
      filterEnd = null;
      searchQuery = "";
      currentPage = 1;
    });
    _fetchData();
  }

  // --- HÀM GỌI API VỚI LOGIC LỌC CHÍNH XÁC ---
  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      final result = await _sensorService.fetchRealSensors(
        page: currentPage,
        keyword: searchQuery,
        sensorType: filterType,
        date: filterDate,
        startTime: filterStart,
        endTime: filterEnd,
      );

      setState(() {
        // 1. Nhận dữ liệu thô từ Server
        List<SensorRecord> rawData = result['data'];
        List<SensorRecord> filteredList = [];

        // 2. DUYỆT TỪNG CARD (Nhiệt, Ẩm, Sáng riêng biệt)
        for (var record in rawData) {
          if (filterType != null && filterType != 'Tất cả giá trị' && record.type != filterType) {
            continue;
          }

          // 3. LOGIC SEARCH LIVE TỔNG LỰC
          if (searchQuery.isNotEmpty) {
            final query = searchQuery.toLowerCase().trim();
            String cardContent = "${record.type} ${record.value} ${record.unit} ${record.time}".toLowerCase();

            if (cardContent.contains(query)) {
              filteredList.add(record);
            }
          } else {
            filteredList.add(record);
          }
        }

        allRecords = filteredList;
        totalPages = result['total'];
        isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
      debugPrint("❌ Lỗi Search Live: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container( // Đổ Gradient nền biển sâu
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFD6EDFF),
            AppColors.background,
          ],
          stops: [0.0, 0.4],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent, // Trong suốt để thấy nền biển
        body: Column(
          children: [
            _buildSearchBar(),
            _buildHeader(),
            Expanded(
              child: isLoading && allRecords.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : allRecords.isEmpty
                  ? const Center(child: Text("Không tìm thấy dữ liệu khớp"))
                  : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: allRecords.length,
                itemBuilder: (context, index) => DataItemCard(record: allRecords[index]),
              ),
            ),
            _buildPaginationUI(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // --- 1. THANH TÌM KIẾM (SEARCH LIVE VỚI DEBOUNCE) ---
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
                color: AppColors.primary.withOpacity(0.1),
                blurRadius: 15,
                offset: const Offset(0, 8)
            )
          ],
          border: Border.all(color: Colors.white),
        ),
        child: TextField(
          onChanged: (value) {
            if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
            _searchDebounce = Timer(const Duration(milliseconds: 500), () {
              setState(() {
                searchQuery = value;
                currentPage = 1;
              });
              _fetchData();
            });
          },
          decoration: InputDecoration(
            hintText: 'Tìm kiếm ...',
            hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
            prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
            suffixIcon: IconButton(
              icon: Icon(
                  Icons.tune,
                  color: (filterType != null || filterDate != null) ? AppColors.primary : AppColors.textMain
              ),
              onPressed: _openFilter,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 15),
          ),
        ),
      ),
    );
  }

  // --- 2. TIÊU ĐỀ & NHÃN THÔNG BÁO ---
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Biến động dữ liệu thực',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textMain),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (filterType != null || filterDate != null || searchQuery.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.only(right: 8.0),
                  child: Text(
                    'Xóa lọc',
                    style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
              IconButton(
                onPressed: _resetAndRefresh,
                icon: const Icon(Icons.refresh, color: AppColors.primary),
                padding: const EdgeInsets.all(8.0),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- CÁC HÀM XỬ LÝ PHỤ ---
  Future<void> _openFilter() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const FilterBottomSheet(),
    );

    if (result != null) {
      setState(() {
        filterType = result['type'] == 'Tất cả giá trị' ? null : result['type'];
        filterDate = result['date'];
        filterStart = result['startTime'];
        filterEnd = result['endTime'];
        currentPage = 1;
      });
      _fetchData();
    }
  }

  // --- 3. PHÂN TRANG (PAGINATION) - PHONG CÁCH ĐẢO NỔI ---
  Widget _buildPaginationUI() {
    if (totalPages <= 1) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Nút quay lại
          _buildArrow(Icons.arrow_back_ios_new_rounded, currentPage > 1, () {
            setState(() => currentPage--);
            _fetchData();
          }),

          const SizedBox(width: 12),

          // "Chiếc thuyền" chứa các con số
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20), // Bo tròn cực mạnh
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                )
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: _buildPageNumbers(),
            ),
          ),

          const SizedBox(width: 12),

          // Nút tiến lên
          _buildArrow(Icons.arrow_forward_ios_rounded, currentPage < totalPages, () {
            setState(() => currentPage++);
            _fetchData();
          }),
        ],
      ),
    );
  }

  // --- LOGIC TÍNH TOÁN SỐ TRANG (Để hiển thị dấu ...) ---
  List<Widget> _buildPageNumbers() {
    List<Widget> items = [];

    // Luôn hiện trang đầu (Trang 1)
    items.add(_pageBtn(1));

    // Hiển thị dấu "..." nếu đang ở trang xa trang đầu
    if (currentPage > 3) {
      items.add(const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: Text("...", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
      ));
    }

    // Hiển thị các trang xung quanh trang hiện tại (Trang hiện tại +/- 1)
    for (int i = currentPage - 1; i <= currentPage + 1; i++) {
      if (i > 1 && i < totalPages) {
        items.add(_pageBtn(i));
      }
    }

    // Hiển thị dấu "..." nếu còn xa trang cuối
    if (currentPage < totalPages - 2) {
      items.add(const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: Text("...", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
      ));
    }

    // Luôn hiện trang cuối (Nếu có nhiều hơn 1 trang)
    if (totalPages > 1) {
      items.add(_pageBtn(totalPages));
    }

    return items;
  }

  // --- NÚT SỐ TRANG (HIỆU ỨNG CHUYỂN ĐỘNG) ---
  Widget _pageBtn(int p) {
    bool active = p == currentPage;
    return InkWell(
      onTap: () {
        if (!active) {
          setState(() => currentPage = p);
          _fetchData();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        constraints: const BoxConstraints(minWidth: 38),
        height: 38,
        alignment: Alignment.center,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          // Nếu active thì xanh đậm, không thì trong suốt
          color: active ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: active ? [
            BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 3)
            )
          ] : null,
        ),
        child: Text(
          "$p",
          style: TextStyle(
            color: active ? Colors.white : AppColors.textMain,
            fontSize: 14,
            fontWeight: active ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // --- NÚT MŨI TÊN (ĐỒNG BỘ CARD) ---
  Widget _buildArrow(IconData icon, bool enabled, VoidCallback onTap) {
    return InkWell(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 45,
        height: 45,
        decoration: BoxDecoration(
          color: enabled ? Colors.white : Colors.white.withOpacity(0.4),
          borderRadius: BorderRadius.circular(15),
          boxShadow: enabled ? [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4)
            )
          ] : null,
        ),
        child: Icon(
            icon,
            size: 18,
            color: enabled ? AppColors.primary : Colors.grey.shade300
        ),
      ),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchDebounce?.cancel();
    super.dispose();
  }
}