import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:chatapp/function/snakbar.dart';
import 'package:chatapp/main.dart';
import 'package:chatapp/models/Usermodel.dart';
import 'package:chatapp/providers/provide.dart';
import 'package:chatapp/widgets/custom_audio_bubble.dart';
import 'package:chatapp/widgets/messageandimages_display.dart';
import 'package:chatapp/widgets/user_chat_profil.dart';
import 'package:chatapp/widgets/video_call_button.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart' hide PlayerState;

import '../../widgets/callHistory.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String chatId;
  final UserModel othersUser;

  const ChatScreen({super.key, required this.chatId, required this.othersUser});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  final FocusNode _textFieldFocusNode = FocusNode();
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();

  bool isUploading = false;
  bool _isRecording = false;
  bool _isCurrentlyTyping = false;
  bool _isTextFieldFocused = false;
  Timer? _typingTimer;
  Timer? _typingDebounceTimer;
  String? _recordedFilePath;

  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    OnlineStatusService();
    _textFieldFocusNode.addListener(() {
      if (_textFieldFocusNode.hasFocus) {
        _handleTextFieldFocus();
      } else {
        _handleTextFieldUnFocus();
      }
    });

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _waveController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    _textFieldFocusNode.dispose();
    _typingTimer?.cancel();
    _typingDebounceTimer?.cancel();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  void _handleTextChange(String text) {
    _typingDebounceTimer?.cancel();
    setState(() {}); // rebuild for mic/send toggle
    if (text.trim().isNotEmpty && _isTextFieldFocused) {
      if (!_isCurrentlyTyping) {
        _isCurrentlyTyping = true;
        ref.read(typingProvider(widget.chatId).notifier).setTyping(true);
      }
      _typingDebounceTimer = Timer(
        const Duration(seconds: 2),
        _handleTypingStop,
      );
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

  void _handleTextFieldFocus() => _isTextFieldFocused = true;

  void _handleTextFieldUnFocus() {
    _isTextFieldFocused = false;
    _handleTypingStop();
  }

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

  Future<void> _startOrStopRecording() async {
    if (_isRecording) {
      // Stop and send
      final filePath = await _recorder.stop();
      setState(() => _isRecording = false);
      if (filePath != null) {
        await _sendVoiceMessage(File(filePath));
      }
    } else {
      // Start recording
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        showAppSnackbar(
          context: context,
          type: SnackbarType.error,
          description: 'Microphone permission denied',
        );
        return;
      }

      final dir = await getApplicationDocumentsDirectory();
      final path =
          '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(
        RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000),
        path: path,
      );
      setState(() {
        _isRecording = true;
        _recordedFilePath = path;
      });
    }
  }

  Future<void> _sendVoiceMessage(File audioFile) async {
    setState(() => isUploading = true);
    try {
      final chatService = ref.read(chatServiceProvider);
      final result = await chatService.sendAudioUpload(
        chatId: widget.chatId,
        audioFile: audioFile,
      );
      if (result != 'success' && mounted) {
        showAppSnackbar(
          context: context,
          type: SnackbarType.error,
          description: 'Failed to send audio',
        );
      }
    } catch (e) {
      if (mounted) {
        showAppSnackbar(
          context: context,
          type: SnackbarType.error,
          description: 'Error: $e',
        );
      }
    } finally {
      if (mounted) setState(() => isUploading = false);
    }
  }

  // ---------- IMAGE PICK + PREVIEW ----------
  Future<void> _pickImage(ImageSource source) async {
    final XFile? pickedFile = await _imagePicker.pickImage(
      source: source,
      imageQuality: 85,
    );
    if (pickedFile != null) {
      final File imageFile = File(pickedFile.path);
      await _showImagePreview(imageFile);
    }
  }

  Future<void> _showImagePreview(File imageFile) async {
    final captionController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file(
                    imageFile,
                    fit: BoxFit.contain,
                    height: MediaQuery.of(context).size.height * 0.35,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: captionController,
                  decoration: InputDecoration(
                    hintText: 'Add a caption...',
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.blueAccent),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context, true),
                      icon: const Icon(Icons.send),
                      label: const Text('Send'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result == true) {
      await _sendImageMessage(imageFile, captionController.text.trim());
    }
  }

  Future<void> _sendImageMessage(File imageFile, String caption) async {
    setState(() => isUploading = true);
    try {
      final chatService = ref.read(chatServiceProvider);
      await chatService.sendImageUpload(
        chatId: widget.chatId,
        imageFile: imageFile,
        caption: caption.isEmpty ? null : caption,
      );
    } finally {
      if (mounted) setState(() => isUploading = false);
    }
  }

  // ---------- BUILD ----------
  @override
  Widget build(BuildContext context) {
    final chatService = ref.read(chatServiceProvider);
    return Scaffold(
      backgroundColor: Colors.white,
      // ChatScreen ichidagi appBar — TO‘G‘RI USUL!
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: false,
            title: UserChatProfile(
              user: widget.othersUser,
              chatId: widget.chatId,
            ),
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                icon: const Icon(Icons.more_vert, color: Colors.black87),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'unfriend',
                    child: Text("Do‘stlikni bekor qilish"),
                  ),
                ],
                onSelected: (v) async {
                  if (v == 'unfriend') {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text("Do‘stlikni bekor qilish"),
                        content: Text(
                          "${widget.othersUser.name} bilan do‘stlikni bekor qilmoqchimisiz?",
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text("Yo‘q"),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text("Ha"),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await ref
                          .read(chatServiceProvider)
                          .unfriendUser(widget.chatId, widget.othersUser.uid);
                      if (mounted) Navigator.pop(context);
                    }
                  }
                },
              ),
              const SizedBox(width: 10),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder(
              stream: chatService.getChatMessages(widget.chatId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = snapshot.data ?? [];
                final currentUserId = FirebaseAuth.instance.currentUser!.uid;
                if (messages.isEmpty) {
                  return const Center(child: Text("No messages yet."));
                }

                final outgoingColor = Color(0xFF6a11cb);
                final outgoingTextColor = Colors.white;
                final incomingColor = const Color(0xFFF1F0F0);
                final incomingTextColor = Colors.black87;


                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  cacheExtent: 1000,
                  // Yangi: eski itemlarni cache qiladi
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderId == currentUserId;
                    final isMissed = message.callStatus == 'missed';
                    final isVideo = message.callType == 'video';
                    final isSystem = message.type == 'system';

                    if (message.type == 'audio') {
                      final bubbleColor = isMe ? outgoingColor : incomingColor;
                      final textColor = isMe
                          ? outgoingTextColor
                          : incomingTextColor;
                      final accentColor = isMe
                          ? Colors.white
                          : Color(0xFF6a11cb);

                      return CustomAudioBubble(
                        key: ValueKey(message.messageId),
                        // Unikal
                        uniqueId: message.messageId,
                        // Yangi
                        audioUrl: message.audioUrl ?? '',
                        isMe: isMe,
                        bubbleColor: bubbleColor,
                        textColor: textColor,
                        accentColor: accentColor,
                      );
                    }
                    if (message.type == 'image') {
                      return MessageandimagesDisplay(
                        isMe: isMe,
                        message: message,
                        widget: widget,
                      );
                    }
                    if (message.type == 'call') {
                      return Callhistory(
                        isMe: isMe,
                        widget: widget,
                        isMissed: isMissed,
                        isVideo: isVideo,
                        message: message,
                      );
                    }
                    if (isSystem) {
                      return Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
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
                      );
                    }
                    return MessageandimagesDisplay(
                      isMe: isMe,
                      message: message,
                      widget: widget,
                    );
                  },
                );
              },
            ),
          ),

          // ---------- INPUT BAR ----------
          Container(
            padding: const EdgeInsets.only(
              top: 5,
              right: 10,
              left: 10,
              bottom: 15,
            ),
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
                  onPressed: isUploading ? null : _showImageOptions,
                  icon: Icon(
                    Icons.image,
                    size: 30,
                    color: isUploading ? Colors.grey : Color(0xFF6a11cb),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    focusNode: _textFieldFocusNode,
                    decoration: InputDecoration(
                      hintText: 'Message...',
                      border: InputBorder.none,
                      fillColor: Colors.grey[100],
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                    onChanged: _handleTextChange,
                  ),
                ),
                const SizedBox(width: 8),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_isRecording)
                      AnimatedBuilder(
                        animation: _waveController,
                        builder: (context, _) {
                          final val = _waveController.value;
                          return Row(
                            children: List.generate(6, (i) {
                              final h = 10 + sin(val * pi * (i + 1)) * 10;
                              return Container(
                                width: 3,
                                height: h,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              );
                            }),
                          );
                        },
                      ),
                    GestureDetector(
                      onTap: isUploading
                          ? null
                          : () async {
                              if (_messageController.text.trim().isNotEmpty) {
                                await _sendMessage();
                                setState(() => _isRecording = false);
                              } else {
                                await _startOrStopRecording();
                              }
                            },
                      child: CircleAvatar(
                        radius: 25,
                        backgroundColor: _isRecording
                            ? Colors.redAccent
                            : Color(0xFF6a11cb),
                        child: isUploading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                _isRecording
                                    ? Icons.stop
                                    : (_messageController.text.trim().isEmpty
                                          ? Icons.mic
                                          : Icons.send),
                                color: Colors.white,
                                size: 26,
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
}
