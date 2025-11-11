// widgets/ProfileInfo.dart
import 'package:chatapp/models/Usermodel.dart';
import 'package:chatapp/widgets/widgetImage.dart';

// import 'package:chatapp/widgets/FullImageView.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/user_status_provider.dart';

class ProfileInfo extends StatelessWidget {
  final UserModel info;

  const ProfileInfo({super.key, required this.info});

  @override
  Widget build(BuildContext context) {
    return // widgets/ProfileInfo.dart
      Scaffold(
        backgroundColor: const Color(0xFFF0F2F5),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(info.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
          centerTitle: true,
        ),
        body: Center(
          child: Column(
            children: [
              const SizedBox(height: 40),
              GestureDetector(
                onTap: () {
                  if (info.profileImages.isNotEmpty) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => FullImageView(imageUrls: info.profileImages, initialIndex: 0)));
                  }
                },
                child: Hero(
                  tag: 'user_${info.uid}',
                  child: CircleAvatar(
                    radius: 90,
                    backgroundImage: info.profileImages.isNotEmpty ? NetworkImage(info.profileImages.first) : null,
                    child: info.profileImages.isEmpty
                        ? Text(info.name[0].toUpperCase(), style: const TextStyle(fontSize: 50, fontWeight: FontWeight.bold))
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              Text(info.name, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text(info.email ?? "Email yo‘q", style: TextStyle(fontSize: 18, color: Colors.grey.shade700)),
              const SizedBox(height: 10),
              Consumer(
                builder: (context, ref, _) {
                  final status = ref.watch(userStatusProvider(info.uid));
                  return status.when(
                    data: (online) => Text(online ? "Online" : "Oxirgi marta ko‘rildi", style: TextStyle(color: online ? Colors.green : Colors.grey)),
                    loading: () => const Text("Yuklanmoqda..."),
                    error: (_, __) => const SizedBox(),
                  );
                },
              ),
            ],
          ),
        ),
      );
  }
}
