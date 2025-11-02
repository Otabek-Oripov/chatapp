import 'dart:async';
import 'dart:io';
import 'package:chatapp/function/date_time_helper.dart';
import 'package:chatapp/function/snakbar.dart';
import 'package:chatapp/models/Usermodel.dart';
import 'package:chatapp/providers/provide.dart';
import 'package:chatapp/widgets/callHistory.dart';
import 'package:chatapp/widgets/messageandimages_display.dart';
import 'package:chatapp/widgets/user_chat_profil.dart';
import 'package:chatapp/widgets/video_call_button.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String chatId;
  final UserModel othersUser;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.othersUser,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  final FocusNode _textFieldFocusNode = FocusNode();

  bool isUploadingImage = false;
  bool _isCurrentlyTyping = false;
  bool _isTextFieldFocused = false;
  Timer? _typingTimer;
  Timer? _typingDebounceTimer;
  Timer? _readStatusTimer;
  List<String> unreadMessageIds = [];

  @override
  void initState() {
    _textFieldFocusNode.addListener(() {
      if (_textFieldFocusNode.hasFocus) {
        _handleTextFieldFocus();
      } else {
        _handleTextFieldUnFocus();
      }
    });
    super.initState();
  }

  // Typing logic
  void _handleTextChange(String text) {
    _typingDebounceTimer?.cancel();
    if (text.trim().isNotEmpty && _isTextFieldFocused) {
      if (!_isCurrentlyTyping) {
        _isCurrentlyTyping = true;
        ref.read(typingProvider(widget.chatId).notifier).setTyping(true);
      }
      _typingDebounceTimer = Timer(const Duration(seconds: 2), _handleTypingStop);
    } else {
      _handleTypingStop();
    }
  }

  void _handleTypingStop() {
    if (_isCurrentlyTyping) {
      _isCurrentlyTyping = false;
      ref.read(typingProvider(widget.chatId).notifier).setTyping(false);
    }
    _typingTimer?.cancel();
  }

  void _handleTextFieldFocus() {
    _isTextFieldFocused = true;
  }

  void _handleTextFieldUnFocus() {
    _isTextFieldFocused = false;
    _handleTypingStop();
  }

  // 🟦 Xabar yuborish
  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;
    _messageController.clear();

    final chatService = ref.read(chatServiceProvider);
    final result = await chatService.sendMessage(
      chatId: widget.chatId,
      message: message,
    );

    if (result != 'success' && mounted) {
      showAppSnackbar(
        context: context,
        type: SnackbarType.error,
        description: 'Failed to send message',
      );
    }
  }

  // 🟨 O‘qilgan xabarlarni belgilash
  Future<void> _markRead() async {
    _readStatusTimer?.cancel();
    _readStatusTimer = Timer(const Duration(milliseconds: 300), () async {
      try {
        final chatService = ref.read(chatServiceProvider);
        await chatService.markMessageAsRead(widget.chatId);
        unreadMessageIds.clear();
      } catch (e) {
        debugPrint("❌ Error marking as read: $e");
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _readStatusTimer?.cancel();
    _textFieldFocusNode.dispose();
    _typingTimer?.cancel();
    _typingDebounceTimer?.cancel();

    if (_isCurrentlyTyping) {
      ref.read(typingProvider(widget.chatId).notifier).setTyping(false);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatService = ref.read(chatServiceProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: UserChatProfile(user: widget.othersUser, chatId: widget.chatId),
        actions: [
          actionButton(
            false,
            widget.othersUser.uid,
            widget.othersUser.name,
            ref,
            widget.chatId,
          ),
          actionButton(
            true,
            widget.othersUser.uid,
            widget.othersUser.name,
            ref,
            widget.chatId,
          ),
          PopupMenuButton(
            onSelected: (value) async {
              if (value == 'unfriend') {
                final result = await showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text("Unfriend User"),
                    content: Text(
                      'Are you sure you want to unfriend ${widget.othersUser.name}?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Unfriend'),
                      ),
                    ],
                  ),
                );

                if (result == true) {
                  final unfriendResult = await chatService.unfriendUser(
                    widget.chatId,
                    widget.othersUser.uid,
                  );
                  if (unfriendResult == 'success' && context.mounted) {
                    Navigator.pop(context);
                    showAppSnackbar(
                      context: context,
                      type: SnackbarType.success,
                      description: 'Your friendship disconnected',
                    );
                  }
                }
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'unfriend', child: Text('Unfriend')),
            ],
          ),
        ],
      ),

      // 🟧 Body
      body: Column(
        children: [
          // 🔹 Chat messages
          Expanded(
            child: StreamBuilder(
              stream: chatService.getChatMessages(widget.chatId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  print("GGG:${snapshot.error}");
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final messages = snapshot.data ?? [];
                final currentUserId = FirebaseAuth.instance.currentUser!.uid;

                if (messages.isNotEmpty) {
                  final hasUnreadMessages = messages.any((msg) {
                    // msg.readBy null bo'lsa false qaytarsin
                    final readBy = msg.readBy;
                    // agar readBy null bo'lsa yoki currentUserId mavjud bo'lmasa -> false
                    return msg.senderId != currentUserId; });

                  if (hasUnreadMessages) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _markRead();
                    });
                  }
                }


                if (messages.isEmpty) {
                  return const Center(
                    child: Text(
                      'No messages yet. Start the conversation!',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderId == currentUserId;
                    final isSystem = message.type == 'system';
                    final isVideo = message.callType == 'video';
                    final isMissed = message.callStatus == 'missed';
                    final showDateHeader = shouldShowDateHeader(messages, index);

                    return Column(
                      children: [
                        if (isSystem)
                          Container(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              message.message,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontStyle: FontStyle.italic,
                                color: Colors.grey,
                              ),
                            ),
                          )
                        else if (message.type == 'call')
                          Callhistory(
                            isMe: isMe,
                            widget: widget,
                            isMissed: isMissed,
                            isVideo: isVideo,
                            message: message,
                          )
                        else
                          MessageandimagesDisplay(
                            isMe: isMe,
                            message: message,
                            widget: widget,
                          ),

                        if (showDateHeader)
                          Container(
                            margin: const EdgeInsets.symmetric(vertical: 16),
                            child: Row(
                              children: [
                                const Expanded(child: Divider()),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    formatDateHeader(message.timestamp),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ),
                                const Expanded(child: Divider()),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // 🔹 Message Input
          Container(
            padding:
            const EdgeInsets.only(top: 5, right: 10, left: 10, bottom: 15),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  blurRadius: 4,
                  spreadRadius: 1,
                  offset: const Offset(0, -1),
                  color: Colors.grey.withAlpha(100),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: isUploadingImage ? null : _showImageOptions,
                  icon: Icon(
                    Icons.image,
                    size: 30,
                    color: isUploadingImage ? Colors.grey : Colors.blue,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    focusNode: _textFieldFocusNode,
                    decoration: InputDecoration(
                      hintText: 'Text a message...',
                      border: const OutlineInputBorder(
                        borderSide: BorderSide.none,
                      ),
                      fillColor: Colors.grey[100],
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                    maxLines: null,
                    onSubmitted: (_) => _sendMessage(),
                    onChanged: _handleTextChange,
                    onTap: _handleTextFieldFocus,
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  onPressed: isUploadingImage ? null : _sendMessage,
                  mini: true,
                  elevation: 0,
                  backgroundColor: Colors.grey.shade300,
                  shape: const CircleBorder(),
                  child: isUploadingImage
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Icon(Icons.send,
                      color: Colors.blueAccent, size: 26),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🟩 Image picker va preview
  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.cancel),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        final File imageFile = File(pickedFile.path);
        await _showImagePreview(imageFile);
      }
    } catch (e) {
      if (mounted) {
        showAppSnackbar(
          context: context,
          type: SnackbarType.error,
          description: 'Error picking image: $e',
        );
      }
    }
  }

  Future<void> _showImagePreview(File imageFile) async {
    final captionController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        contentPadding: const EdgeInsets.all(16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              constraints: const BoxConstraints(maxHeight: 300),
              child: Image.file(imageFile, fit: BoxFit.contain),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: captionController,
              decoration: const InputDecoration(
                hintText: 'Add a caption (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (result == true) {
      await _sendImageMessage(imageFile, captionController.text);
    }
  }

  Future<void> _sendImageMessage(File imageFile, String caption) async {
    setState(() => isUploadingImage = true);
    try {
      final chatService = ref.read(chatServiceProvider);
      final result = await chatService.sendImageUpload(
        chatId: widget.chatId,
        imageFile: imageFile,
        caption: caption.isEmpty ? null : caption,
      );
      if (result != 'success' && mounted) {
        showAppSnackbar(
          context: context,
          type: SnackbarType.error,
          description: 'Failed to send image: $result',
        );
      }
    } catch (e) {
      if (mounted) {
        showAppSnackbar(
          context: context,
          type: SnackbarType.error,
          description: 'Failed to send image: $e',
        );
      }
    } finally {
      if (mounted) setState(() => isUploadingImage = false);
    }
  }
}
