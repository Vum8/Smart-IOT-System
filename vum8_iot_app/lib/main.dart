import 'package:flutter/material.dart';
import 'package:vum8_iot_app/modules/profile/profile_screen.dart';
import 'modules/data/data_screen.dart';
import 'modules/home/home_screen.dart';
import 'modules/history/history_screen.dart';
import 'widgets/common/custom_app_bar.dart';
import 'widgets/common/custom_bottom_navigation.dart';
import 'core/app_colors.dart';

void main() => runApp(const SmartHomeApp());

class SmartHomeApp extends StatelessWidget {
  const SmartHomeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.background, // Dùng từ file core
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        useMaterial3: true,
      ),
      home: const MainNavigation(),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const DataScreen(),
    const HistoryScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Gọi Component AppBar riêng
      appBar: CustomAppBar(currentIndex: _selectedIndex),

      body: IndexedStack( // Dùng IndexedStack để giữ trạng thái dữ liệu nhảy liên tục
        index: _selectedIndex,
        children: _screens,
      ),

      // Gọi Component BottomNav riêng
      bottomNavigationBar: CustomBottomNavigation(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
      ),
    );
  }
}