import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nubbill/providers/auth_provider.dart';
import 'package:nubbill/widgets/rounded_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    // final password = _passwordController.text; // Currently unused in Supabase Auth via Email Link

    try {
      // Using Riverpod controller
      await ref.read(authControllerProvider.notifier).signInWithEmail(email);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ส่งลิงก์เข้าสู่ระบบไปที่อีเมลแล้ว กรุณาตรวจสอบ'),
            backgroundColor: Colors.green,
          ),
        );
        // Navigate to OTP/Check Email page?
        // For now, Supabase magic link or OTP.
        // Prototype shows OTP input.
        // To support OTP, we need to call signInWithOtp which sends a code.
        // My AuthRepository.signInWithEmail implementation calls signInWithOtp.

        // Navigate to OTP verify page?
        // Or wait for link click (deep link).
        // Prototype Section 4 says "OTP Input". So we should navigate there.
        // But implementation plan says "Refactor Register/OTP Pages".
        // I'll assume we navigate to a verification page.

        // context.push('/verify-otp', extra: email);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final isLoading = state.isLoading;

    ref.listen<AsyncValue<void>>(authControllerProvider, (previous, next) {
      if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    });

    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.only(top: 60),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'พร้อมเคลียร์บิลทริปนี้หรือยัง?',
                  style: TextStyle(
                    color: Color(0xFF81CEF2),
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
                const SizedBox(height: 16),
                Text.rich(
                  TextSpan(
                    text: 'เข้าใช้งานเพื่อ ',
                    style: const TextStyle(fontSize: 14),
                    children: [
                      TextSpan(
                        text: 'ติดตามยอดใช้จ่าย และสรุปบิลทริป',
                        style: TextStyle(
                          color: const Color(0xFF81CEF2),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const Text('กับเพื่อนได้ทันที!'),
                const SizedBox(height: 40),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Email
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'กรุณากรอกอีเมล';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          hintText: 'กรอกอีเมล',
                          hintStyle: const TextStyle(color: Colors.grey),
                          filled: true,
                          fillColor: const Color(0xFFF5F5F5),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 20,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide.none,
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: const BorderSide(
                              color: Colors.red,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                      // Prototype Section 3 only asks for Email for OTP.
                      // Password field removed as per "Authentication - Email Input" prototype.
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    isLoading
                        ? const CircularProgressIndicator(
                            color: Color(0xFF81CEF2),
                          )
                        : RoundedButton(
                            text: 'รับรหัส OTP',
                            backgroundColor: const Color(0xFF81CEF2),
                            textColor: Colors.white,
                            onPressed: _signIn,
                          ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [const Text("หรือเข้าใช้งานด้วย")],
                ),
                // TODO: Add Social Login buttons
              ],
            ),
          ),
        ),
      ),
    );
  }
}
