import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../../core/app_colors.dart';
import '../../models/action_log.dart';
import 'history_filter_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchKeyword = "";
  Timer? _debounce;

  List<ActionLog> _allLogs = [];
  bool _isLoading = false;

  // BIẾN QUẢN LÝ PHÂN TRANG (GIỮ NGUYÊN)
  int _currentPage = 1;
  int _totalPages = 1;

  IO.Socket? _socket;
  Map<String, bool> _devicePowerStates = {
    "Đèn chiếu sáng": false, "Quạt thông gió": false, "Máy tạo ẩm": false,
  };
  Map<String, String> _filterQuery = {};

  @override
  void initState() {
    super.initState();
    _initSocket();
    _fetchPage(1); // Mặc định gọi trang 1 khi khởi động
  }

  // --- LOGIC SOCKET (GIỮ NGUYÊN) ---
  void _initSocket() {
    _socket = IO.io('http://10.0.2.2:3000', IO.OptionBuilder()
        .setTransports(['websocket'])
        .enableAutoConnect()
        .build());

    _socket!.on('device_status_ack', (data) {
      if (mounted) {
        String deviceName = _getDeviceName(data['device']);
        String rawStatus = data['status']?.toString().toUpperCase() ?? "OFF";
        bool isFail = rawStatus == "FAIL" || rawStatus == "ERROR";

        setState(() {
          if (!isFail) {
            bool isOn = rawStatus == "ON";
            _devicePowerStates = Map.from(_devicePowerStates);
            _devicePowerStates[deviceName] = isOn;
          }
        });

        if (_filterQuery.isEmpty && _searchKeyword.isEmpty) {
          _fetchPage(1);
        } else {
          // Nếu đang search, vẫn phải giữ keyword khi fetch lại
          _fetchPage(1);
        }
      }
    });
  }

  String _getDeviceName(String key) {
    if (key == 'light') return "Đèn chiếu sáng";
    if (key == 'temp' || key == 'fan') return "Quạt thông gió";
    return "Máy tạo ẩm";
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _socket?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // --- LOGIC FETCH API (GIỮ NGUYÊN) ---
  Future<void> _fetchPage(int page) async {
    setState(() {
      _isLoading = true;
      _currentPage = page;
      _allLogs = [];
    });

    try {
      String url = 'http://10.0.2.2:3000/api/history?page=$_currentPage';

      if (_filterQuery.isNotEmpty) {
        _filterQuery.forEach((key, value) {
          if (value.isNotEmpty) {
            String apiValue = value;
            if (key == 'statusFilter') {
              apiValue = value == 'Chỉ BẬT' ? 'on' : 'off';
            }
            url += '&$key=${Uri.encodeComponent(apiValue)}';
          }
        });
      }

      if (_searchKeyword.isNotEmpty) {
        url += '&keyword=${Uri.encodeComponent(_searchKeyword)}';
      }

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final Map<String, dynamic> result = json.decode(response.body);
        final List<dynamic> data = result['data'];
        if (mounted) {
          setState(() {
            _totalPages = result['totalPages'] ?? 1;
            _allLogs = data.map((item) => ActionLog.fromJson(item, AppColors.primary)).toList();
          });
        }
      }
    } catch (e) {
      debugPrint("❌ Lỗi fetch: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openFilter() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => HistoryFilterScreen(currentFilter: _filterQuery)),
    );
    if (result != null && result is Map<String, dynamic>) {
      _filterQuery = {
        'device': result['device'],
        'date': result['date'],
        'startTime': result['startTime'],
        'endTime': result['endTime'],
        'statusFilter': result['statusFilter'],
        'onlyErrors': result['onlyErrors'], // THÊM DÒNG NÀY
      };
      _fetchPage(1);
    }
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() => _searchKeyword = value);
      _fetchPage(1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        // ĐỒNG BỘ BIỂN NƯỚC SÂU (GIỐNG TRANG HOME)
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
        backgroundColor: Colors.transparent, // Trong suốt để lộ nền biển
        body: Column(
          children: [
            _buildSearchAndFilterSection(),
            _buildActiveDevicesSection(),

            // Header tiêu đề
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Lịch sử hoạt động',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textMain)),
                  GestureDetector(
                    onTap: () {
                      _filterQuery = {};
                      _searchController.clear();
                      _searchKeyword = "";
                      _fetchPage(1);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('Xem tất cả',
                          style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _allLogs.isEmpty
                  ? const Center(child: Text("Không có dữ liệu lịch sử phù hợp"))
                  : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                itemCount: _allLogs.length,
                itemBuilder: (context, index) => _buildLogItem(_allLogs[index]),
              ),
            ),

            if (!_isLoading) _buildPaginationUI(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // --- 1. SEARCH & FILTER (ĐỒNG BỘ DATA SCREEN) ---
  Widget _buildSearchAndFilterSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 50, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.primary.withOpacity(0.08), // Shadow xanh nhẹ
                      blurRadius: 15,
                      offset: const Offset(0, 8)
                  )
                ],
                border: Border.all(color: Colors.white), // Viền trắng sang trọng
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  icon: const Icon(Icons.search, color: Colors.grey),
                  hintText: 'Tìm kiếm hoạt động...',
                  hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.grey, size: 20),
                    onPressed: () {
                      _searchController.clear();
                      _onSearchChanged("");
                    },
                  ) : null,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
              onTap: _openFilter,
              child: Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                      color: _filterQuery.isEmpty ? AppColors.primary : Colors.orange,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                            color: (_filterQuery.isEmpty ? AppColors.primary : Colors.orange).withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4)
                        )
                      ]
                  ),
                  child: const Icon(Icons.tune_rounded, color: Colors.white)
              )
          ),
        ],
      ),
    );
  }

  // --- 2. THIẾT BỊ HOẠT ĐỘNG (NHƯ NHỮNG CHIẾC PHAO NỔI) ---
  Widget _buildActiveDevicesSection() {
    List<String> activeNames = _devicePowerStates.entries
        .where((e) => e.value == true)
        .map((e) => e.key)
        .toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Thiết bị đang chạy',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          const SizedBox(height: 12),
          activeNames.isEmpty
              ? Text("Tất cả thiết bị đang nghỉ ngơi 💤",
              style: TextStyle(color: Colors.blueGrey.withOpacity(0.5), fontSize: 13))
              : Wrap(spacing: 10, runSpacing: 10, children: activeNames.map((name) => _buildDeviceChip(name)).toList()),
        ],
      ),
    );
  }

  Widget _buildDeviceChip(String name) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(color: Colors.green.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))
          ]
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt, size: 14, color: Colors.green),
          const SizedBox(width: 6),
          Text(name, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  // --- 3. LOG ITEM (BẢN CHUẨN: PHÂN BIỆT MÀU ON/OFF KỂ CẢ KHI THẤT BẠI) ---
  Widget _buildLogItem(ActionLog log) {
    bool isFail = log.isFail;
    bool isOn = log.valueText == "Turn On";

    // 1. MÀU NHẬN DIỆN HÀNH ĐỘNG (Dùng cho Card, Icon và Nhãn)
    // ON = Xanh lá (Bản Vũ ưng) | OFF = Đỏ/Hồng (Bản Vũ ưng)
    Color actionColor = isOn ? Colors.green : Colors.redAccent;

    // Nếu thất bại, ta dùng tông Cam đậm để cảnh báo nhưng vẫn giữ base màu của hành động
    Color displayColor = isFail ? Colors.orange.shade800 : actionColor;

    // 2. MÀU TRẠNG THÁI (SUCCESS/FAIL)
    // Thành công luôn Xanh lá | Thất bại luôn Cam/Đỏ
    Color statusTextColor = isFail ? Colors.orange.shade900 : Colors.green;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          // Nền loang nhẹ theo màu hành động (Xanh/Đỏ)
          colors: [Colors.white, displayColor.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: displayColor.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4)
          )
        ],
        border: Border.all(color: displayColor.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          // Icon mang màu của hành động (Bật = Xanh, Tắt = Đỏ)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: displayColor.withOpacity(0.1),
                shape: BoxShape.circle
            ),
            child: Icon(
                isFail ? Icons.warning_amber_rounded : (isOn ? Icons.power_rounded : Icons.power_off_rounded),
                color: displayColor,
                size: 24
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(log.title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textMain)),
                    const SizedBox(height: 4),
                    Text("${log.date} | ${log.time}",
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))
                  ]
              )
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // NHÃN HÀNH ĐỘNG: Giúp Vũ biết đang BẬT hay TẮT kể cả khi lỗi
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: displayColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8)
                ),
                child: Text(
                    log.valueText.toUpperCase(),
                    style: TextStyle(color: displayColor, fontWeight: FontWeight.w900, fontSize: 10)
                ),
              ),
              const SizedBox(height: 6),
              // DÒNG TRẠNG THÁI: Đúng tinh thần Thành công = Xanh lá
              Text(
                  isFail ? "THẤT BẠI" : "THÀNH CÔNG",
                  style: TextStyle(
                      color: statusTextColor,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5
                  )
              ),
            ],
          )
        ],
      ),
    );
  }

  // --- 4. PHÂN TRANG (ĐỒNG BỘ ĐẢO NỔI) ---
  Widget _buildPaginationUI() {
    if (_totalPages <= 1) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Nút quay lại kiểu mới
        _buildArrow(Icons.arrow_back_ios_new_rounded, _currentPage > 1,
                () => _fetchPage(_currentPage - 1)),
        const SizedBox(width: 12),

        // "Chiếc thuyền" chứa số trang bo tròn mạnh
        Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: AppColors.primary.withOpacity(0.1), // Shadow xanh thương hiệu
                    blurRadius: 15,
                    offset: const Offset(0, 5)
                )
              ]
          ),
          child: Row(children: _buildPageNumbers()),
        ),

        const SizedBox(width: 12),

        // Nút tiến lên kiểu mới
        _buildArrow(Icons.arrow_forward_ios_rounded, _currentPage < _totalPages,
                () => _fetchPage(_currentPage + 1)),
      ],
    );
  }

  // --- LOGIC TÍNH TOÁN SỐ TRANG (GIỮ NGUYÊN) ---
  List<Widget> _buildPageNumbers() {
    List<Widget> items = [];
    // Hiển thị 4 trang đầu hoặc ít hơn nếu tổng số trang nhỏ hơn 4
    for (int i = 1; i <= (_totalPages > 4 ? 4 : _totalPages); i++) {
      items.add(_pageBtn(i));
    }
    // Hiển thị dấu ... và trang cuối nếu tổng số trang lớn hơn 5
    if (_totalPages > 5) {
      items.add(const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text("...", style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold))
      ));
      items.add(_pageBtn(_totalPages));
    }
    return items;
  }

  // --- NÚT SỐ TRANG (ĐÃ ĐƯỢC LÀM MƯỢT) ---
  Widget _pageBtn(int p) {
    bool active = p == _currentPage;
    return InkWell(
      onTap: () => _fetchPage(p),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 35, height: 35, alignment: Alignment.center,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10), // Bo tròn nhẹ
          boxShadow: active ? [
            BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 3)
            )
          ] : null,
        ),
        child: Text("$p",
            style: TextStyle(
                color: active ? Colors.white : Colors.black,
                fontSize: 13,
                fontWeight: active ? FontWeight.bold : FontWeight.normal
            )
        ),
      ),
    );
  }

  // Nút mũi tên đồng bộ UI Card
  Widget _buildArrow(IconData icon, bool enabled, VoidCallback onTap) {
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 45, height: 45,
        decoration: BoxDecoration(
          color: enabled ? Colors.white : Colors.white.withOpacity(0.5),
          borderRadius: BorderRadius.circular(15), // Bo góc 15 khớp Card
          boxShadow: enabled ? [
            BoxShadow(
                color: Colors.black.withOpacity(0.05), // Shadow rất nhẹ
                blurRadius: 10
            )
          ] : null,
        ),
        child: Icon(icon, size: 18, color: enabled ? AppColors.primary : Colors.grey.shade300),
      ),
    );
  }
}