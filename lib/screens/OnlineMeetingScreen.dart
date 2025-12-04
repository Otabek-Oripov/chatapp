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

  /// Har bir qidiruv sessiyasi uchun unikal token
  String? _searchToken;

  StreamSubscription<QuerySnapshot>? _matchSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    final user = _auth.currentUser;
    if (user == null) {
      userID = 'guest_${DateTime.now().millisecondsSinceEpoch}';
      userName = 'Guest';
    } else {
      userID = user.uid;
      userName = (user.displayName != null && user.displayName!.isNotEmpty)
          ? user.displayName!
          : (user.email ?? 'User_${user.uid.substring(0, 6)}');
    }

    // Ixtiyoriy: ekran ochilganda eski random holatlarni tozalab qo‘yish
    _cleanupMatching();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cleanupMatching();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Agar qidiruvda bo‘lsa ham, callda bo‘lsa ham – ilova background’ga ketganda
    // tozalab qo‘yamiz, shunda hech qachon xonada "yolg‘iz" qolib ketmaysan.
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

  /// Random bilan bog‘liq hamma narsani tozalash:
  /// - waiting dan chiqarish
  /// - bu user qatnashgan barcha active random_calls ni "ended" qilish
  /// - Zego roomdan chiqish
  Future<void> _cleanupMatching() async {
    _matchSubscription?.cancel();
    _matchSubscription = null;

    final currentToken = _searchToken;
    _searchToken = null;

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

    try {
      // Shu user ishtirok etayotgan barcha active call’larni tugatish
      final activeCallsSnap = await _firestore
          .collection('random_calls')
          .where('participants', arrayContains: userID)
          .where('status', isEqualTo: 'active')
          .get();

      for (final doc in activeCallsSnap.docs) {
        await doc.reference.set(
          {
            'status': 'ended',
            'endedAt': FieldValue.serverTimestamp(),
            // Agar token bilan match bo‘lgan bo‘lsa, baribir tugatiladi
          },
          SetOptions(merge: true),
        );
      }
    } catch (e) {
      debugPrint('random_calls cleanup error: $e');
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
        // Avvalgi tokenni hech qayerda ishlatmaymiz
      });
    }

    debugPrint('Random cleanup done for user=$userID, oldToken=$currentToken');
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

    // Har bir qidiruv sessiyasi uchun yangi token
    _searchToken = '${userID}_${DateTime.now().microsecondsSinceEpoch}';
    debugPrint('Random search started with token: $_searchToken');

    setState(() {
      _isSearching = true;
    });

    // Navbatga yozamiz
    final waitingRef = _firestore.collection('random_waiting').doc(userID);

    await waitingRef.set({
      'uid': userID,
      'name': userName,
      'token': _searchToken,
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

    // Agar navbatda boshqa user topilsa, transaction qilib call yaratamiz
    if (partnerDoc != null && _searchToken != null) {
      final partnerID = partnerDoc.id;
      final partnerData = partnerDoc.data();
      final partnerName = (partnerData['name'] ?? 'User') as String;
      final partnerToken = (partnerData['token'] ?? '') as String;

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
            'tokens': [_searchToken, partnerToken],
            'status': 'active',
            'createdAt': FieldValue.serverTimestamp(),
            'endAction': null,
            'endedBy': null,
            'endedAt': null,
          });

          // Endi navbatdan chiqarib tashlaymiz
          transaction.delete(myRef);
          transaction.delete(partnerRef);
        });

        // Transaction OK → juftlik topildi
        if (!mounted || !_isSearching || _searchToken == null) return;

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

    if (_searchToken == null) return;
    final localToken = _searchToken; // closure uchun

    _matchSubscription = _firestore
        .collection('random_calls')
        .where('tokens', arrayContains: localToken)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .listen((snapshot) {
      // Agar bu orada cancel bo‘lib ketgan bo‘lsa – eventni ignor qilamiz
      if (!_isSearching || _searchToken == null || _searchToken != localToken) {
        return;
      }

      if (!_isInCall && snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final data = doc.data();
        final callID = data['callID'] as String;
        final partnerID =
        (data['user1'] as String) == userID ? data['user2'] as String : data['user1'] as String;
        final partnerName =
        (data['user1'] as String) == userID ? data['user2_name'] as String : data['user1_name'] as String;

        _matchSubscription?.cancel();
        _matchSubscription = null;

        if (!mounted || !_isSearching) return;

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

  /// Call tugaganda – “Next” varianti (ikkala user ham qayta random qidirish)
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
                      // 🔥 Bekor qilish → random dagi hamma narsa tozalanadi
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

class _CallScreenState extends State<CallScreen>
    with WidgetsBindingObserver {
  final _firestore = FirebaseFirestore.instance;

  bool _isMicOn = true;
  bool _isCameraOn = true;

  /// Qaysi tugma bosilganini bilish uchun flag:
  /// next -> true, stop / system -> false
  bool _nextAfterHangup = false;

  /// onCallEnd faqat bir marta ishlashi uchun
  bool _handledCallEnd = false;

  final ZegoUIKitPrebuiltCallController _callController =
  ZegoUIKitPrebuiltCallController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// App backgroundga ketganda – callni STOP sifatida tugatamiz
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      if (!_handledCallEnd) {
        _nextAfterHangup = false; // stop
        _callController.hangUp(
          context,
          showConfirmation: false,
          reason: ZegoCallEndReason.localHangUp,
        );
      }
    }
  }

  Future<void> _markCallEnded(String action) async {
    try {
      await _firestore.collection('random_calls').doc(widget.callID).set(
        {
          'status': 'ended',
          'endAction': action, // 'next' yoki 'stop'
          'endedBy': widget.userID,
          'endedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('markCallEnded error: $e');
    }
  }

  void _onCallEnd(ZegoCallEndEvent event, VoidCallback defaultAction) {
    if (_handledCallEnd) {
      defaultAction.call();
      return;
    }
    _handledCallEnd = true;

    _handleCallEndAsync(event).whenComplete(() {
      defaultAction.call(); // Zego default Pop
    });
  }

  Future<void> _handleCallEndAsync(ZegoCallEndEvent event) async {
    // local user tugatdi
    if (event.reason == ZegoCallEndReason.localHangUp) {
      final action = _nextAfterHangup ? 'next' : 'stop';
      await _markCallEnded(action);

      if (_nextAfterHangup) {
        widget.onNext();
      } else {
        widget.onStop();
      }
    } else {
      // remote tugatdi → Firestore’dan endAction ni o‘qiymiz
      String? action;
      try {
        final doc = await _firestore
            .collection('random_calls')
            .doc(widget.callID)
            .get();
        action = doc.data()?['endAction'] as String?;
      } catch (_) {}

      if (action == 'next') {
        // 🔥 Partner Next bosgan → biz ham avtomatik Next
        widget.onNext();
      } else {
        // Partner Stop qilgan yoki status yo‘q → biz Stop varianti
        widget.onStop();
      }
    }
  }

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
              onCallEnd: _onCallEnd,
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
                    icon:
                    _isCameraOn ? Icons.videocam : Icons.videocam_off,
                  ),
                ),

                // NEXT (ikkala tomonni qayta qidirishga qaytaradi)
                GestureDetector(
                  onTap: () {
                    if (_handledCallEnd) return;
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

                // STOP (ikkala tomon uchun ham to‘xtatadi)
                GestureDetector(
                  onTap: () {
                    if (_handledCallEnd) return;
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
