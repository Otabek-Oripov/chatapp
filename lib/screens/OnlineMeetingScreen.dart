import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
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
  StreamSubscription? _callSub;

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
    super.dispose();
  }

  Future<void> _startSearch() async {
    if (isSearching || isConnected) return;
    setState(() => isSearching = true);

    final docRef = _firestore.collection('waiting').doc(userID);
    await docRef.set({
      'uid': userID,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Listen for another user
    _waitingSub = _firestore
        .collection('waiting')
        .where(FieldPath.documentId, isNotEqualTo: userID)
        .limit(1)
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.docs.isEmpty) return;

      final partnerDoc = snapshot.docs.first;
      partnerID = partnerDoc.id;

      // Har doim bir xil callID hosil bo'lishi uchun
      final ids = [userID, partnerID!]..sort();
      callID = ids.join('_');

      await _firestore.collection('calls').doc(callID).set({
        'callID': callID,
        'user1': userID,
        'user2': partnerID,
        'active': true,
      });

      await Future.wait([
        docRef.delete(),
        _firestore.collection('waiting').doc(partnerID).delete(),
      ]);

      setState(() {
        isConnected = true;
        isSearching = false;
      });

      print("CALL STARTED: $callID");
    });
  }

  Future<void> _leaveQueue() async {
    await _firestore.collection('waiting').doc(userID).delete();
    if (callID != null) {
      await _firestore.collection('calls').doc(callID).update({'active': false});
    }
    _waitingSub?.cancel();
    _callSub?.cancel();
    setState(() {
      isSearching = false;
      isConnected = false;
      callID = null;
      partnerID = null;
    });
  }

  void _nextUser() {
    _leaveQueue().then((_) => _startSearch());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ZEGO CALL
          if (isConnected && callID != null)
            ZegoUIKitPrebuiltCall(
              appID: 448607128,
              appSign: "0078f2d636d85815818a894d1a17c6400ac54cd597daaa77835c7f20e72da0ac",
              userID: userID,
              userName: userName,
              callID: callID!,
              config: ZegoUIKitPrebuiltCallConfig.oneOnOneVideoCall()
                ..turnOnCameraWhenJoining = true
                ..turnOnMicrophoneWhenJoining = true
                ..useSpeakerWhenJoining = true
                // ..onHangUp = _nextUser
                // ..onError = (error) => print("ZEGO ERROR: $error"),
            ),

          // START
          if (!isSearching && !isConnected)
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(horizontal: 70, vertical: 24),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(35)),
                ),
                onPressed: _startSearch,
                child: const Text("START", style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),

          // SEARCHING
          if (isSearching && !isConnected)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white, strokeWidth: 5),
                  SizedBox(height: 25),
                  Text("Juftlik qidirilmoqda...", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                ],
              ),
            ),

          // NEXT
          if (isConnected)
            Positioned(
              bottom: 100,
              left: 20,
              right: 20,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                onPressed: _nextUser,
                child: const Text("Keyingi odam", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
    );
  }
}