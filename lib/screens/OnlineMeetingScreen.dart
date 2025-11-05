// lib/screens/video_chat_screen.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import '../function/snakbar.dart';
import '../models/Usermodel.dart';

class VideoChatScreen extends StatefulWidget {
  @override
  _VideoChatScreenState createState() => _VideoChatScreenState();
}

class _VideoChatScreenState extends State<VideoChatScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _currentUserId = FirebaseAuth.instance.currentUser!.uid;

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  bool _inCall = false;
  bool _isMuted = false;
  bool _isVideoOff = false;
  String? _roomId;
  String? _partnerId;
  UserModel? _partner;

  StreamSubscription? _roomListener;
  StreamSubscription? _candidatesListener;

  @override
  void initState() {
    super.initState();
    _initRenderers();
    _checkAndRequestPermissions();
    _setOnlineStatus(true);
  }

  // === 1. RENDERER ===
  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  // === 2. RUXSAT ===
  Future<bool> _requestPermissions() async {
    final statuses = await [Permission.camera, Permission.microphone].request();
    return statuses[Permission.camera]?.isGranted == true &&
        statuses[Permission.microphone]?.isGranted == true;
  }

  Future<void> _checkAndRequestPermissions() async {
    final granted = await _requestPermissions();
    if (!granted && mounted) {
      showAppSnackbar(
        context: context,
        type: SnackbarType.error,
        description: "Ruxsat berilmadi. Video chat ishlamaydi.",
      );
    }
  }

  // === 3. ONLINE STATUS ===
  Future<void> _setOnlineStatus(bool online) async {
    await _firestore.collection('users').doc(_currentUserId).update({
      'isOnline': online,
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }

  // === 4. RANDOM CHAT BOSHLASH (Index bilan) ===
  Future<void> _startRandomChat() async {
    if (!mounted) return;

    try {
      // Composite Index ishlatiladi: isOnline + uid
      final snapshot = await _firestore
          .collection('users')
          .where('isOnline', isEqualTo: true)
          .where('uid', isNotEqualTo: _currentUserId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        _showWaitingDialog();
        return;
      }

      final partnerDoc = snapshot.docs.first;
      final partnerData = partnerDoc.data() as Map<String, dynamic>;
      _partner = UserModel.fromMap(partnerData);
      _partnerId = _partner!.uid;
      _roomId = const Uuid().v4().substring(0, 8);

      // === ROOMS YARATISH (UserModel bilan) ===
      await _firestore.collection('rooms').doc(_roomId).set({
        'roomId': _roomId,
        'users': [_currentUserId, _partnerId],
        'createdAt': FieldValue.serverTimestamp(),
        'active': true,
        'initiator': _currentUserId,
        'partner': {
          'uid': _partner!.uid,
          'name': _partner!.name,
          'photoUrl': _partner!.photoUrl,
          'profileImages': _partner!.profileImages,
        },
      });

      // WebRTC boshlash
      await _createPeerConnection();
      await _createAndSendOffer();
      _listenToRoom();
    } catch (e) {
      print("Match topishda xato: $e");
      showAppSnackbar(
        context: context,
        type: SnackbarType.error,
        description: "Foydalanuvchi topilmadi. Qayta urining.",
      );
    }
  }

  // === 5. PEER CONNECTION ===
  Future<void> _createPeerConnection() async {
    _peerConnection = await createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ],
    });

    _localStream = await navigator.mediaDevices.getUserMedia({
      'video': true,
      'audio': true,
    });

    _localStream!.getTracks().forEach((track) {
      _peerConnection!.addTrack(track, _localStream!);
    });

    _localRenderer.srcObject = _localStream;

    _peerConnection!.onIceCandidate = (candidate) {
      if (_roomId == null) return;
      _firestore.collection('rooms').doc(_roomId).collection('candidates').add({
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
        'sender': _currentUserId,
      });
    };

    _peerConnection!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteRenderer.srcObject = event.streams[0];
        if (mounted) setState(() => _inCall = true);
      }
    };
  }

  // === 6. OFFER ===
  Future<void> _createAndSendOffer() async {
    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);

    await _firestore.collection('rooms').doc(_roomId).update({
      'offer': {'sdp': offer.sdp, 'type': offer.type},
      'offerBy': _currentUserId,
    });
  }

  // === 7. ROOM TINGLASH ===
  void _listenToRoom() {
    if (_roomId == null) return;

    _roomListener = _firestore.collection('rooms').doc(_roomId).snapshots().listen((doc) async {
      final data = doc.data();
      if (data == null) return;

      // Partner ma'lumotlari
      if (data['partner'] != null && data['initiator'] != _currentUserId) {
        final partnerMap = data['partner'] as Map<String, dynamic>;
        _partner = UserModel.fromMap(partnerMap);
        if (mounted) setState(() {});
      }

      // Offer keldi
      if (data['offer'] != null && data['offerBy'] != _currentUserId) {
        await _handleOffer(data['offer'] as Map<String, dynamic>);
      }

      // Answer keldi
      if (data['answer'] != null && data['answerBy'] != _currentUserId) {
        final answer = data['answer'] as Map<String, dynamic>;
        await _peerConnection?.setRemoteDescription(
          RTCSessionDescription(answer['sdp'] as String, answer['type'] as String),
        );
      }

      if (mounted) setState(() => _inCall = true);
    });

    // ICE Candidates
    _candidatesListener = _firestore
        .collection('rooms')
        .doc(_roomId)
        .collection('candidates')
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data != null && data['sender'] != _currentUserId) {
            final candidate = RTCIceCandidate(
              data['candidate'] as String,
              data['sdpMid'] as String?,
              data['sdpMLineIndex'] as int?,
            );
            _peerConnection?.addCandidate(candidate);
          }
        }
      }
    });
  }

  // === 8. OFFER QABUL QILISH ===
  Future<void> _handleOffer(Map<String, dynamic> offer) async {
    await _peerConnection!.setRemoteDescription(
      RTCSessionDescription(offer['sdp'] as String, offer['type'] as String),
    );

    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);

    await _firestore.collection('rooms').doc(_roomId).update({
      'answer': {'sdp': answer.sdp, 'type': answer.type},
      'answerBy': _currentUserId,
    });
  }

  // === 9. NEXT ===
  void _nextUser() async {
    await _endCall();
    if (mounted) _startRandomChat();
  }

  // === 10. CALL TUGATISH ===
  Future<void> _endCall() async {
    _localStream?.getTracks().forEach((track) => track.stop());
    await _peerConnection?.close();
    _peerConnection = null;

    if (_roomId != null) {
      await _firestore.collection('rooms').doc(_roomId).delete();
    }

    _roomListener?.cancel();
    _candidatesListener?.cancel();

    if (mounted) {
      setState(() {
        _inCall = false;
        _roomId = null;
        _partnerId = null;
        _partner = null;
      });
    }
  }

  // === 11. KUTISH DIALOGI ===
  void _showWaitingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.black87,
        content: Row(
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(width: 20),
            Text("Online foydalanuvchi topilmoqda...", style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );

    Future.delayed(Duration(seconds: 30), () {
      if (mounted && !_inCall) {
        Navigator.pop(context);
        showAppSnackbar(
          context: context,
          type: SnackbarType.info,
          description: "Online foydalanuvchi topilmadi. Qayta urining.",
        );
      }
    });
  }

  // === UI ===
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: _inCall
            ? Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundImage: _partner?.photoUrl != null
                  ? NetworkImage(_partner!.photoUrl!)
                  : null,
              child: _partner?.photoUrl == null ? Icon(Icons.person, size: 16) : null,
            ),
            SizedBox(width: 8),
            Text(_partner?.name ?? "Stranger", style: TextStyle(color: Colors.white)),
          ],
        )
            : Text("Random Video Chat", style: TextStyle(color: Colors.white)),
        actions: [
          if (_inCall)
            IconButton(icon: Icon(Icons.call_end, color: Colors.red), onPressed: _endCall),
        ],
      ),
      body: Stack(
        children: [
          // Remote Video
          if (_inCall && _remoteRenderer.srcObject != null)
            RTCVideoView(_remoteRenderer, mirror: false, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),

          // Local Video
          if (_inCall)
            Positioned(
              top: 80,
              right: 20,
              width: 120,
              height: 160,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: RTCVideoView(_localRenderer, mirror: true),
              ),
            ),

          // Controls
          if (_inCall)
            Positioned(
              bottom: 50,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _controlButton(
                    icon: _isMuted ? Icons.mic_off : Icons.mic,
                    onPressed: () {
                      _isMuted = !_isMuted;
                      _localStream?.getAudioTracks().forEach((t) => t.enabled = !_isMuted);
                      setState(() {});
                    },
                  ),
                  _controlButton(
                    icon: Icons.refresh,
                    color: Colors.blue,
                    onPressed: _nextUser,
                  ),
                  _controlButton(
                    icon: _isVideoOff ? Icons.videocam_off : Icons.videocam,
                    onPressed: () {
                      _isVideoOff = !_isVideoOff;
                      _localStream?.getVideoTracks().forEach((t) => t.enabled = !_isVideoOff);
                      setState(() {});
                    },
                  ),
                ],
              ),
            ),

          // Start Button
          if (!_inCall)
            Center(
              child: ElevatedButton(
                onPressed: _startRandomChat,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: EdgeInsets.symmetric(horizontal: 40, vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: Text("Random Chat Boshlash", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _controlButton({required IconData icon, Color? color, required VoidCallback onPressed}) {
    return IconButton(
      icon: Icon(icon, color: color ?? Colors.white, size: 40),
      onPressed: onPressed,
      padding: EdgeInsets.all(12),
    );
  }

  @override
  void dispose() {
    _setOnlineStatus(false);
    _endCall();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }
}