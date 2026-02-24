import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nubbill/providers/auth_provider.dart';
import 'package:nubbill/widgets/rounded_button.dart';

class NicknameScreen extends ConsumerStatefulWidget {
  const NicknameScreen({super.key});

  @override
  ConsumerState<NicknameScreen> createState() => _NicknameScreenState();
}

class _NicknameScreenState extends ConsumerState<NicknameScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController();

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _saveNickname() async {
    if (!_formKey.currentState!.validate()) return;

    final nickname = _nicknameController.text.trim();

    try {
      await ref.read(authControllerProvider.notifier).updateNickname(nickname);

      if (mounted) {
        // Router redirect should handle navigation to home once nickname is set (if we add logic for it)
        // Or we can simple go to home
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
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
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'ยินดีต้อนรับ! 🎉',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text('ตั้งชื่อเล่นของคุณ', style: TextStyle(fontSize: 18)),
              const SizedBox(height: 32),
              Form(
                key: _formKey,
                child: TextFormField(
                  controller: _nicknameController,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'กรุณากรอกชื่อเล่น';
                    }
                    if (value.length < 2) {
                      return 'ชื่อเล่นต้องมีอย่างน้อย 2 ตัวอักษร';
                    }
                    if (value.length > 30) {
                      return 'ชื่อเล่นต้องไม่เกิน 30 ตัวอักษร';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.person_outline),
                    label: const Text('ชื่อเล่น'),
                    hintText: 'เพื่อนๆ จะเห็นชื่อนี้',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFFBDBDBD),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 48),
              isLoading
                  ? const CircularProgressIndicator()
                  : RoundedButton(
                      text: 'เริ่มใช้งาน',
                      backgroundColor: primaryColor,
                      textColor: Colors.white,
                      onPressed: _saveNickname,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
