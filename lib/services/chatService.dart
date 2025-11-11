// lib/services/ChatService.dart
import 'dart:io';
import 'package:chatapp/models/MessageModel.dart';
import 'package:chatapp/models/MessageRequestModel.dart';
import 'package:chatapp/models/Usermodel.dart';
import 'package:chatapp/models/chatModel.dart';
import 'package:chatapp/services/chatId.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  String get currentUserId => _firebaseAuth.currentUser?.uid ?? "";

  /// Get all users except current user
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

  /// Update user online status
  Future<void> updateUserOnlineStatus(bool isOnline) async {
    if (currentUserId.isEmpty) return;
    try {
      await _firestore.collection("users").doc(currentUserId).update({
        "isOnline": isOnline,
        "lastSeen": FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("Error updating online status: $e");
    }
  }

  /// Check if users are friends
  Future<bool> areUsersFriends(String userID1, String userID2) async {
    final chatId = generateChatID(userID1, userID2);
    final friendshipDoc =
    await _firestore.collection("friendships").doc(chatId).get();
    return friendshipDoc.exists;
  }

  /// Unfriend user
  Future<String> unfriendUser(String chatId, String friendId) async {
    try {
      final batch = _firestore.batch();

      batch.delete(_firestore.collection('friendships').doc(chatId));
      batch.delete(_firestore.collection('chats').doc(chatId));

      final messages = await _firestore
          .collection('messages')
          .where('chatId', isEqualTo: chatId)
          .get();

      for (final doc in messages.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      return 'success';
    } catch (e) {
      return e.toString();
    }
  }

  /// Send message request
  Future<String> sendMessageRequest({
    required String receiverId,
    required String receiverName,
    required String receiverEmail,
  }) async {
    try {
      final currentUser = _firebaseAuth.currentUser!;
      final requestId = '${currentUserId}_$receiverId';

      final userDoc =
      await _firestore.collection("users").doc(currentUserId).get();
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
        id: requestId,
        senderId: currentUserId,
        receiverId: receiverId,
        senderName: currentUser.displayName ?? "User",
        sendEmail: currentUser.email ?? '',
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

  /// Stream of pending requests
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

  /// Accept message request
  Future<String> acceptMessageRequest(
      String requestId, String senderId) async {
    try {
      final batch = _firestore.batch();

      batch.update(
          _firestore.collection('messageRequests').doc(requestId), {
        'status': 'accepted',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final friendshipId = generateChatID(currentUserId, senderId);

      batch.set(_firestore.collection('friendships').doc(friendshipId), {
        'participants': [currentUserId, senderId],
        'createdAt': FieldValue.serverTimestamp(),
      });

      batch.set(_firestore.collection('chats').doc(friendshipId), {
        'chatId': friendshipId,
        'participants': [currentUserId, senderId],
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
        'message': 'Request accepted. You can start chatting.',
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'system',
      });

      await batch.commit();
      return 'success';
    } catch (e) {
      return e.toString();
    }
  }

  /// Reject message request
  Future<String> rejectMessageRequest(String requestId,
      {bool deleteRequest = true}) async {
    try {
      if (deleteRequest) {
        await _firestore
            .collection('messageRequests')
            .doc(requestId)
            .delete();
      } else {
        await _firestore
            .collection('messageRequests')
            .doc(requestId)
            .update({'status': 'rejected'});
      }
      return 'success';
    } catch (e) {
      return e.toString();
    }
  }

  /// Get user chat list
  Stream<List<ChatModel>> getUserChats() {
    if (currentUserId.isEmpty) return Stream.value([]);

    return _firestore
        .collection('chats')
        .where("participants", arrayContains: currentUserId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
          .map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return ChatModel.fromMap(data, doc.id);
      })
          .toList(),
    );
  }

  /// Get messages for a chat
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
    return query.snapshots().map(
          (snapshot) => snapshot.docs
          .map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return MessageModel.fromMap(data, doc.id);
      })
          .toList(),
    );
  }

  /// Send text message
  Future<String> sendMessage({
    required String chatId,
    required String message,
  }) async {
    try {
      final currentUser = _firebaseAuth.currentUser!;
      final messageId = _firestore.collection('messages').doc().id;
      final batch = _firestore.batch();

      batch.set(_firestore.collection('messages').doc(messageId), {
        'messageId': messageId,
        'senderId': currentUserId,
        'senderName': currentUser.displayName ?? "User",
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'chatId': chatId,
        'type': 'user',
        'readBy': null,
      });

      final chatDoc =
      await _firestore.collection('chats').doc(chatId).get();
      if (!chatDoc.exists) return 'Chat not found';

      final participants = List<String>.from(chatDoc['participants']);
      final otherUserId =
      participants.firstWhere((id) => id != currentUserId);

      batch.update(_firestore.collection('chats').doc(chatId), {
        'lastMessage': message,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageId': messageId,
        'lastSenderId': currentUserId,
        'unreadCount.$otherUserId': FieldValue.increment(1),
        'unreadCount.$currentUserId': 0,
      });

      await batch.commit();
      return 'success';
    } catch (e) {
      print('Error sending message: $e');
      return e.toString();
    }
  }

  /// Upload image
  Future<String> uploadImage(File imageFile, String chatId) async {
    try {
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_$currentUserId.jpg';
      final storeRef = FirebaseStorage.instance
          .ref()
          .child('chat_images')
          .child(chatId)
          .child(fileName);

      final uploadTask = storeRef.putFile(imageFile);
      final snapshot = await uploadTask.whenComplete(() {});
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('Error uploading image: $e');
      return '';
    }
  }

  /// Send image message
  Future<String> sendImageMessage({
    required String chatId,
    required String imageUrl,
    String? caption,
  }) async {
    try {
      final currentUser = _firebaseAuth.currentUser!;
      final messageId = _firestore.collection('messages').doc().id;
      final batch = _firestore.batch();

      batch.set(_firestore.collection('messages').doc(messageId), {
        'messageId': messageId,
        'senderId': currentUserId,
        'senderName': currentUser.displayName ?? "User",
        'message': caption ?? "",
        'readBy': null,
        'imageUrl': imageUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'chatId': chatId,
        'type': 'image',
      });

      final chatDoc =
      await _firestore.collection('chats').doc(chatId).get();
      if (!chatDoc.exists) return 'Chat not found';

      final participants = List<String>.from(chatDoc['participants']);
      final otherUserId =
      participants.firstWhere((id) => id != currentUserId);

      batch.update(_firestore.collection('chats').doc(chatId), {
        'lastMessage': (caption?.isNotEmpty ?? false) ? caption : 'Photo',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageId': messageId,
        'lastSenderId': currentUserId,
        'unreadCount.$otherUserId': FieldValue.increment(1),
        'unreadCount.$currentUserId': 0,
      });

      await batch.commit();
      return 'success';
    } catch (e) {
      print("Error sending image message: $e");
      return e.toString();
    }
  }

  /// Send + upload image
  Future<String> sendImageUpload({
    required String chatId,
    required File imageFile,
    String? caption,
  }) async {
    final imageUrl = await uploadImage(imageFile, chatId);
    if (imageUrl.isEmpty) return 'Failed to upload image';
    return await sendImageMessage(
        chatId: chatId, imageUrl: imageUrl, caption: caption);
  }

  /// Add Call History
  Future<String> addCallHistory({
    required String chatId,
    required bool isVideoCall,
    required String callStatus,
    int? duration,
  }) async {
    try {
      final currentUser = _firebaseAuth.currentUser!;
      final messageId = _firestore.collection('messages').doc().id;
      final batch = _firestore.batch();

      batch.set(_firestore.collection('messages').doc(messageId), {
        'messageId': messageId,
        'chatId': chatId,
        'senderId': currentUserId,
        'senderName': currentUser.displayName ?? '',
        'message': isVideoCall ? 'Video call' : 'Audio call',
        'callType': isVideoCall ? 'video' : 'audio',
        'timestamp': FieldValue.serverTimestamp(),
        'callStatus': callStatus,
        'duration': duration ?? 0,
        'type': 'call',
        'readBy': null,
      });

      final chatDoc =
      await _firestore.collection('chats').doc(chatId).get();
      if (!chatDoc.exists) return 'Chat not found';

      final participants = List<String>.from(chatDoc['participants']);
      final otherUserId =
      participants.firstWhere((id) => id != currentUserId);

      batch.update(_firestore.collection('chats').doc(chatId), {
        'lastMessage': isVideoCall ? 'Video call' : 'Audio call',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageId': messageId,
        'lastSenderId': currentUserId,
        'unreadCount.$otherUserId': FieldValue.increment(1),
        'unreadCount.$currentUserId': 0,
      });

      await batch.commit();
      return 'success';
    } catch (e) {
      print("Error adding call history: $e");
      return e.toString();
    }
  }

  /// Mark all messages as read
  Future<void> markMessageAsRead(String chatId) async {
    final currentUser = _firebaseAuth.currentUser;
    if (currentUser == null) return;

    try {
      final batch = _firestore.batch();

      final chatRef = _firestore.collection('chats').doc(chatId);
      batch.update(chatRef, {
        'unreadCount.${currentUser.uid}': 0,
        'lastReadTime.${currentUser.uid}': FieldValue.serverTimestamp(),
      });

      final messageQuery = await _firestore
          .collection('messages')
          .where('chatId', isEqualTo: chatId)
          .where('readBy', isNull: true)
          .get();

      for (final doc in messageQuery.docs) {
        final data = doc.data();
        final senderId = data['senderId'] as String?;
        if (senderId != null && senderId != currentUser.uid) {
          batch.update(doc.reference, {'readBy': currentUser.uid});
        }
      }

      await batch.commit();
    } catch (e) {
      print("Error marking messages as read: $e");
    }
  }

  /// Typing indicator
  Stream<Map<String, bool>> getTypingStatus(String chatId) {
    return _firestore.collection('chats').doc(chatId).snapshots().map((doc) {
      if (!doc.exists) return <String, bool>{};
      final data = doc.data() as Map<String, dynamic>;
      final typing = data['typing'] as Map<String, dynamic>? ?? {};
      final typingTimeStamp =
          data['typingTimeStamp'] as Map<String, dynamic>? ?? {};
      final result = <String, bool>{};
      final now = DateTime.now();
      typing.forEach((userid, isTyping) {
        if (userid != currentUserId) {
          final timestamp = typingTimeStamp[userid];
          if (timestamp != null && isTyping == true) {
            final typingTime = (timestamp as Timestamp).toDate();
            final isRecent = now.difference(typingTime).inSeconds < 5;
            result[userid] = isRecent;
          } else {
            result[userid] = false;
          }
        }
      });
      return result;
    });
  }

  Future<void> setTypingStatus(String chatId, bool isTyping) async {
    if (currentUserId.isEmpty) return;
    try {
      await _firestore.collection("chats").doc(chatId).update({
        'typing.$currentUserId': isTyping,
        'typingTimeStamp.$currentUserId': FieldValue.serverTimestamp(),
      });
      if (!isTyping) {
        Future.delayed(const Duration(seconds: 1), () async {
          try {
            await _firestore.collection("chats").doc(chatId).update({
              'typing.$currentUserId': false,
            });
          } catch (e) {}
        });
      }
    } catch (e) {
      print('Error updating typing status: $e');
    }
  }

  /// Upload audio
  Future<String> uploadAudio(File audioFile, String chatId) async {
    try {
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_$currentUserId.m4a';
      final ref = FirebaseStorage.instance
          .ref()
          .child('chat_audios')
          .child(chatId)
          .child(fileName);

      final uploadTask = ref.putFile(audioFile);
      final snapshot = await uploadTask.whenComplete(() {});
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('Error uploading audio: $e');
      return '';
    }
  }

  /// Send audio message
  Future<String> sendAudioMessage({
    required String chatId,
    required String audioUrl,
  }) async {
    try {
      final currentUser = _firebaseAuth.currentUser!;
      final messageId = _firestore.collection('messages').doc().id;
      final batch = _firestore.batch();

      batch.set(_firestore.collection('messages').doc(messageId), {
        'messageId': messageId,
        'senderId': currentUserId,
        'senderName': currentUser.displayName ?? "User",
        'message': '',
        'audioUrl': audioUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'chatId': chatId,
        'type': 'audio',
        'readBy': null,
      });

      final chatDoc =
      await _firestore.collection('chats').doc(chatId).get();
      if (!chatDoc.exists) return 'Chat not found';

      final participants = List<String>.from(chatDoc['participants']);
      final otherUserId =
      participants.firstWhere((id) => id != currentUserId);

      batch.update(_firestore.collection('chats').doc(chatId), {
        'lastMessage': 'Voice message',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageId': messageId,
        'lastSenderId': currentUserId,
        'unreadCount.$otherUserId': FieldValue.increment(1),
        'unreadCount.$currentUserId': 0,
      });

      await batch.commit();
      return 'success';
    } catch (e) {
      print('Error sending audio: $e');
      return e.toString();
    }
  }

  /// Send audio upload
  Future<String> sendAudioUpload({
    required String chatId,
    required File audioFile,
  }) async {
    final audioUrl = await uploadAudio(audioFile, chatId);
    if (audioUrl.isEmpty) return 'Failed to upload audio';
    return await sendAudioMessage(chatId: chatId, audioUrl: audioUrl);
  }

  // --------------------------------------------------------------
  //  DELETE MESSAGE (FOR EVERYONE) – TO‘LIQ TUGALLANGAN VERSIYA
  // --------------------------------------------------------------
  Future<String> deleteMessage({
    required String chatId,
    required String messageId,
  }) async {
    try {
      final messageRef = _firestore.collection('messages').doc(messageId);
      final messageSnap = await messageRef.get();

      if (!messageSnap.exists) return 'Message not found';

      final senderId = messageSnap['senderId'] as String?;
      if (senderId != currentUserId) {
        return 'You can only delete your own messages';
      }

      final batch = _firestore.batch();
      batch.delete(messageRef);

      final chatRef = _firestore.collection('chats').doc(chatId);
      final chatSnap = await chatRef.get();

      if (chatSnap.exists) {
        final data = chatSnap.data() as Map<String, dynamic>;

        // Agar o‘chirilayotgan xabar oxirgi xabar bo‘lsa
        if (data['lastMessageId'] == messageId) {
          // Yangi oxirgi xabarni topish
          final lastMessagesQuery = await _firestore
              .collection('messages')
              .where('chatId', isEqualTo: chatId)
              .orderBy('timestamp', descending: true)
              .limit(1)
              .get();

          if (lastMessagesQuery.docs.isNotEmpty) {
            final newDoc = lastMessagesQuery.docs.first;
            final newData = newDoc.data();

            String lastMessageText = '';
            switch (newData['type']) {
              case 'image':
                lastMessageText = (newData['message']?.toString().isNotEmpty ??
                    false)
                    ? newData['message']
                    : 'Photo';
                break;
              case 'audio':
                lastMessageText = 'Voice message';
                break;
              case 'call':
                lastMessageText =
                newData['callType'] == 'video' ? 'Video call' : 'Audio call';
                break;
              default:
                lastMessageText = newData['message'] ?? '';
            }

            batch.update(chatRef, {
              'lastMessage': lastMessageText,
              'lastMessageTime': newData['timestamp'],
              'lastMessageId': newDoc.id,
              'lastSenderId': newData['senderId'],
            });
          } else {
            // Hech qanday xabar qolmagan
            batch.update(chatRef, {
              'lastMessage': 'Chat cleared',
              'lastMessageTime': FieldValue.serverTimestamp(),
              'lastMessageId': null,   // null – to‘g‘ri
              'lastSenderId': null,
            });
          }
        }
        // Aks holda hech narsa qilmaslik kerak
      }

      await batch.commit();
      return 'success';
    } catch (e) {
      print('Delete error: $e');
      return e.toString();
    }
  }
}