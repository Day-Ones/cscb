import 'package:flutter/material.dart';
import 'organization_page.dart';
import 'profile_page.dart';
import '../data/local/db/app_database.dart';

class MainPage extends StatefulWidget {
  final User user;
  
  const MainPage({super.key, required this.user});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      const HomeScreen(),
      const OrganizationPage(),
      ProfilePage(user: widget.user),
    ];
    
    return Scaffold(
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.business),
            label: 'Organization',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        selectedItemColor: Colors.lightBlue,
      ),
    );
  }
}

// Simple Placeholder for Home
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        backgroundColor: Colors.lightBlue,
        foregroundColor: Colors.white,
      ),
      body: const Center(child: Text("Home")),
    );
  }
}
