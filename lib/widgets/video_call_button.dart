import 'package:chatapp/providers/provide.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zego_uikit/zego_uikit.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';

ZegoSendCallInvitationButton actionButton(
    bool isVideo,
    String receiverId,
    String receiverName,
    WidgetRef ref,
    String chatId,
    ) {
  return ZegoSendCallInvitationButton(
    isVideoCall: isVideo,
    resourceID: 'zego_call', // must match resourceID in Zego console if using push
    iconSize: const Size(30, 30),
    buttonSize: const Size(40, 40),

    invitees: [
      ZegoUIKitUser(
        id: receiverId,      // 🔥 this must equal callee's userID used in init
        name: receiverName,
      ),
    ],

    onPressed: (String code, String message, List<String> errorInvitees) async {
      debugPrint(
          'SendCallInvitationButton onPressed -> code=$code, message=$message, errorInvitees=$errorInvitees');

      final chatService = ref.read(chatServiceProvider);

      if (errorInvitees.isNotEmpty || code != '0') {
        // code '0' usually means success
        debugPrint('Error inviting users: $errorInvitees');
        // you could also show a snackbar here if you want
      } else {
        debugPrint('Call invitation sent successfully');

        await chatService.addCallHistory(
          chatId: chatId,
          isVideoCall: isVideo,
          callStatus: 'pending', // or "ringing"
        );
      }
    },
  );
}
