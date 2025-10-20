import 'package:chatapp/models/MessageModel.dart';
import 'package:chatapp/models/MessageRequestModel.dart';
import 'package:chatapp/models/Usermodel.dart';
import 'package:chatapp/models/chatModel.dart';
import 'package:chatapp/services/chatId.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  String get currentUserId => _firebaseAuth.currentUser?.uid ?? "";

  Stream<List<UserModel>> getAllUsers() {
    if (currentUserId.isEmpty) return Stream.value([]);

    return _firestore
        .collection("users")
        .where("uid", isNotEqualTo: currentUserId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => UserModel.fromMap(doc.data()))
              .where((user) => user.uid != currentUserId)
              .toList(),
        );
  }

  Future<void> updateUserOnlineStatus(bool isOnline) async {
    if (currentUserId.isEmpty) return;
    try {
      await _firestore.collection("users").doc(currentUserId).update({
        "isOnline": isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {}
  }

  Future<bool> areUsersFriends(String userID1, String userID2) async {
    final chatId = generateChatID(userID1, userID2);
    final friendshipDoc = await _firestore
        .collection("friendships")
        .doc(chatId)
        .get();
    final exists = friendshipDoc.exists;
    return exists;
  }

  Future<String> sendMessageRequest({
    required String receiverId,
    required String receiverName,
    required String receiverEmail,
  }) async {
    try {
      final currrentUser = _firebaseAuth.currentUser!;
      final requestId = '${currentUserId}_$receiverId';
      final userDoc = await _firestore
          .collection("users")
          .doc(currentUserId)
          .get();
      String? userPhotoUrl;
      if (userDoc.exists) {
        final userModel = UserModel.fromMap(userDoc.data()!);
        userPhotoUrl = userModel.photoUrl;
      }

      final existingRequest = await _firestore
          .collection('messageRequests')
          .doc(requestId)
          .get();
      if (existingRequest.exists &&
          existingRequest.data()?['status'] == 'pending') {
        return 'Request already sent';
      }
      final request = MessagerequestModel(
        id: receiverId,
        senderId: currentUserId,
        receiverId: receiverId,
        senderName: currrentUser.displayName ?? "user",
        sendEmail: currrentUser.email ?? '',
        status: 'pending',
        createdAt: DateTime.now(),
        photoUrl: userPhotoUrl,
      );

      await _firestore
          .collection('messageRequests')
          .doc(requestId)
          .set(request.toMap());
      return "success";
    } catch (e) {
      return e.toString();
    }
  }

  Stream<List<MessagerequestModel>> getPendingRequest() {
    if (currentUserId.isEmpty) return Stream.value([]);
    return _firestore
        .collection("messageRequests")
        .where('receiverId', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => MessagerequestModel.fromMap(doc.data()))
              .toList(),
        );
  }

  Future<String> acceptMessageRequest(String requestId, String senderId) async {
    try {
      final batch = _firestore.batch();
      batch.update(_firestore.collection('messageRequests').doc(requestId), {
        'status': 'accepted',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final friendshipId = generateChatID(currentUserId, senderId);
      batch.set(_firestore.collection('friendships').doc(friendshipId), {
        'paticipants': [currentUserId, senderId],
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.set(_firestore.collection('chats').doc(friendshipId), {
        'chatId': friendshipId,
        'paticipants': [currentUserId, senderId],
        'lastMessage': '',
        'lastSenderId': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'unreadCount': {currentUserId: 0, senderId: 0},
      });

      final messageId = _firestore.collection('messages').doc().id;
      batch.set(_firestore.collection('messages').doc(messageId), {
        'messageId': messageId,
        'chatId': friendshipId,
        'senderId': 'system',
        'senderName': 'System',
        'message': 'Request has been accepted. You can now start chatting',
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'system',
      });
      await batch.commit();
      return 'success';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String> rejectMessageRequest(
    String requestId, {
    bool deleteRequest = true,
  }) async {
    try {
      if (deleteRequest) {
        await _firestore.collection('messageRequests').doc(requestId).delete();
      } else {
        await _firestore.collection('messageRequests').doc(requestId).update({
          'status': 'rejected',
        });
      }
      return 'success';
    } catch (e) {
      return e.toString();
    }
  }

  final Map<String, List<ChatModel>> _chatsCache = {};

  Stream<List<ChatModel>> getUserChats() {
    if (currentUserId.isEmpty) return Stream.value([]);
    return _firestore
        .collection('chats')
        .where("participants", arrayContains: currentUserId)
        .orderBy('lastMessageTime', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) {
          final docs = snapshot.docs
              .map((doc) => ChatModel.fromMap(doc.data()))
              .toList();
          return docs;
        });
  }

  Stream<List<MessageModel>> getChatMessages(
    String chatId, {
    int limit = 20,
    DocumentSnapshot? lastDocument,
  }) {
    Query query = _firestore
        .collection('messages')
        .where('chatId', isEqualTo: chatId)
        .orderBy('timestamp', descending: true)
        .limit(limit);
    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }
    return query.snapshots().map((snapshot) {
      final docs = snapshot.docs
          .map(
            (doc) => MessageModel.fromMap(doc.data() as Map<String, dynamic>),
          )
          .toList();
      print("sizeofDoc2 ${docs.length}");
      return docs;
    });
  }
}
