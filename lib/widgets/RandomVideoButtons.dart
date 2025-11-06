// // lib/widgets/tutoring_call_button.dart
// import 'package:flutter/material.dart';
// import 'package:zego_uikit/zego_uikit.dart';
// import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
//
// /// 1-on-1 Tutoring (Random Chat) uchun chaqiruv tugmasi — YANGI PROJECT (448607128)
// Widget tutoringCallButton({
//   required String receiverId,
//   required String receiverName,
//   required BuildContext context,
// }) {
//   return ZegoSendCallInvitationButton(
//     isVideoCall: true,
//     resourceID: 'zego_uikit_call',
//     iconSize: const Size(60, 60),
//     buttonSize: const Size(80, 80),
//     icon: ButtonIcon(
//       icon: Icon(Icons.video_call, color: Colors.white, size: 40),
//     ),
//     invitees: [
//       ZegoUIKitUser(id: receiverId, name: receiverName),
//     ],
//
//     // YANGI PROJECT — TO‘G‘RIDAN-TO‘G‘RI YOZAMIZ!
//     appID: 448607128,
//     appSign: "0078f2d636d85815818a894d1a17c6400ac54cd597daaa77835c7f20e72da0ac",
//
//     timeoutSeconds: 60,
//
//     onPressed: (String code, String message, List<String> errorInvitees) {
//       if (errorInvitees.isNotEmpty) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text("Call yuborilmadi: $errorInvitees")),
//         );
//       } else {
//         debugPrint("TUTORING CALL YUBORILDI → $receiverName");
//       }
//     },
//   );
// }