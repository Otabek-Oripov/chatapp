// lib/screens/video_chat_screen.dart

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:zego_uikit/zego_uikit.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';

/// Random videochat uchun Zego konfiguratsiyasi
const int zegoRandomAppID = 1991101055;
const String zegoRandomAppSign =
    '2a591fef78ce6204faa1b11019ddb6908ad38305cf5fbc23229cdd9b67ccb602';

/// Omegle uslubidagi random videochat ekrani
class VideoChatScreen extends StatefulWidget {
  const VideoChatScreen({super.key});

  @override
  State<VideoChatScreen> createState() => _VideoChatScreenState();
}

class _VideoChatScreenState extends State<VideoChatScreen>
    with WidgetsBindingObserver {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  late final String userID;
  late final String userName;

  bool _isSearching = false;
  bool _isInCall = false;
  String? _activeCallID;
  String? _currentPartnerName;

  StreamSubscription<QuerySnapshot>? _matchSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    final user = _auth.currentUser;
    if (user == null) {
      // Teorik jihatdan bu ekranga guest kirishi kerak emas,
      // lekin crash bo‘lmasligi uchun fallback
      userID = 'guest_${DateTime.now().millisecondsSinceEpoch}';
      userName = 'Guest';
    } else {
      userID = user.uid;
      userName = (user.displayName != null && user.displayName!.isNotEmpty)
          ? user.displayName!
          : (user.email ?? 'User_${user.uid.substring(0, 6)}');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cleanupMatching();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _cleanupMatching();
    }
  }

  /// Kamera va mikrofonga ruxsat so‘rash
  Future<bool> _requestPermissions() async {
    final cameraStatus = await Permission.camera.request();
    final micStatus = await Permission.microphone.request();
    return cameraStatus.isGranted && micStatus.isGranted;
  }

  /// Random matchni tozalash (queue dan chiqish, call ni tugatish)
  Future<void> _cleanupMatching() async {
    _matchSubscription?.cancel();
    _matchSubscription = null;

    try {
      // waiting navbatdan o‘chirish
      await _firestore
          .collection('random_waiting')
          .doc(userID)
          .delete()
          .catchError((_) {});
    } catch (e) {
      debugPrint('random_waiting delete error: $e');
    }

    if (_activeCallID != null) {
      try {
        await _firestore.collection('random_calls').doc(_activeCallID).update({
          'status': 'ended',
          'endedAt': FieldValue.serverTimestamp(),
        }).catchError((_) {});
      } catch (e) {
        debugPrint('random_calls update error: $e');
      }
    }

    // Zego roomdan ham chiqamiz
    try {
      await ZegoUIKit().leaveRoom();
    } catch (_) {}

    if (mounted) {
      setState(() {
        _isSearching = false;
        _isInCall = false;
        _activeCallID = null;
        _currentPartnerName = null;
      });
    }
  }

  /// START tugmasi bosilganda: random juftlik qidirishni boshlash
  Future<void> _startMatching() async {
    if (_isSearching || _isInCall) return;

    if (!await _requestPermissions()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kamera va mikrofon ruxsatlari kerak.'),
        ),
      );
      return;
    }

    setState(() {
      _isSearching = true;
    });

    // Navbatga yozamiz
    final waitingRef =
    _firestore.collection('random_waiting').doc(userID);

    await waitingRef.set({
      'uid': userID,
      'name': userName,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Avval boshqa navbatdagilarni ko‘rib chiqamiz
    final waitingSnapshot = await _firestore
        .collection('random_waiting')
        .orderBy('createdAt', descending: false)
        .limit(10)
        .get();

    QueryDocumentSnapshot<Map<String, dynamic>>? partnerDoc;

    for (final doc in waitingSnapshot.docs) {
      if (doc.id != userID) {
        partnerDoc = doc;
        break;
      }
    }

    if (partnerDoc != null) {
      final partnerID = partnerDoc.id;
      final partnerName =
      (partnerDoc.data()['name'] ?? 'User') as String;

      final ids = [userID, partnerID]..sort();
      final callID = '${ids[0]}_${ids[1]}';

      try {
        await _firestore.runTransaction((transaction) async {
          final myRef =
          _firestore.collection('random_waiting').doc(userID);
          final partnerRef =
          _firestore.collection('random_waiting').doc(partnerID);

          final mySnap = await transaction.get(myRef);
          final partnerSnap = await transaction.get(partnerRef);

          if (!mySnap.exists || !partnerSnap.exists) {
            // Kimdir allaqachon olib ketgan bo‘lishi mumkin
            return;
          }

          final callRef =
          _firestore.collection('random_calls').doc(callID);

          transaction.set(callRef, {
            'callID': callID,
            'user1': userID,
            'user2': partnerID,
            'user1_name': userName,
            'user2_name': partnerName,
            'participants': [userID, partnerID],
            'status': 'active',
            'createdAt': FieldValue.serverTimestamp(),
          });

          // Endi navbatdan chiqarib tashlaymiz
          transaction.delete(myRef);
          transaction.delete(partnerRef);
        });

        // Transaction OK → juftlik topildi
        if (!mounted) return;

        _activeCallID = callID;
        _currentPartnerName = partnerName;

        setState(() {
          _isSearching = false;
          _isInCall = true;
        });

        _openCallScreen(
          callID: callID,
          partnerName: partnerName,
        );
        return;
      } catch (e) {
        debugPrint('Random match transaction error: $e');
        // Urinish muvaffaqiyatsiz → kutish rejimi
      }
    }

    // Hali juftlik topilmadi → boshqa user seni topishi uchun listener qo‘yamiz
    _matchSubscription?.cancel();
    _matchSubscription = _firestore
        .collection('random_calls')
        .where('participants', arrayContains: userID)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .listen((snapshot) {
      if (!_isInCall && snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final callID = doc['callID'] as String;
        final partnerID =
        (doc['user1'] as String) == userID ? doc['user2'] as String : doc['user1'] as String;
        final partnerName =
        (doc['user1'] as String) == userID ? doc['user2_name'] as String : doc['user1_name'] as String;

        _matchSubscription?.cancel();
        _matchSubscription = null;

        if (!mounted) return;

        _activeCallID = callID;
        _currentPartnerName = partnerName;

        setState(() {
          _isSearching = false;
          _isInCall = true;
        });

        _openCallScreen(
          callID: callID,
          partnerName: partnerName,
        );
      }
    });
  }

  /// CallScreen ga o‘tish
  void _openCallScreen({
    required String callID,
    required String partnerName,
  }) {
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => CallScreen(
          callID: callID,
          userID: userID,
          userName: userName,
          partnerName: partnerName,
          onNext: _onNextFromCall,
          onStop: _onStopFromCall,
        ),
      ),
    )
        .then((_) {
      if (mounted) {
        setState(() {
          _isInCall = false;
        });
      }
    });
  }

  /// Call tugaganda – “Stop” varianti (suhbat tugadi va qaytish)
  Future<void> _onStopFromCall() async {
    await _cleanupMatching();
  }

  /// Call tugaganda – “Next” varianti (yangi random qidirish)
  Future<void> _onNextFromCall() async {
    await _cleanupMatching();
    if (mounted) {
      _startMatching();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWaiting = _isSearching && !_isInCall;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Random Videochat',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.videocam_rounded,
              size: 80,
              color: Colors.white,
            ),
            const SizedBox(height: 24),
            Text(
              isWaiting
                  ? 'Juftlik qidirilmoqda...'
                  : 'Tasodifiy suhbatdosh bilan videochat qiling',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            if (isWaiting)
              Column(
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.stop),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    onPressed: () async {
                      await _cleanupMatching();
                    },
                    label: const Text(
                      'Bekor qilish',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const SizedBox(
                    height: 40,
                    width: 40,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 4,
                    ),
                  ),
                ],
              )
            else
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent.shade400,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 60,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(40),
                  ),
                ),
                onPressed: _startMatching,
                child: const Text(
                  'START',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Bitta random call uchun Zego ekrani
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
  bool _isMicOn = true;
  bool _isCameraOn = true;

  /// call tugaganda nima qilish kerakligini bilish uchun flag
  bool _isEnding = false;
  bool _nextAfterHangup = false;

  final ZegoUIKitPrebuiltCallController _callController =
  ZegoUIKitPrebuiltCallController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Asosiy Zego call widget
          ZegoUIKitPrebuiltCall(
            appID: zegoRandomAppID,
            appSign: zegoRandomAppSign,
            userID: widget.userID,
            userName: widget.userName,
            callID: widget.callID,
            config: ZegoUIKitPrebuiltCallConfig.oneOnOneVideoCall()
              ..turnOnCameraWhenJoining = true
              ..turnOnMicrophoneWhenJoining = true
              ..useSpeakerWhenJoining = true
              ..topMenuBarConfig.isVisible = false
              ..bottomMenuBarConfig.isVisible = false,
            events: ZegoUIKitPrebuiltCallEvents(
              onError: (error) {
                debugPrint('Zego error: $error');
              },
              onCallEnd:
                  (ZegoCallEndEvent event, VoidCallback defaultAction) {
                if (_isEnding) {
                  defaultAction.call();
                  return;
                }
                _isEnding = true;

                // remote chiqib ketsa yoki vaqt tugasa
                if (event.reason == ZegoCallEndReason.remoteHangUp ||
                    event.reason == ZegoCallEndReason.abandoned ||
                    event.reason == ZegoCallEndReason.kickOut) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Suhbatdosh chiqib ketdi'),
                    ),
                  );
                  widget.onStop();
                } else {
                  // localHangUp
                  if (_nextAfterHangup) {
                    widget.onNext();
                  } else {
                    widget.onStop();
                  }
                }

                // Zego defaultAction → oldingi sahifaga qaytish
                defaultAction.call();
              },
            ),
          ),

          // Partner ismi – yuqori chapda
          Positioned(
            top: 60,
            left: 20,
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

          // Tugmalar – mic, camera, next, stop
          Positioned(
            bottom: 160,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // MIKROFON
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isMicOn = !_isMicOn;
                    });
                    ZegoUIKit()
                        .turnMicrophoneOn(_isMicOn, userID: widget.userID);
                  },
                  child: _roundButton(
                    isActive: _isMicOn,
                    activeColor: Colors.green.shade600,
                    inactiveColor: Colors.red.shade700,
                    icon: _isMicOn ? Icons.mic : Icons.mic_off,
                  ),
                ),

                // KAMERA
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isCameraOn = !_isCameraOn;
                    });
                    ZegoUIKit()
                        .turnCameraOn(_isCameraOn, userID: widget.userID);
                  },
                  child: _roundButton(
                    isActive: _isCameraOn,
                    activeColor: Colors.green.shade600,
                    inactiveColor: Colors.red.shade700,
                    icon: _isCameraOn
                        ? Icons.videocam
                        : Icons.videocam_off,
                  ),
                ),

                // NEXT
                GestureDetector(
                  onTap: () {
                    if (_isEnding) return;
                    _nextAfterHangup = true;
                    _callController.hangUp(
                      context,
                      showConfirmation: false,
                      reason: ZegoCallEndReason.localHangUp,
                    );
                  },
                  child: _roundButton(
                    isActive: true,
                    activeColor: Colors.orange.shade700,
                    inactiveColor: Colors.orange.shade700,
                    icon: Icons.skip_next,
                  ),
                ),

                // STOP
                GestureDetector(
                  onTap: () {
                    if (_isEnding) return;
                    _nextAfterHangup = false;
                    _callController.hangUp(
                      context,
                      showConfirmation: false,
                      reason: ZegoCallEndReason.localHangUp,
                    );
                  },
                  child: _roundButton(
                    isActive: true,
                    activeColor: Colors.red.shade600,
                    inactiveColor: Colors.red.shade600,
                    icon: Icons.stop,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _roundButton({
    required bool isActive,
    required Color activeColor,
    required Color inactiveColor,
    required IconData icon,
  }) {
    final color = isActive ? activeColor : inactiveColor;
    return Container(
      height: 70,
      width: 70,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.6),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Icon(
        icon,
        color: Colors.white,
        size: 36,
      ),
    );
  }
}
