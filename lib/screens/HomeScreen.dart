import 'package:chatapp/screens/LoginScreen.dart';
import 'package:chatapp/screens/OnlineMeetingScreen.dart';
import 'package:chatapp/screens/chatListScreen.dart';

import 'package:chatapp/screens/profilescreen.dart';
import 'package:chatapp/screens/userListscreen.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

class Homescreen extends StatefulWidget {
  const Homescreen({super.key});

  @override
  State<Homescreen> createState() => _HomescreenState();
}

class _HomescreenState extends State<Homescreen> {
  int selectedIndex = 0;

  final List<Widget> _page = [
    VideoChatScreen(),
    Chatlistscreen(),
    Userlistscreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _page[selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        elevation: 0,
        currentIndex: selectedIndex,
        iconSize: 25,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(
          color: Colors.blue,
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelStyle: const TextStyle(color: Colors.grey),
        onTap: (value) {
          setState(() {
            selectedIndex = value;
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: Icon(selectedIndex == 0 ? Iconsax.video5 : Iconsax.video),
            label: 'video',
          ),
          BottomNavigationBarItem(
            icon: Icon(selectedIndex == 1 ? Icons.chat : Icons.chat_bubble_outline),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(selectedIndex == 2 ? Iconsax.people5 : Iconsax.people),
            label: 'Users',
          ),
          BottomNavigationBarItem(
            icon: Icon(selectedIndex == 3 ? Icons.person:Iconsax.user),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
