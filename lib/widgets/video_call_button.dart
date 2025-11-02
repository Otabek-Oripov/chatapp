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
    resourceID: 'zego_call', // o'z ZEGOCLOUD resource ID'ingni yoz
    iconSize: const Size(30, 30),
    buttonSize: const Size(40, 40),

    invitees: [
      ZegoUIKitUser(
        id: receiverId,
        name: receiverName,
      ),
    ],

    // chaqirilganda ishlaydigan event
    onPressed: (String code, String message, List<String> errorInvitees) async {
      final chatService = ref.read(chatServiceProvider);

      if (errorInvitees.isNotEmpty) {
        debugPrint('Error inviting users: $errorInvitees');
      } else {
        debugPrint('Call invitation sent successfully');

        // Firestore tarixga yozish
        await chatService.addCallHistory(
          chatId: chatId,
          isVideoCall: isVideo,
          callStatus: 'pending', // boshlanishida “pending” yoki “ringing”
        );
      }
    },
  );
}
