import 'dart:async';
import 'package:flutter/material.dart';

class VerificationPage extends StatefulWidget {
  const VerificationPage({super.key});

  @override
  State<VerificationPage> createState() => _VerificationPageState();
}

class _VerificationPageState extends State<VerificationPage> {
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  int _secondsRemaining = 0;
  Timer? _timer;

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
      _secondsRemaining = 300; // 5 minutes
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
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
              'กรอกรหัสยืนยันจาก SMS',
              style: TextStyle(
                color: Color.fromARGB(255, 129, 206, 242),
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ป้อนรหัส 4 หลักที่เราส่งไปทาง SMS ที่เบอร์\n081-xxx-xxxx',
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
                      maxLength: 4,
                      onChanged: (value) {
                        setState(() {});
                        if (value.length == 4) {
                          // Handle OTP completion
                          print("OTP Filled: $value");
                        }
                      },
                      decoration: const InputDecoration(counterText: ''),
                    ),
                  ),
                  // Visual OTP Boxes
                  GestureDetector(
                    onTap: () {
                      _focusNode.requestFocus();
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(4, (index) {
                        final digit = _otpController.text.length > index
                            ? _otpController.text[index]
                            : '';
                        return Container(
                          width: 60,
                          height: 60,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
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
                            child: Text(
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
                  onTap: _secondsRemaining > 0 ? null : _startResendTimer,
                  child: Text(
                    _secondsRemaining > 0 ? _timerText : 'ส่งรหัสอีกครั้ง',
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
          ],
        ),
      ),
    );
  }
}
