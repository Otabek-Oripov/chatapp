import 'package:chatapp/models/MessageModel.dart';
import 'package:chatapp/screens/chat/chat_screen.dart';
import 'package:chatapp/services/timeFormat.dart';
import 'package:chatapp/widgets/image_ful_screen.dart';
import 'package:chatapp/widgets/messageStatus.dart';
import 'package:flutter/material.dart';

class MessageandimagesDisplay extends StatelessWidget {
  final bool isMe;
  final ChatScreen widget;
  final MessageModel message;

  const MessageandimagesDisplay({
    super.key,
    required this.isMe,
    required this.widget,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              backgroundImage: widget.othersUser.photoUrl != null
                  ? NetworkImage(widget.othersUser.photoUrl!)
                  : null,
              child: widget.othersUser.photoUrl == null
                  ? Text(
                widget.othersUser.name.isNotEmpty
                    ? widget.othersUser.name[0].toUpperCase()
                    : "U",
                style: TextStyle(color: Colors.white),
              )
                  : null,
              backgroundColor: widget.othersUser.photoUrl == null
                  ? const Color(0xFF6a11cb)
                  : null,

            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: message.type == 'image'
                  ? const EdgeInsets.all(4) // Rasmlar uchun kichik padding
                  : const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? Color(0xFF6a11cb) : Colors.grey[300],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Image
                  if (message.type == 'image' && message.imageUrl != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: GestureDetector(
                        onTap: () => showFullScreenImage(message.imageUrl!, context),
                        child: Container(
                          constraints: const BoxConstraints(
                            maxHeight: 300,
                            maxWidth: 250,
                          ),
                          child: Image.network(
                            message.imageUrl!,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const SizedBox(
                                height: 200,
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                height: 200,
                                color: Colors.grey[300],
                                child: const Icon(
                                  Icons.broken_image,
                                  size: 50,
                                  color: Colors.grey,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],

                  // Text message (if any)
                  if (message.message.isNotEmpty) ...[
                    if (message.type == 'image') const SizedBox(height: 6),
                    Padding(
                      padding: message.type == 'image'
                          ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
                          : EdgeInsets.zero,
                      child: Text(
                        message.message,
                        style: TextStyle(
                          color: isMe ? Colors.white : Colors.black,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],

                  // Time + Status
                  Padding(
                    padding: message.type == 'image'
                        ? const EdgeInsets.only(right: 8, top: 4, bottom: 4)
                        : const EdgeInsets.only(top: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          formateMessageTime(message.timestamp),
                          style: TextStyle(
                            fontSize: 10,
                            color: isMe ? Colors.white70 : Colors.black54,
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 4),
                          buildMessageStatusIcon(message, widget.othersUser.uid),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

