import 'package:flutter/material.dart';
import 'package:nubbill/shared/app_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nubbill/config/supabase_config.dart';
import 'package:nubbill/widgets/rounded_button.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await SupabaseConfig.client.auth.updateUser(
        UserAttributes(password: _passwordController.text),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('เปลี่ยนรหัสผ่านสำเร็จ!'),
            backgroundColor: Colors.green,
          ),
        );
        // Navigate to home after successful reset
        context.go('/home');
      }
    } on AuthException catch (e) {
      if (mounted) {
        String message = 'เกิดข้อผิดพลาด กรุณาลองใหม่อีกครั้ง';
        final lower = e.message.toLowerCase();
        if (lower.contains('same password') ||
            lower.contains('should be different')) {
          message = 'รหัสผ่านใหม่ต้องไม่ซ้ำกับรหัสผ่านเดิม';
        } else if (lower.contains('weak password') ||
            lower.contains('too short')) {
          message = 'รหัสผ่านสั้นเกินไป กรุณาใช้อย่างน้อย 6 ตัวอักษร';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text('ตั้งรหัสผ่านใหม่'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ตั้งรหัสผ่านใหม่',
              style: TextStyle(
                color: Color(0xFF81CEF2),
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'กรอกรหัสผ่านใหม่ที่ต้องการใช้',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 40),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'กรุณากรอกรหัสผ่านใหม่';
                      }
                      if (value.length < 6) {
                        return 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร';
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      hintText: 'รหัสผ่านใหม่',
                      hintStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: const Color(0x1414161A),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 20,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? AppIcons.visibilityOff
                              : AppIcons.visibility,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
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
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirm,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'กรุณายืนยันรหัสผ่าน';
                      }
                      if (value != _passwordController.text) {
                        return 'รหัสผ่านไม่ตรงกัน';
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      hintText: 'ยืนยันรหัสผ่านใหม่',
                      hintStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: const Color(0x1414161A),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 20,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirm
                              ? AppIcons.visibilityOff
                              : AppIcons.visibility,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          setState(() => _obscureConfirm = !_obscureConfirm);
                        },
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
                ],
              ),
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _isLoading
                    ? const CircularProgressIndicator(color: Color(0xFF81CEF2))
                    : RoundedButton(
                        text: 'ยืนยันรหัสผ่านใหม่',
                        backgroundColor: const Color(0xFF81CEF2),
                        textColor: Colors.white,
                        onPressed: _resetPassword,
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
