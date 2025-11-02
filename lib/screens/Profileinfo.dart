import 'package:chatapp/models/Usermodel.dart';
import 'package:chatapp/widgets/widgetImage.dart';
import 'package:flutter/material.dart';


class ProfileInfo extends StatelessWidget {
  final UserModel info;

  const ProfileInfo({super.key, required this.info});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          info.name.isNotEmpty ? info.name : 'User',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () {
                if (info.photoUrl != null && info.photoUrl!.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FullImageView(imageUrl: info.photoUrl!,),
                    ),
                  );
                }
              },
              child: Hero(
                tag: 'profileImage_${info.uid}',
                child: CircleAvatar(
                  radius: 70,
                  backgroundImage: info.photoUrl != null
                      ? NetworkImage(info.photoUrl!)
                      : null,
                  child: info.photoUrl == null
                      ? Text(
                    info.name.isNotEmpty
                        ? info.name[0].toUpperCase()
                        : 'U',
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              info.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              info.email ?? 'No email',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
