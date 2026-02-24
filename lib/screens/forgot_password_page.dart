import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nubbill/config/supabase_config.dart';
import 'package:nubbill/widgets/rounded_button.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();

      await SupabaseConfig.client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'nubbill://reset-password',
      );

      if (mounted) {
        setState(() => _emailSent = true);
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_getThaiErrorMessage(e.message)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('เกิดข้อผิดพลาด กรุณาลองใหม่อีกครั้ง'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getThaiErrorMessage(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('rate limit') || lower.contains('too many')) {
      return 'ส่งคำขอมากเกินไป กรุณารอสักครู่แล้วลองใหม่';
    }
    if (lower.contains('not found') || lower.contains('user not found')) {
      return 'ไม่พบอีเมลนี้ในระบบ';
    }
    return 'เกิดข้อผิดพลาด กรุณาลองใหม่อีกครั้ง';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _emailSent ? _buildSuccessView() : _buildFormView(),
      ),
    );
  }

  Widget _buildFormView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ลืมรหัสผ่าน?',
          style: TextStyle(
            color: Color(0xFF81CEF2),
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'กรอกอีเมลที่ใช้สมัครสมาชิก เราจะส่งลิงก์สำหรับตั้งรหัสผ่านใหม่ให้คุณ',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        const SizedBox(height: 40),
        Form(
          key: _formKey,
          child: TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'กรุณากรอกอีเมล';
              }
              if (!value.contains('@')) {
                return 'กรุณากรอกอีเมลให้ถูกต้อง';
              }
              return null;
            },
            decoration: InputDecoration(
              hintText: 'กรอกอีเมล',
              hintStyle: const TextStyle(color: Colors.grey),
              filled: true,
              fillColor: const Color(0x1414161A),
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
                borderSide: const BorderSide(color: Colors.red, width: 2),
              ),
            ),
          ),
        ),
        const SizedBox(height: 40),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _isLoading
                ? const CircularProgressIndicator(color: Color(0xFF81CEF2))
                : RoundedButton(
                    text: 'ส่งลิงก์รีเซ็ตรหัสผ่าน',
                    backgroundColor: const Color(0xFF81CEF2),
                    textColor: Colors.white,
                    onPressed: _sendResetEmail,
                  ),
          ],
        ),
      ],
    );
  }

  Widget _buildSuccessView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Icon(
          Icons.mark_email_read_outlined,
          size: 80,
          color: Color(0xFF81CEF2),
        ),
        const SizedBox(height: 24),
        const Text(
          'ส่งอีเมลเรียบร้อยแล้ว!',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Text(
          'เราได้ส่งลิงก์สำหรับตั้งรหัสผ่านใหม่ไปที่\n${_emailController.text.trim()}\n\nกรุณาตรวจสอบกล่องจดหมายและกล่องจดหมายขยะ',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.6),
        ),
        const SizedBox(height: 40),
        RoundedButton(
          text: 'กลับไปหน้าเข้าสู่ระบบ',
          backgroundColor: const Color(0xFF81CEF2),
          textColor: Colors.white,
          onPressed: () => context.go('/login'),
        ),
      ],
    );
  }
}
