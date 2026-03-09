import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/rounded_button.dart';

class AuthenticationPage extends StatelessWidget {
  const AuthenticationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            RoundedButton(
              text: 'สมัครบัญชีใหม่',
              backgroundColor: const Color.fromARGB(255, 129, 206, 242),
              textColor: Colors.white,

              onPressed: () => context.push('/register'),
            ),
            const SizedBox(height: 16),
            RoundedButton(
              text: 'ลงชื่อเข้าใช้',
              backgroundColor: Colors.white,
              textColor: const Color.fromARGB(255, 129, 206, 242),
              outlined: true,
              onPressed: () => context.push('/login'),
            ),
          ],
        ),
      ),
    );
  }
}
