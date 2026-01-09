import 'package:flutter/material.dart';
import 'package:nubbill/pages/verification_page.dart';
import 'package:nubbill/widgets/rounded_button.dart';

class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});

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
                'ยินดีต้อนรับ! ผมนับบิล',
                style: TextStyle(
                  color: Color.fromARGB(255, 129, 206, 242),
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
              SizedBox(height: 16),
              Text.rich(
                TextSpan(
                  text: 'สมัครสมาชิกเพื่อให้เราช่วยดูแล',
                  style: TextStyle(fontSize: 14),
                  children: [
                    TextSpan(
                      text: 'เรื่องตัวเลขในทุกมื้อ',
                      style: TextStyle(
                        color: Color.fromARGB(255, 129, 206, 242),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const Text('คุณแค่เที่ยว เรื่องหารบิลเราจัดการเอง!'),
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
                            color: Color.fromARGB(255, 129, 206, 242),
                            width: 2,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    TextFormField(
                      decoration: InputDecoration(
                        hintText: 'กรอกชื่อเล่น',
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

              SizedBox(height: 40),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  RoundedButton(
                    text: 'รับรหัสยืนยันทาง SMS',
                    backgroundColor: const Color.fromARGB(255, 129, 206, 242),
                    textColor: Colors.white,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => VerificationPage()),
                      );
                    },
                  ),
                ],
              ),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("มีบัญชีอยู่แล้ว?"),
                  SizedBox(width: 5),
                  const Text(
                    'ลงชื่อเข้าใช้',
                    style: TextStyle(color: Color.fromARGB(255, 129, 206, 242)),
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
