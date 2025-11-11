import 'package:chatapp/screens/chatListScreen.dart';
import "package:chatapp/screens/userListscreen.dart";
import 'package:chatapp/screens/profilescreen.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import 'OnlineMeetingScreen.dart';

class Homescreen extends StatefulWidget {
  const Homescreen({super.key});
  @override
  State<Homescreen> createState() => _HomescreenState();
}

class _HomescreenState extends State<Homescreen> {
  int selectedIndex = 0;

  final List<Widget> _pages = const [
    VideoChatScreen(),
    Chatlistscreen(),
    Userlistscreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: _pages[selectedIndex],
      bottomNavigationBar: Container(
        padding: EdgeInsets.all(0),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6a11cb), Color(0xFF2575fc)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(35),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 25,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(35),
          child: BottomNavigationBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            currentIndex: selectedIndex,
            selectedItemColor: Colors.white,
            unselectedItemColor: Colors.white70,
            type: BottomNavigationBarType.fixed,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            unselectedLabelStyle: const TextStyle(fontSize: 11),
            onTap: (i) => setState(() => selectedIndex = i),
            items: [
              _navItem(Iconsax.video, Iconsax.video5, "Video"),
              _navItem(Iconsax.message, Iconsax.message5, "Chat"),
              _navItem(Iconsax.people, Iconsax.people5, "Users"),
              _navItem(Iconsax.user, Icons.person, "Profil"),
            ],
          ),
        ),
      ),
    );
  }

  BottomNavigationBarItem _navItem(IconData icon, IconData activeIcon, String label) {
    return BottomNavigationBarItem(
      icon: Icon(icon, size: 26),
      activeIcon: Icon(activeIcon, size: 30),
      label: label,
    );
  }
}