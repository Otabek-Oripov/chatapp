import 'package:chatapp/screens/HomeScreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../function/Buttons.dart';
import '../function/snakbar.dart';
import '../providers/auth.provider.dart';
import '../services/auth.service.dart';
import 'Sign.Up_screen.dart';

class UserLoginScreen extends ConsumerWidget {
  const UserLoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final height = MediaQuery.of(context).size.height;
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
          description: "Successful Login",
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
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(
              height: height / 2.1,
              width: double.infinity,
              child: Image.asset(
                "assets/2752392.jpg",
                fit: BoxFit.cover,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                children: [
                  TextField(
                    autocorrect: false,
                    onChanged: formNotifier.updateEmail,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.email),
                      labelText: "Enter your email",
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.all(15),
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
                      contentPadding: const EdgeInsets.all(15),
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
                    onTap: formState.isFormValid ? login : null,
                    buttonText: "Login",
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: const [
                      Expanded(child: Divider(color: Colors.black26)),
                      Text(" or "),
                      Expanded(child: Divider(color: Colors.black26)),
                    ],
                  ),
                  const SizedBox(height: 15),
                  // Google login placeholder
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Don't have an account? "),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SignupScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          "Sign Up",
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
