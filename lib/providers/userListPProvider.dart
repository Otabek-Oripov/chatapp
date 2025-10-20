import 'package:chatapp/models/Usermodel.dart';
import 'package:chatapp/models/userlistnodel.dart';
import 'package:chatapp/providers/provide.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

class UserListNotifier extends StateNotifier<UserListTileState> {
  final Ref ref;
  final UserModel user;

  UserListNotifier(this.ref, this.user) : super(UserListTileState()) {
    _checkRelationship();
  }

  Future<void> _checkRelationship() async {
    final chatService = ref.read(chatServiceProvider);
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;
    final friends = await chatService.areUsersFriends(currentUserId, user.uid);

    if (friends) {
      state = state.copyWith(
        isFriend: true,
        requestStatus: null,
        isRequestSender: false,
        pendingRequestId: null,
      );
      return;
    }

    final senderRequestId = '${currentUserId}_${user.uid}';
    final receiverRequestId = '${user.uid}_$currentUserId';

    final senderDoc = await FirebaseFirestore.instance
        .collection('messageRequests')
        .doc(senderRequestId)
        .get();

    final receiverDoc = await FirebaseFirestore.instance
        .collection('messageRequests')
        .doc(receiverRequestId)
        .get();

    String? finalStatus;
    bool isSender = false;
    String? requestId;

    if (senderDoc.exists) {
      final sentStatus = senderDoc['status'];
      if (sentStatus == 'pending') {
        finalStatus = 'pending';
        isSender = true;
        requestId = senderRequestId;
      }
    }

    if (receiverDoc.exists && finalStatus == null) {
      final receivedStatus = receiverDoc['status'];
      if (receivedStatus == 'pending') {
        finalStatus = 'pending';
        isSender = false;
        requestId = receiverRequestId;
      }
    }

    state = state.copyWith(
      isFriend: false,
      requestStatus: finalStatus,
      isRequestSender: isSender,
      pendingRequestId: requestId,
    );
  }

  Future<String> sendRequest() async {
    state = state.copyWith(isLoading: true);
    final chatService = ref.read(chatServiceProvider);
    final result = await chatService.sendMessageRequest(
      receiverId: user.uid,
      receiverName: user.name,
      receiverEmail: user.email,
    );

    if (result == 'success') {
      state = state.copyWith(
        isLoading: false,
        requestStatus: 'pending',
        isRequestSender: true,
        pendingRequestId:
        '${FirebaseAuth.instance.currentUser!.uid}_${user.uid}',
      );
    } else {
      state = state.copyWith(isLoading: false);
    }

    return result;
  }

  Future<String> acceptRequest() async {
    if (state.pendingRequestId == null) return 'no-request';

    state = state.copyWith(isLoading: true);
    final chatService = ref.read(chatServiceProvider);
    final result = await chatService.acceptMessageRequest(
      state.pendingRequestId!,
      user.uid,
    );

    if (result == 'success') {
      state = state.copyWith(
        isLoading: false,
        isFriend: true,
        requestStatus: null,
        isRequestSender: false,
        pendingRequestId: null,
      );
      ref.invalidate(requestsProvider);
      ref.invalidate(chatsProvider);
    } else {
      state = state.copyWith(isLoading: false);
    }

    return result;
  }

  Future<void> cancelRequest() async {
    if (state.pendingRequestId == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('messageRequests')
          .doc(state.pendingRequestId)
          .delete();

      state = state.copyWith(
        requestStatus: null,
        isRequestSender: false,
        pendingRequestId: null,
      );
    } catch (e) {
      print("Error canceling request: $e");
    }
  }
}

final userListProvider = StateNotifierProvider.family<
    UserListNotifier,
    UserListTileState,
    UserModel>((ref, user) {
  return UserListNotifier(ref, user);
});
