import 'package:chatapp/models/MessageModel.dart';
import 'package:chatapp/screens/chat/chat_screen.dart';
import 'package:chatapp/services/timeFormat.dart';
import 'package:flutter/material.dart';

class Callhistory extends StatelessWidget {
  final bool isMe;
  final ChatScreen widget;
  final bool isMissed;
  final bool isVideo;
  final MessageModel message;

  const Callhistory({
    super.key,
    required this.isMe,
    required this.widget,
    required this.isMissed,
    required this.isVideo,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        mainAxisAlignment:
        isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
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
              )
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isMissed
                  ? Colors.red.withOpacity(0.15)
                  : Colors.green.withOpacity(0.15),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: isMissed ? Colors.red : Colors.green,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isVideo ? Icons.videocam : Icons.call,
                  color: isMissed ? Colors.red : Colors.green,
                ),
                const SizedBox(width: 6),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isMissed
                          ? (isMe ? 'Call not answered' : "Missed call")
                          : "${isVideo ? 'Video' : 'Audio'} call",
                      style: TextStyle(
                        color: isMissed ? Colors.red : Colors.green,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      formateMessageTime(message.timestamp),
                      style: TextStyle(
                        color: (isMissed ? Colors.red : Colors.green)
                            .withOpacity(0.7),
                        fontSize: 10,
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
}
