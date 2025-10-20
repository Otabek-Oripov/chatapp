import 'package:chatapp/models/Usermodel.dart';
import 'package:chatapp/widgets/user_chat_profil.dart';
import 'package:chatapp/widgets/video_call_button.dart';
import 'package:flutter/material.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final UserModel othersUser;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.othersUser,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        forceMaterialTransparency: true,
        backgroundColor: Colors.white,
        elevation: 0,
        title: UserChatProfil(user: widget.othersUser),
        actions: [
          actionButton(false, widget.othersUser.uid, widget.othersUser.name) ,
          actionButton(true, widget.othersUser.uid, widget.othersUser.name) ,
        ],
      ),
      body: const Center(
        child: Text("Chat content goes here"),
      ),
    );
  }
}
