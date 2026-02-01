import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nubbill/widgets/rounded_button.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _pages = [
    {
      'title': 'สร้างกลุ่มง่ายๆ',
      'description': 'รวมเพื่อนๆ มาหารบิลด้วยกัน',
      'icon': 'group',
    },
    {
      'title': 'บันทึกค่าใช้จ่าย',
      'description': 'เพิ่มบิล แบ่งจ่ายได้หลายแบบ',
      'icon': 'receipt',
    },
    {
      'title': 'จ่ายเงินสะดวก',
      'description': 'สแกน QR แล้วส่งสลิปยืนยัน',
      'icon': 'qr_code',
    },
    {
      'title': 'เคลียร์ยอดชัดเจน',
      'description': 'ไม่ต้องจำว่าใครติดใคร',
      'icon': 'check',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: () => context.go('/login'),
                child: const Text('ข้าม', style: TextStyle(color: Colors.grey)),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Placeholder for Illustration
                        Container(
                          height: 250,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Icon(
                            _getIcon(_pages[index]['icon']!),
                            size: 100,
                            color: const Color(0xFF81CEF2),
                          ),
                        ),
                        const SizedBox(height: 48),
                        Text(
                          _pages[index]['title']!,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _pages[index]['description']!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 8,
                        width: _currentPage == index ? 24 : 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? const Color(0xFF81CEF2)
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  RoundedButton(
                    text: _currentPage == _pages.length - 1
                        ? 'เริ่มต้นใช้งาน'
                        : 'ถัดไป',
                    backgroundColor: const Color(0xFF81CEF2),
                    textColor: Colors.white,
                    onPressed: () {
                      if (_currentPage < _pages.length - 1) {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeIn,
                        );
                      } else {
                        context.go('/login');
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIcon(String name) {
    switch (name) {
      case 'group':
        return Icons.group_outlined;
      case 'receipt':
        return Icons.receipt_long_outlined;
      case 'qr_code':
        return Icons.qr_code_scanner_outlined;
      case 'check':
        return Icons.check_circle_outline;
      default:
        return Icons.circle;
    }
  }
}
