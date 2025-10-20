import 'dart:async';
import 'package:chatapp/models/MessageRequestModel.dart';
import 'package:chatapp/models/Usermodel.dart';
import 'package:chatapp/models/chatModel.dart';
import 'package:chatapp/services/chatService.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

final chatServiceProvider = Provider<ChatService>((ref) => ChatService());

class UserNotifier extends StateNotifier<AsyncValue<List<UserModel>>> {
  final ChatService _chatService;
  StreamSubscription<List<UserModel>>? _subscription;

  UserNotifier(this._chatService) : super(const AsyncValue.loading()) {
    _init();
  }

  void _init() {
    _subscription?.cancel();
    _subscription = _chatService.getAllUsers().listen(
      (users) => state = AsyncValue.data(users),
      onError: (error, stackTrace) =>
          state = AsyncValue.error(error, stackTrace),
    );
  }

  void refresh() => _init();

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final usersProvider =
    StateNotifierProvider<UserNotifier, AsyncValue<List<UserModel>>>((ref) {
      final service = ref.watch(chatServiceProvider);
      return UserNotifier(service);
    });

class RequestNotifier
    extends StateNotifier<AsyncValue<List<MessagerequestModel>>> {
  final ChatService _chatService;
  StreamSubscription<List<MessagerequestModel>>? _subscription;

  RequestNotifier(this._chatService) : super(const AsyncValue.loading()) {
    _init();
  }

  void _init() {
    _subscription?.cancel();
    _subscription = _chatService.getPendingRequest().listen(
      (requests) => state = AsyncValue.data(requests),
      onError: (error, stackTrace) =>
          state = AsyncValue.error(error, stackTrace),
    );
  }

  Future<void> acceptRequest(String requestId, String senderId) async {
    await _chatService.acceptMessageRequest(requestId, senderId);
    _init();
  }

  Future<void> rejectRequest(String requestId) async {
    await _chatService.rejectMessageRequest(requestId);
    _init();
  }

  void refresh() => _init();

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final requestsProvider =
    StateNotifierProvider<
      RequestNotifier,
      AsyncValue<List<MessagerequestModel>>
    >((ref) {
      final service = ref.watch(chatServiceProvider);
      return RequestNotifier(service);
    });

final autofreshProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<User?>>(authStateProvider, (prev, next) {
    next.whenData((user) {
      if (user != null) {
        Future.delayed(const Duration(milliseconds: 500), () {
          ref.invalidate(usersProvider);
          ref.invalidate(requestsProvider);
        });
      }
    });
  });
});

class ChatsNotifier extends StateNotifier<AsyncValue<List<ChatModel>>> {
  final ChatService _chatService;
  StreamSubscription<List<ChatModel>>? _subscription;

  ChatsNotifier(this._chatService) : super(const AsyncValue.loading()) {
    _init();
  }

  void _init() {
    _subscription?.cancel();
    _subscription = _chatService.getUserChats().listen(
          (chats) => state = AsyncValue.data(chats),
      onError: (error, stackTrace) =>
      state = AsyncValue.error(error, stackTrace),
    );
  }

  void refresh() => _init();

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final chatsProvider =
StateNotifierProvider<ChatsNotifier, AsyncValue<List<ChatModel>>>((ref) {
  final service = ref.watch(chatServiceProvider);
  return ChatsNotifier(service);
});


final searchQueryProvider = StateProvider<String>((ref) => '');

final filteresUsersProvider = Provider<AsyncValue<List<UserModel>>>((ref) {
  final users = ref.watch(usersProvider);
  final query = ref.watch(searchQueryProvider);
  return users.when(
    data: (list) {
      if (query.isEmpty) return AsyncValue.data(list);
      return AsyncValue.data(
        list
            .where(
              (u) =>
                  u.name.toLowerCase().contains(query.toLowerCase()) ||
                  u.email.toLowerCase().contains(query.toLowerCase()),
            )
            .toList(),
      );
    },
    error: (error, stackTrace) => AsyncValue.error(error, stackTrace),
    loading: () => AsyncValue.loading(),
  );
});
