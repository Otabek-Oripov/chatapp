
import 'package:chatapp/screens/HomeScreen.dart';
import 'package:chatapp/screens/LoginScreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../function/snakbar.dart';
import '../providers/auth.provider.dart';
import '../services/auth.service.dart';

class SignupScreen extends ConsumerWidget {
  const SignupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formState = ref.watch(authFormProvider);
    final formNotifier = ref.read(authFormProvider.notifier);
    final authMethod = ref.read(authMethodProvider);

    Future<void> signup() async {
      formNotifier.setLoading(true);
      final res = await authMethod.signUpUser(
        email: formState.email,
        password: formState.password,
        name: formState.name,
      );

      if (!context.mounted) return;
      formNotifier.setLoading(false);

      if (res == "success") {
        showAppSnackbar(
          context: context,
          type: SnackbarType.success,
          description: "Muvaffaqiyatli ro‘yxatdan o‘tdingiz!",
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const Homescreen()),
        );
      } else {
        showAppSnackbar(
          context: context,
          type: SnackbarType.error,
          description: res,
        );
      }
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF6a11cb), Color(0xFF2575fc)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  // Logo
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.chat_bubble,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Hisob yarating",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Glass Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildTextField(
                          icon: Icons.person,
                          label: "To‘liq ismingiz",
                          onChanged: formNotifier.updateName,
                          errorText: formState.nameError,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          icon: Icons.email,
                          label: "Email",
                          keyboardType: TextInputType.emailAddress,
                          onChanged: formNotifier.updateEmail,
                          errorText: formState.emailError,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          icon: Icons.lock,
                          label: "Parol",
                          obscureText: formState.isPasswordHidden,
                          onChanged: formNotifier.updatePassword,
                          errorText: formState.passwordError,
                          suffixIcon: IconButton(
                            icon: Icon(
                              formState.isPasswordHidden
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.white70,
                            ),
                            onPressed: formNotifier.togglePasswordVisibility,
                          ),
                        ),
                        const SizedBox(height: 24),
                        formState.isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: const Color(0xFF6a11cb),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 8,
                                  ),
                                  onPressed: formState.isFormValid
                                      ? signup
                                      : null,
                                  child: const Text(
                                    "RO‘YXATDAN O‘TISH",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Allaqachon hisobingiz bormi? ",
                        style: TextStyle(color: Colors.white70),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const UserLoginScreen(),
                          ),
                        ),
                        child: const Text(
                          "Kirish",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required IconData icon,
    required String label,
    TextInputType? keyboardType,
    bool obscureText = false,
    required Function(String) onChanged,
    String? errorText,
    Widget? suffixIcon,
  }) {
    return TextField(
      keyboardType: keyboardType,
      obscureText: obscureText,
      onChanged: onChanged,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.white70),
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        errorText: errorText,
        errorStyle: const TextStyle(color: Colors.orange),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.white38),
          borderRadius: BorderRadius.circular(16),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.white),
          borderRadius: BorderRadius.circular(16),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.orange),
          borderRadius: BorderRadius.circular(16),
        ),
        suffixIcon: suffixIcon,
      ),
    );
  }
}
