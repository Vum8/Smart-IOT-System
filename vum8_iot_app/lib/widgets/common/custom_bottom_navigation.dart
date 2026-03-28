import 'package:flutter/material.dart';

class CustomBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      selectedItemColor: Colors.blue,
      unselectedItemColor: Colors.grey,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: "Trang chủ"),
        BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: "Dữ liệu"),
        BottomNavigationBarItem(icon: Icon(Icons.history), label: "Lịch sử"),
        BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: "Profile"),
      ],
    );
  }
}