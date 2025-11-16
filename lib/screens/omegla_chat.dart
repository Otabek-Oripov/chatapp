// lib/screens/omegle_chat_screen.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';

class OmegleChatScreen extends StatefulWidget {
  const OmegleChatScreen({super.key});

  @override
  State<OmegleChatScreen> createState() => _OmegleChatScreenState();
}

class _OmegleChatScreenState extends State<OmegleChatScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  late String userID;
  late String userName;

  bool isSearching = false;
  bool isConnected = false;
  String? callID;
  String? partnerID;
  int searchDuration = 0;

  StreamSubscription? _waitingSub;
  StreamSubscription? _callSub;
  Timer? _searchTimer;

  @override
  void initState() {
    super.initState();
    final user = _auth.currentUser!;
    userID = user.uid;
    userName = "User_${userID.substring(0, 5)}";
  }

  @override
  void dispose() {
    _leaveQueue();
    _searchTimer?.cancel();
    super.dispose();
  }

  Future<void> _startSearch() async {
    if (isSearching || isConnected) return;
    setState(() {
      isSearching = true;
      searchDuration = 0;
    });

    // Start timer to show search duration
    _searchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => searchDuration++);
    });

    final docRef = _firestore.collection('waiting').doc(userID);
    await docRef.set({
      'uid': userID,
      'timestamp': FieldValue.serverTimestamp(),
    });

    _waitingSub = _firestore
        .collection('waiting')
        .where(FieldPath.documentId, isNotEqualTo: userID)
        .limit(1)
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.docs.isEmpty) return;

      _searchTimer?.cancel();

      final partnerDoc = snapshot.docs.first;
      partnerID = partnerDoc.id;

      final ids = [userID, partnerID!]..sort();
      callID = ids.join('_');

      await _firestore.collection('calls').doc(callID).set({
        'callID': callID,
        'user1': userID,
        'user2': partnerID,
        'active': true,
        'startTime': FieldValue.serverTimestamp(),
      });

      await Future.wait([
        docRef.delete(),
        _firestore.collection('waiting').doc(partnerID).delete(),
      ]);

      setState(() {
        isConnected = true;
        isSearching = false;
      });
    });
  }

  Future<void> _leaveQueue() async {
    _searchTimer?.cancel();
    _waitingSub?.cancel();
    _callSub?.cancel();

    await _firestore.collection('waiting').doc(userID).delete();
    if (callID != null) {
      await _firestore.collection('calls').doc(callID).update({'active': false});
    }

    setState(() {
      isSearching = false;
      isConnected = false;
      callID = null;
      partnerID = null;
      searchDuration = 0;
    });
  }

  void _nextUser() {
    _leaveQueue().then((_) => _startSearch());
  }

  void _stopChat() {
    _leaveQueue();
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0a0e27),
      body: Stack(
        children: [
          // ZEGO CALL
          if (isConnected && callID != null)
            ZegoUIKitPrebuiltCall(
              appID: 448607128,
              appSign:
              "0078f2d636d85815818a894d1a17c6400ac54cd597daaa77835c7f20e72da0ac",
              userID: userID,
              userName: userName,
              callID: callID!,
              config: ZegoUIKitPrebuiltCallConfig.oneOnOneVideoCall()
                ..turnOnCameraWhenJoining = true
                ..turnOnMicrophoneWhenJoining = true
                ..useSpeakerWhenJoining = true,
            ),

          // IDLE STATE - START BUTTON
          if (!isSearching && !isConnected)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF0a0e27),
                    const Color(0xFF1a1f3a),
                  ],
                ),
              ),
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // LOGO/TITLE
                      const Text(
                        "Omegle",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Random Video Chat",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 60),

                      // START BUTTON
                      Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00d4ff), Color(0xFF0099cc)],
                          ),
                          borderRadius: BorderRadius.circular(50),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00d4ff).withOpacity(0.4),
                              blurRadius: 20,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _startSearch,
                            borderRadius: BorderRadius.circular(50),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 60,
                                vertical: 18,
                              ),
                              child: const Text(
                                "START",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),

                      // INFO TEXT
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.1),
                                ),
                              ),
                              child: const Text(
                                "🎥 Connect with random strangers instantly\n"
                                    "🔒 Completely anonymous\n"
                                    "⚡ Crystal clear video & audio",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  height: 1.8,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // SEARCHING STATE
          if (isSearching && !isConnected)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF0a0e27),
                    const Color(0xFF1a1f3a),
                  ],
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ANIMATED SEARCH INDICATOR
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF00d4ff).withOpacity(0.3),
                                width: 2,
                              ),
                            ),
                          ),
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF00d4ff).withOpacity(0.5),
                                width: 2,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 40,
                            height: 40,
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                const Color(0xFF00d4ff),
                              ),
                              strokeWidth: 3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // SEARCHING TEXT
                    const Text(
                      "Connecting to a stranger...",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // TIMER
                    Text(
                      _formatDuration(searchDuration),
                      style: const TextStyle(
                        color: Color(0xFF00d4ff),
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 48),

                    // CANCEL BUTTON
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(
                          color: Colors.red.withOpacity(0.5),
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _stopChat,
                          borderRadius: BorderRadius.circular(50),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 48,
                              vertical: 14,
                            ),
                            child: const Text(
                              "CANCEL",
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // CONNECTED STATE - OVERLAY CONTROLS
          if (isConnected)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.6),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // NEXT BUTTON
                        Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF00d4ff), Color(0xFF0099cc)],
                            ),
                            borderRadius: BorderRadius.circular(50),
                            boxShadow: [
                              BoxShadow(
                                color:
                                const Color(0xFF00d4ff).withOpacity(0.4),
                                blurRadius: 15,
                              ),
                            ],
                          ),
                          width: double.infinity,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _nextUser,
                              borderRadius: BorderRadius.circular(50),
                              child: Padding(
                                padding:
                                const EdgeInsets.symmetric(vertical: 14),
                                child: const Text(
                                  "NEXT",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // DISCONNECT BUTTON
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(50),
                            border: Border.all(
                              color: Colors.red.withOpacity(0.5),
                            ),
                          ),
                          width: double.infinity,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _stopChat,
                              borderRadius: BorderRadius.circular(50),
                              child: Padding(
                                padding:
                                const EdgeInsets.symmetric(vertical: 14),
                                child: const Text(
                                  "DISCONNECT",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}