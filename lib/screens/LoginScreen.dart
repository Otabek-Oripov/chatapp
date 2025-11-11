// lib/screens/LoginScreen.dart — TO‘LIQ ALMASHTIRING!
import 'package:chatapp/screens/HomeScreen.dart';
import 'package:chatapp/screens/Sign.Up_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../function/snakbar.dart';
import '../providers/auth.provider.dart';
import '../services/auth.service.dart';

class UserLoginScreen extends ConsumerWidget {
  const UserLoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formState = ref.watch(authFormProvider);
    final formNotifier = ref.read(authFormProvider.notifier);
    final authMethod = ref.read(authMethodProvider);

    Future<void> login() async {
      formNotifier.setLoading(true);
      final res = await authMethod.loginUser(
        email: formState.email,
        password: formState.password,
      );
      if (!context.mounted) return;
      formNotifier.setLoading(false);

      if (res == "success") {
        showAppSnackbar(
          context: context,
          type: SnackbarType.success,
          description: "Xush kelibsiz!",
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
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFff6b6b), Color(0xFFfeca57)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 50),
                  Container(
                    padding: const EdgeInsets.all(25),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.black26, blurRadius: 20),
                      ],
                    ),
                    child: const Icon(
                      Icons.flutter_dash,
                      size: 80,
                      color: Color(0xFFff6b6b),
                    ),
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    "Xush kelibsiz!",
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Text(
                    "Yana uchrashganimizdan xursandmiz",
                    style: TextStyle(fontSize: 18, color: Colors.white70),
                  ),
                  const SizedBox(height: 50),

                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        // EMAIL
                        _buildField(
                          icon: Icons.email,
                          label: "Email",
                          onChanged: formNotifier.updateEmail,
                          error: formState.emailError,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 20),

                        // PAROL — TO‘G‘RI USUL!
                        _buildField(
                          icon: Icons.lock,
                          label: "Parol",
                          onChanged: formNotifier.updatePassword,
                          error: formState.passwordError,
                          obscure: formState.isPasswordHidden,
                          // TO‘G‘RI
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
                        const SizedBox(height: 30),

                        formState.isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : SizedBox(
                                width: double.infinity,
                                height: 60,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: const Color(0xFFff6b6b),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    elevation: 10,
                                  ),
                                  onPressed: formState.isFormValid
                                      ? login
                                      : null,
                                  child: const Text(
                                    "KIRISH",
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ),
                              ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Hisobingiz yo‘qmi? ",
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SignupScreen(),
                          ),
                        ),
                        child: const Text(
                          "Ro‘yxatdan o‘tish",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
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

  // TO‘G‘RI _buildField — NOMLI PARAMETRLAR!
  Widget _buildField({
    required IconData icon,
    required String label,
    required Function(String) onChanged,
    String? error,
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? suffixIcon,
  }) {
    return TextField(
      keyboardType: keyboardType,
      obscureText: obscure,
      onChanged: onChanged,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.white70),
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        errorText: error,
        errorStyle: const TextStyle(color: Colors.yellow),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.white38),
          borderRadius: BorderRadius.circular(16),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.white),
          borderRadius: BorderRadius.circular(16),
        ),
        suffixIcon: suffixIcon,
      ),
    );
  }
}
