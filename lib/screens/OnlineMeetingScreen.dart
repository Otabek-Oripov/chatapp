// lib/screens/video_chat_screen.dart — TO‘LIQ ALMASHTIRING!
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';

class VideoChatScreen extends StatefulWidget {
  const VideoChatScreen({super.key});

  @override
  State<VideoChatScreen> createState() => _VideoChatScreenState();
}

class _VideoChatScreenState extends State<VideoChatScreen> {
  final userID = FirebaseAuth.instance.currentUser!.uid;
  final userName = FirebaseAuth.instance.currentUser!.displayName ?? "User";
  final callID = "omegle_uz_random_2025";

  bool isInQueue = false;
  bool isConnected = false;
  int timerSeconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Timer faqat START bosilganda ishlaydi!
  }

  @override
  void dispose() {
    _timer?.cancel();
    _leaveQueue();
    super.dispose();
  }

  Future<void> _joinQueue() async {
    await FirebaseFirestore.instance.collection('available_users').doc(userID).set({
      'uid': userID,
      'joinedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await FirebaseFirestore.instance.collection('users').doc(userID).update({'isOnline': true});

    // TIMERNI BU YERDA BOSHLAYMIZ!
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (isConnected && mounted) {
        setState(() => timerSeconds++);
      }
    });

    setState(() {
      isInQueue = true;
      isConnected = false;
      timerSeconds = 0;
    });
  }

  Future<void> _leaveQueue() async {
    await FirebaseFirestore.instance.collection('available_users').doc(userID).delete();
    await FirebaseFirestore.instance.collection('users').doc(userID).update({'isOnline': false});
    _timer?.cancel();
    setState(() {
      isInQueue = false;
      isConnected = false;
      timerSeconds = 0;
    });
  }

  void _nextUser() {
    ZegoUIKitPrebuiltCallController().hangUp(context);
    timerSeconds = 0;
    _joinQueue();
  }

  void _stopChat() {
    ZegoUIKitPrebuiltCallController().hangUp(context);
    _leaveQueue();
    // Homescreen ga to‘liq qaytish
    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
  }

  String _formatTime(int seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return "$mins:$secs";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // FULLSCREEN — BOTTOM BAR KO‘RINMAYDI!
      extendBodyBehindAppBar: true,
      extendBody: true,
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.black,

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: _stopChat, // Close bosilganda ham Homescreen ga qaytadi
        ),
      ),

      body: Stack(
        children: [
          // ZEGO VIDEO
          ZegoUIKitPrebuiltCall(
            appID: 448607128,
            appSign: "0078f2d636d85815818a894d1a17c6400ac54cd597daaa77835c7f20e72da0ac",
            userID: userID,
            userName: userName,
            callID: callID,
            config: ZegoUIKitPrebuiltCallConfig.oneOnOneVideoCall()
              ..turnOnCameraWhenJoining = true
              ..turnOnMicrophoneWhenJoining = true
              ..useSpeakerWhenJoining = true,
          ),

          // ONLINE SONI
          Positioned(
            top: 70,
            left: 20,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('available_users').snapshots(),
              builder: (context, snapshot) {
                final count = snapshot.data?.size ?? 0;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.green, width: 2),
                  ),

                );
              },
            ),
          ),

          // START TUGMASI
          if (!isInQueue)
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 22),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                onPressed: _joinQueue,
                child: const Text("START", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),

          // SEARCHING...
          if (isInQueue && !isConnected)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white, strokeWidth: 5),
                  SizedBox(height: 30),
                  Text("Odamlarni qidiryapman...", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
            ),

          // TIMER — FAQAT ULANGANDA KO‘RINADI!
          if (isConnected)
            Positioned(
              top: 70,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: Colors.orange, width: 3),
                ),
                child: Text(
                  _formatTime(timerSeconds),
                  style: const TextStyle(color: Colors.orange, fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ),

          // STOP BUTTON
          if (isConnected)
            Positioned(
              bottom: 100,
              left: 30,
              child: FloatingActionButton(
                heroTag: "stop",
                backgroundColor: Colors.red.shade600,
                elevation: 10,
                onPressed: _stopChat,
                child: const Icon(Icons.stop, size: 45, color: Colors.white),
              ),
            ),

          // NEXT BUTTON
          if (isConnected)
            Positioned(
              bottom: 100,
              right: 30,
              child: FloatingActionButton(
                heroTag: "next",
                backgroundColor: Colors.orange.shade700,
                elevation: 10,
                onPressed: _nextUser,
                child: const Icon(Icons.skip_next, size: 45, color: Colors.white),
              ),
            ),

          // ULANGANLIKNI TEKSHIRISH
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('available_users').doc(userID).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || !isInQueue) return const SizedBox();

              final data = snapshot.data!.data() as Map<String, dynamic>?;
              final joinedAt = data?['joinedAt'] as Timestamp?;

              if (joinedAt != null && !isConnected) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  setState(() => isConnected = true);
                });
              }

              return const SizedBox();
            },
          ),
        ],
      ),
    );
  }
}