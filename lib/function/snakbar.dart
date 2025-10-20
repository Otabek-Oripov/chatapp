import 'package:flutter/material.dart';

enum SnackbarType { success, error, info }

void showAppSnackbar({
  required BuildContext context,
  required SnackbarType type,
  required String description,
}) {
  // Avval eski snackbarlarni yopamiz (to‘planmasin)
  ScaffoldMessenger.of(context).hideCurrentSnackBar();

  // Snackbar rangini tanlaymiz
  Color bgColor;
  switch (type) {
    case SnackbarType.success:
      bgColor = Colors.green;
      break;
    case SnackbarType.error:
      bgColor = Colors.red;
      break;
    case SnackbarType.info:
    default:
      bgColor = Colors.blue;
  }

  final snackBar = SnackBar(
    content: Text(
      description,
      style: const TextStyle(color: Colors.white),
    ),
    backgroundColor: bgColor,
    behavior: SnackBarBehavior.floating,
    duration: const Duration(seconds: 3),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
    ),
  );

  // Snackbar’ni ko‘rsatamiz
  ScaffoldMessenger.of(context).showSnackBar(snackBar);
}
