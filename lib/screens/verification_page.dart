import 'dart:async';
import 'package:flutter/material.dart';
import 'package:nubbill/shared/app_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nubbill/config/supabase_config.dart';
import 'package:nubbill/screens/home_page.dart';

class VerificationPage extends StatefulWidget {
  final String email;
  final String nickname;

  const VerificationPage({
    super.key,
    required this.email,
    required this.nickname,
  });

  @override
  State<VerificationPage> createState() => _VerificationPageState();
}

class _VerificationPageState extends State<VerificationPage> {
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  int _secondsRemaining = 0;
  Timer? _timer;
  bool _isVerifying = false;
  bool _isResending = false;

  @override
  void initState() {
    super.initState();
    // Auto-focus the hidden field so keyboard appears
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _otpController.dispose();
    _focusNode.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    setState(() {
      _secondsRemaining = 60; // 1 minute for email
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        _stopTimer();
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    setState(() {
      _secondsRemaining = 0;
    });
  }

  String get _timerText {
    final minutes = (_secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsRemaining % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  /// Mask email for display
  String get _maskedEmail {
    final email = widget.email;
    final atIndex = email.indexOf('@');
    if (atIndex > 2) {
      return '${email.substring(0, 2)}***${email.substring(atIndex)}';
    }
    return email;
  }

  /// Verify the OTP code and navigate to home on success
  Future<void> _verifyOtp(String otp) async {
    if (otp.length != 8) return;

    setState(() => _isVerifying = true);

    try {
      final response = await SupabaseConfig.client.auth.verifyOTP(
        email: widget.email,
        token: otp,
        type: OtpType.email,
      );

      if (response.user != null && mounted) {
        // Successfully verified - navigate to home with session
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
          (route) => false, // Remove all previous routes
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        final thaiMessage = _getThaiErrorMessage(e.message);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(thaiMessage), backgroundColor: Colors.red),
          // SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
        // Clear the OTP input
        _otpController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('เกิดข้อผิดพลาด กรุณาลองใหม่อีกครั้ง'),
            backgroundColor: Colors.red,
          ),
        );
        _otpController.clear();
      }
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  /// Translate Supabase error messages to Thai
  String _getThaiErrorMessage(String message) {
    final lowerMessage = message.toLowerCase();

    if (lowerMessage.contains('token has expired or is invalid')) {
      return 'รหัส OTP ไม่ถูกน้า ลองตรวจสอบอีกครั้งนะ';
    }
    if (lowerMessage.contains('too many requests') ||
        lowerMessage.contains('rate limit')) {
      return 'ส่งคำขอมากเกินไปละน้า รอสักครู่แล้วลองใหม่เด้อ';
    }
    if (lowerMessage.contains('user not found') ||
        lowerMessage.contains('email not found')) {
      return 'ไม่พบอีเมลนี้ในระบบ';
    }
    if (lowerMessage.contains('network') ||
        lowerMessage.contains('connection')) {
      return 'ไม่สามารถเชื่อมต่อได้ ลองตรวจสอบอินเทอร์เน็ตก่อนนะ';
    }

    // Default message
    return 'เกิดข้อผิดพลาดน้า กรุณาลองใหม่อีกครั้งจ้า';
  }

  /// Resend OTP code
  Future<void> _resendOtp() async {
    if (_secondsRemaining > 0 || _isResending) return;

    setState(() => _isResending = true);

    try {
      await SupabaseConfig.client.auth.resend(
        type: OtpType.signup,
        email: widget.email,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ส่งรหัส OTP ใหม่ไปที่อีเมลแล้ว'),
            backgroundColor: Colors.green,
          ),
        );
        _startResendTimer();
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(AppIcons.close),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            const Text(
              'กรอกรหัสยืนยันจากอีเมล',
              style: TextStyle(
                color: Color.fromARGB(255, 129, 206, 242),
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ป้อนรหัส 8 หลักที่เราส่งไปทางอีเมล\n$_maskedEmail',
              style: TextStyle(
                fontSize: 14,
                color: const Color(0xFF141416).withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 40),
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Hidden TextField
                  Opacity(
                    opacity: 0.0,
                    child: TextField(
                      controller: _otpController,
                      focusNode: _focusNode,
                      keyboardType: TextInputType.number,
                      maxLength: 8,
                      onChanged: (value) {
                        setState(() {});
                        if (value.length == 8) {
                          _verifyOtp(value);
                        }
                      },
                      decoration: const InputDecoration(counterText: ''),
                    ),
                  ),
                  // Visual OTP Boxes (8 digits)
                  GestureDetector(
                    onTap: () {
                      _focusNode.requestFocus();
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(8, (index) {
                        final digit = _otpController.text.length > index
                            ? _otpController.text[index]
                            : '';
                        return Container(
                          width: 36,
                          height: 48,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF141416,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: digit.isNotEmpty
                                  ? const Color.fromARGB(255, 129, 206, 242)
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child:
                                _isVerifying &&
                                    index == _otpController.text.length - 1
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color.fromARGB(255, 129, 206, 242),
                                    ),
                                  )
                                : Text(
                                    digit,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'ไม่ได้รับรหัสใช่ไหม? ',
                  style: TextStyle(
                    color: const Color(0xFF141416).withValues(alpha: 0.7),
                  ),
                ),
                GestureDetector(
                  onTap: _secondsRemaining > 0 || _isResending
                      ? null
                      : _resendOtp,
                  child: _isResending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color.fromARGB(255, 129, 206, 242),
                          ),
                        )
                      : Text(
                          _secondsRemaining > 0
                              ? _timerText
                              : 'ส่งรหัสอีกครั้ง',
                          style: TextStyle(
                            color: _secondsRemaining > 0
                                ? const Color(0xFF141416).withValues(alpha: 0.7)
                                : const Color.fromARGB(255, 129, 206, 242),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                'กรุณาตรวจสอบกล่องจดหมายขยะด้วยนะ',
                style: TextStyle(
                  fontSize: 12,
                  color: const Color(0xFF141416).withValues(alpha: 0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
