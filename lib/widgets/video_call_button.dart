import 'package:flutter/material.dart';
import 'package:zego_uikit/zego_uikit.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';

ZegoSendCallInvitationButton actionButton(
    bool isVideo,
    String receiverId,
    String receiverName,
    ) {
  return ZegoSendCallInvitationButton(
    isVideoCall: isVideo,
    resourceID: 'zego_call', // Zego konsolda kiritilgan resource ID
    iconSize: const Size(30, 30),
    buttonSize: const Size(40, 40),

    // 🔹 To‘g‘ri: ZegoUIKitUser ishlatiladi, ZegoUiKit emas
    invitees: [
      ZegoUIKitUser(
        id: receiverId,
        name: receiverName,
      ),
    ],

    onPressed: (String code, String message, List<String> errorInvitees) {
      if (errorInvitees.isNotEmpty) {
        debugPrint('Error inviting users: $errorInvitees');
      } else {
        debugPrint('Call invitation sent successfully.');
      }
    },
  );
}
