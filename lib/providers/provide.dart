import 'dart:async';
import 'package:chatapp/models/MessageRequestModel.dart';
import 'package:chatapp/models/Usermodel.dart';
import 'package:chatapp/models/chatModel.dart';
import 'package:chatapp/services/chatService.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:just_audio/just_audio.dart';

// Auth State Provider
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

final audioPlayerProvider = Provider<AudioPlayer>((ref) {
  final player = AudioPlayer();
  ref.onDispose(() => player.dispose());
  return player;
});

// Chat Service Provider
final chatServiceProvider = Provider<ChatService>((ref) => ChatService());

// User Notifier
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

// Request Notifier
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
StateNotifierProvider<RequestNotifier, AsyncValue<List<MessagerequestModel>>>(
        (ref) {
      final service = ref.watch(chatServiceProvider);
      return RequestNotifier(service);
    });

// Auto Refresh Provider
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

// Chats Notifier
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

// Search Query Provider
final searchQueryProvider = StateProvider<String>((ref) => '');

//Filtered Users Provider
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
    loading: () => const AsyncValue.loading(),
  );
});

// --------- Typing Indicator ---------
class TypingNotifier extends StateNotifier<Map<String, bool>> {
  final ChatService _chatService;
  StreamSubscription<Map<String, bool>>? _subscription;
  final String chatId;

  TypingNotifier(this._chatService, this.chatId) : super({}) {
    listenToTypingStatus();
  }

  void listenToTypingStatus() {
    _subscription?.cancel();
    _subscription = _chatService.getTypingStatus(chatId).listen(
          (typingData) => state = Map<String, bool>.from(typingData),
      onError: (error) => state = {},
    );
  }

  Future<void> setTyping(bool isTyping) async {
    await _chatService.setTypingStatus(chatId, isTyping);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final typingProvider = StateNotifierProvider.family<
    TypingNotifier, Map<String, bool>, String>((ref, chatId) {
  final service = ref.watch(chatServiceProvider);
  return TypingNotifier(service, chatId);
});
