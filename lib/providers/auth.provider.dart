import 'package:flutter_riverpod/legacy.dart';

import '../models/auth.model.dart';
class AuthFormNotifier extends StateNotifier<AuthFormState> {
  AuthFormNotifier() : super(AuthFormState());
  void togglePasswordVisibility() {
    state = state.copyWith(isPasswordHidden: !state.isPasswordHidden);
  }
  void updateName(String name) {
    String? nameError;
    if (name.isNotEmpty && name.length < 6) {
      nameError = "Provide your full name";
    }
    state = state.copyWith(name: name, nameError: nameError);
  }
  void updateEmail(String email) {
    String? emailError;
    if (email.isNotEmpty &&
        !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      emailError = 'Enter a valid email';
    }
    state = state.copyWith(email: email, emailError: emailError);
  }
  void updatePassword(String password) {
    String? passwordError;
    if (password.isNotEmpty && password.length < 6) {
      passwordError = 'Password must be at least 6 characters';
    }
    state = state.copyWith(password: password, passwordError: passwordError);
  }
  void setLoading(bool isLoading) {
    state = state.copyWith(isLoading: isLoading);
  }
}
final authFormProvider = StateNotifierProvider<AuthFormNotifier, AuthFormState>(
      (ref) {
    return AuthFormNotifier();
  },
);