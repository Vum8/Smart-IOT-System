import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import '../../core/app_colors.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  // =============================================================
  // CHẾ ĐỘ DEMO:
  // true -> Mở trên Laptop | false -> Mở trên Điện thoại (Như cũ)
  final bool isDemoOnLaptop = true;
  // =============================================================

  Future<void> _handleResourceTap(BuildContext context, String urlString) async {
    if (isDemoOnLaptop) {
      // --- CHẾ ĐỘ 1: GỌI API ĐỂ MỞ TRÊN TRÌNH DUYỆT LAPTOP ---
      final String serverIp = "192.168.85.13"; // Kiểm tra IP Laptop của bạn
      final String apiUrl = "http://$serverIp:3000/api/open-link?url=$urlString";

      try {
        debugPrint("🚀 Đang yêu cầu Laptop mở: $urlString");
        final response = await http.get(Uri.parse(apiUrl)).timeout(const Duration(seconds: 3));

        if (response.statusCode == 200) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('🚀 Đã mở trên trình duyệt Laptop!'),
              backgroundColor: AppColors.primary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        } else {
          throw Exception();
        }
      } catch (e) {
        // Fallback nếu server laptop lỗi hoặc chưa bật
        _openOnMobile(urlString);
      }
    } else {
      // --- CHẾ ĐỘ 2: MỞ TRỰC TIẾP TRÊN ĐIỆN THOẠI ---
      _openOnMobile(urlString);
    }
  }

  Future<void> _openOnMobile(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint("Không thể mở: $urlString");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primary.withOpacity(0.05),
              AppColors.background,
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              _buildMainProfileCard(),
              const SizedBox(height: 32),

              // Tiêu đề phần tài nguyên
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 18,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Tài nguyên phát triển',
                    style: TextStyle(
                      color: AppColors.textMain,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _buildResourceCard(
                icon: Icons.description_outlined,
                iconBg: const Color(0xFFE8F5E9),
                iconColor: const Color(0xFF2E7D32),
                title: 'Báo cáo PDF',
                subtitle: 'Thông tin về sản phẩm',
                onTap: () => _handleResourceTap(context, 'https://vum8.com/report.pdf'),
              ),
              _buildResourceCard(
                icon: Icons.menu_book_rounded,
                iconBg: const Color(0xFFFFEBEE),
                iconColor: const Color(0xFFC62828),
                title: 'Tài liệu API Postman',
                subtitle: 'Kiểm Tra API của ứng dụng',
                onTap: () => _handleResourceTap(context, 'https://web.postman.co/'),
              ),
              _buildResourceCard(
                icon: Icons.code_rounded,
                iconBg: const Color(0xFFF5F5F5),
                iconColor: AppColors.textMain,
                title: 'Kho lưu trữ GitHub',
                subtitle: 'Khám phá mã nguồn',
                onTap: () => _handleResourceTap(context, 'https://github.com/Vum8/IOT.git'),
              ),
              _buildResourceCard(
                icon: Icons.blur_on_rounded,
                iconBg: const Color(0xFFE3F2FD),
                iconColor: AppColors.primary,
                title: 'Thiết kế Figma',
                subtitle: 'Xem UI & UX',
                onTap: () => _handleResourceTap(context, 'https://figma.com'),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainProfileCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          )
        ],
      ),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                ),
                child: const CircleAvatar(
                  radius: 64,
                  backgroundColor: AppColors.white,
                  child: CircleAvatar(
                    radius: 60,
                    backgroundImage: AssetImage("assets/images/avatar_vu.jpg"),
                  ),
                ),
              ),
              // Badge trạng thái "Online"
              Positioned(
                right: 8,
                bottom: 8,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.white, width: 3),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text('Nguyễn Trần Vũ',
              style: TextStyle(color: AppColors.textMain, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
          const SizedBox(height: 6),
          // Mã sinh viên trong khung Chip chuyên nghiệp
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('B22DCPT309 • D22PTDPT01',
                style: TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Divider(color: AppColors.border, thickness: 1.2),
          ),
          const SizedBox(height: 16),
          const Text(
            'Sinh viên ngành Công nghệ đa phương tiện\nHọc viện Công nghệ Bưu chính Viễn thông',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w500, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildResourceCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          highlightColor: AppColors.primary.withOpacity(0.05),
          splashColor: AppColors.primary.withOpacity(0.1),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(icon, color: iconColor, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(color: AppColors.textMain, fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: const TextStyle(color: AppColors.textLight, fontSize: 13)),
                    ],
                  ),
                ),
                // Icon thay đổi theo chế độ Demo
                Icon(
                    isDemoOnLaptop ? Icons.laptop_mac_rounded : Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: AppColors.border
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}