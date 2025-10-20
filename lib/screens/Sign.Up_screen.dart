import 'package:chatapp/screens/HomeScreen.dart';
import 'package:chatapp/screens/LoginScreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../function/Buttons.dart';
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
          description: "Account created successfully! Welcome",
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

    final height = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          children: [
            Container(
              height: height / 2.4,
              width: double.infinity,
              decoration: const BoxDecoration(),
              child: Image.asset("assets/77881.jpg", fit: BoxFit.cover),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                children: [
                  TextField(
                    autocorrect: false,
                    onChanged: formNotifier.updateName,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.person),
                      labelText: "Enter your name",
                      border: const OutlineInputBorder(),
                      errorText: formState.nameError,
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    autocorrect: false,
                    onChanged: formNotifier.updateEmail,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.email),
                      labelText: "Enter your email",
                      border: const OutlineInputBorder(),
                      errorText: formState.emailError,
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    autocorrect: false,
                    onChanged: formNotifier.updatePassword,
                    obscureText: formState.isPasswordHidden,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.lock),
                      labelText: "Enter your password",
                      border: const OutlineInputBorder(),
                      errorText: formState.passwordError,
                      suffixIcon: IconButton(
                        onPressed: formNotifier.togglePasswordVisibility,
                        icon: Icon(
                          formState.isPasswordHidden
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  formState.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : MyButton(
                    onTap: formState.isFormValid ? signup : null,
                    buttonText: "Sign Up",
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Already have an account? "),
                      GestureDetector(
                        onTap: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => const UserLoginScreen()),
                          );
                        },
                        child: const Text(
                          "Login",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
