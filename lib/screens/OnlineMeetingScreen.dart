// lib/screens/video_chat_screen.dart — TO‘LIQ ALMASHTIRING!
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:zego_uikit/zego_uikit.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';

class VideoChatScreen extends StatefulWidget {
  const VideoChatScreen({super.key});

  @override
  State<VideoChatScreen> createState() => _VideoChatScreenState();
}

class _VideoChatScreenState extends State<VideoChatScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  late String userID;
  late String userName;

  bool isSearching = false;
  bool isConnected = false;
  String? callID;
  String? partnerID;

  StreamSubscription? _waitingSub;

  @override
  void initState() {
    super.initState();
    final user = _auth.currentUser!;
    userID = user.uid;
    userName = user.displayName?.isNotEmpty == true
        ? user.displayName!
        : "User_${userID.substring(0, 5)}";
  }

  @override
  void dispose() {
    _leaveQueue();
    super.dispose();
  }

  Future<void> _startSearch() async {
    if (isSearching || isConnected) return;
    setState(() {
      isSearching = true;
      isConnected = false;
    });

    final docRef = _firestore.collection('waiting').doc(userID);
    await docRef.set({
      'uid': userID,
      'name': userName,
      'timestamp': FieldValue.serverTimestamp(),
    });

    _waitingSub = _firestore
        .collection('waiting')
        .where(FieldPath.documentId, isNotEqualTo: userID)
        .limit(1)
        .snapshots()
        .listen((snapshot) async {
          if (snapshot.docs.isEmpty || isConnected) return;

          final partnerDoc = snapshot.docs.first;
          partnerID = partnerDoc.id;
          final partnerName = partnerDoc['name'] ?? "User";

          final ids = [userID, partnerID!]..sort();
          callID = ids.join('_');

          // CALL YARATISH
          await _firestore.collection('calls').doc(callID).set({
            'callID': callID,
            'user1': userID,
            'user2': partnerID,
            'user1_name': userName,
            'user2_name': partnerName,
            'active': true,
            'startedAt': FieldValue.serverTimestamp(),
          });

          // TOZALASH
          await Future.wait([
            docRef.delete(),
            _firestore.collection('waiting').doc(partnerID).delete(),
          ]);

          setState(() => isConnected = true);

          if (mounted) {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (_, __, ___) => CallScreen(
                  callID: callID!,
                  userID: userID,
                  userName: userName,
                  partnerName: partnerName,
                  onNext: _nextUser,
                  onStop: _stopAndBack,
                ),
                transitionsBuilder: (_, a, __, c) =>
                    FadeTransition(opacity: a, child: c),
                transitionDuration: const Duration(milliseconds: 300),
              ),
            );
          }
        });
  }

  Future<void> _leaveQueue() async {
    // Waiting dan chiqish
    await _firestore.collection('waiting').doc(userID).delete();

    // Agar call mavjud bo‘lsa — butunlay o‘chirish!
    if (callID != null) {
      await _firestore.collection('calls').doc(callID).delete();
    }

    _waitingSub?.cancel();
    callID = null;
    partnerID = null;

    if (mounted) {
      setState(() {
        isSearching = false;
        isConnected = false;
      });
    }
  }

  void _nextUser() async {
    await _leaveQueue();
    _startSearch();
  }

  void _stopAndBack() async {
    await _leaveQueue();
    if (mounted) {
      Navigator.popUntil(context, (route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (!isSearching && !isConnected)
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 60,
                    vertical: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(40),
                  ),
                ),
                onPressed: _startSearch,
                child: const Text(
                  "START",
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

          if (isSearching && !isConnected)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 6,
                  ),
                  SizedBox(height: 30),
                  Text(
                    "Juftlik qidirilmoqda...",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// CALL SCREEN — STATEFUL + ISMI CHIROYLI + STOP TO‘G‘RI ISHLAYDI
class CallScreen extends StatefulWidget {
  final String callID;
  final String userID;
  final String userName;
  final String partnerName;
  final VoidCallback onNext;
  final VoidCallback onStop;

  const CallScreen({
    super.key,
    required this.callID,
    required this.userID,
    required this.userName,
    required this.partnerName,
    required this.onNext,
    required this.onStop,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  bool isMicOn = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          ZegoUIKitPrebuiltCall(
            appID: 448607128,
            appSign:
                "0078f2d636d85815818a894d1a17c6400ac54cd597daaa77835c7f20e72da0ac",
            userID: widget.userID,
            userName: widget.userName,
            callID: widget.callID,
            config: ZegoUIKitPrebuiltCallConfig.oneOnOneVideoCall()
              ..turnOnCameraWhenJoining = true
              ..turnOnMicrophoneWhenJoining = true
              ..useSpeakerWhenJoining = true
              ..topMenuBarConfig = ZegoTopMenuBarConfig(isVisible: false)
              ..bottomMenuBarConfig = ZegoBottomMenuBarConfig(isVisible: false),
          ),

          // PARTNER ISMI
          Positioned(
            top: 60,
            left: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                widget.partnerName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // BUTTONLAR — ROWDA, 70x70
          Positioned(
            bottom: 180,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // MIKROFON
                GestureDetector(
                  onTap: () {
                    setState(() => isMicOn = !isMicOn);
                    ZegoUIKit().turnMicrophoneOn(isMicOn);
                  },
                  child: Container(
                    height: 70,
                    width: 70,
                    decoration: BoxDecoration(
                      color: isMicOn
                          ? Colors.green.shade600
                          : Colors.red.shade700,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: isMicOn
                              ? Colors.green.withOpacity(0.6)
                              : Colors.red.withOpacity(0.6),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Icon(
                      isMicOn ? Icons.mic : Icons.mic_off,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ),

                // NEXT
                GestureDetector(
                  onTap: widget.onNext,
                  child: Container(
                    height: 70,
                    width: 70,
                    decoration: BoxDecoration(
                      color: Colors.orange.shade700,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withOpacity(0.6),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.skip_next,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),

                // STOP
                GestureDetector(
                  onTap: widget.onStop,
                  child: Container(
                    height: 70,
                    width: 70,
                    decoration: BoxDecoration(
                      color: Colors.red.shade600,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.6),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.stop,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
