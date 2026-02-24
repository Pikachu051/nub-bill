import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nubbill/providers/auth_provider.dart';
import 'package:nubbill/widgets/rounded_button.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final String email;

  const OtpScreen({super.key, required this.email});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  Timer? _timer;
  int _start = 60;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    setState(() {
      _start = 60;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_start == 0) {
        setState(() {
          timer.cancel();
        });
      } else {
        setState(() {
          _start--;
        });
      }
    });
  }

  void _onDigitChanged(int index, String value) {
    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }

    // Check if full
    final otp = _controllers.map((c) => c.text).join();
    if (otp.length == 6) {
      _verifyOtp();
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _controllers.map((c) => c.text).join();
    if (otp.length != 6) return;

    try {
      await ref
          .read(authControllerProvider.notifier)
          .verifyOtp(widget.email, otp);
      // Navigation is handled by router redirect based on auth state + logic
      // But we might need to check if user has nickname.
      // If user is logged in, router redirects to /home.
      // We need to check for nickname to redirect to /nickname.
      // This logic will be in router redirect.
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('รหัส OTP ไม่ถูกต้อง: $e'),
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
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('กรอกรหัส OTP'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Text(
              'ส่งไปที่ ${widget.email}',
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(6, (index) {
                return SizedBox(
                  width: 45,
                  height: 55,
                  child: TextField(
                    cursorColor: const Color(0xFF141416),
                    controller: _controllers[index],
                    focusNode: _focusNodes[index],
                    autofocus: index == 0,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    maxLength: 1,
                    decoration: InputDecoration(
                      counterText: '',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFFBDBDBD),
                          width: 1,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFFBDBDBD),
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFFBDBDBD),
                          width: 1,
                        ),
                      ),
                    ),
                    onChanged: (value) => _onDigitChanged(index, value),
                  ),
                );
              }),
            ),
            const SizedBox(height: 32),
            Text(
              'ส่งใหม่ได้ใน 00:${_start.toString().padLeft(2, '0')}',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            if (_start == 0)
              TextButton(
                onPressed: () {
                  // Resend OTP logic
                  ref
                      .read(authControllerProvider.notifier)
                      .signInWithEmail(widget.email);
                  _startTimer();
                },
                child: const Text('ส่งรหัสใหม่'),
              ),
            const Spacer(),
            isLoading
                ? const CircularProgressIndicator()
                : RoundedButton(
                    text: 'ยืนยัน',
                    backgroundColor: primaryColor,
                    textColor: Colors.white,
                    onPressed: _verifyOtp,
                  ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
