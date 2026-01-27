import 'package:flutter/material.dart';
import 'package:nubbill/widgets/rounded_button.dart';
import 'package:nubbill/screens/register_page.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'พร้อมเคลียร์บิลทริปนี้หรือยัง?',
                style: TextStyle(
                  color: Color.fromARGB(255, 129, 206, 242),
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
              SizedBox(height: 16),
              Text.rich(
                TextSpan(
                  text: 'เข้าใช้งานเพื่อ ',
                  style: TextStyle(fontSize: 14),
                  children: [
                    TextSpan(
                      text: 'ติดตามยอดใช้จ่าย และสรุปบิลทริป',
                      style: TextStyle(
                        color: const Color.fromARGB(255, 129, 206, 242),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const Text('กับเพื่อนได้ทันที!'),
              SizedBox(height: 40),
              Form(
                child: Column(
                  children: [
                    // Email
                    TextFormField(
                      decoration: InputDecoration(
                        hintText: 'กรอกเบอร์โทร',
                        hintStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: Color(0x1414161A),
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
                          borderSide: const BorderSide(
                            color: const Color.fromARGB(255, 129, 206, 242),
                            width: 2,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Password
                    TextFormField(
                      obscureText: true,
                      decoration: InputDecoration(
                        hintText: 'รหัสผ่าน',
                        hintStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: Color(0x1414161A),
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
                          borderSide: const BorderSide(
                            color: Color.fromARGB(255, 129, 206, 242),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 5),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'จำรหัสผ่านไม่ได้?',
                  style: TextStyle(color: const Color.fromARGB(255, 129, 206, 242)),
                ),
              ),

              SizedBox(height: 40),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  RoundedButton(
                    text: 'เริ่มหารบิลกันเลย!',
                    backgroundColor: const Color.fromARGB(255, 129, 206, 242),
                    textColor: Colors.white,
                    onPressed: () {
                      // Navigator.push(
                      //   context,
                      //   MaterialPageRoute(builder: (_) => LoginPage()),
                      // );
                    },
                  ),
                ],
              ),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("ยังไม่มีบัญชี?"),
                  SizedBox(width: 5),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RegisterPage(),
                        ),
                      );
                    },
                    child: const Text(
                      'สมัครบัญชีใหม่',
                      style: TextStyle(
                        color: Color.fromARGB(255, 129, 206, 242),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
