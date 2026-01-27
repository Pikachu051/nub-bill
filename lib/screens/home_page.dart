import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Stack(
            children: [
              // Blue bg
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
                child: Container(
                  width: double.infinity,
                  height: 200,
                  color: Color.fromARGB(255, 129, 206, 242),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 60, 16, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundImage: NetworkImage(
                        "https://example.com/profile.jpg",
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text(
                          'คุณ, โลลี่ป๊อป',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "เคลียร์บิลกันเถอะ!",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // เนื้อหาด้านล่าง
          Expanded(
            child: Container(
              color: Colors.white,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ===== การ์ดภาพรวมกระเป๋า =====
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'ภาพรวมกระเป๋าตังค์',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '+1,300.00฿',
                            style: TextStyle(
                              color: Colors.blue,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Divider(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  children: const [
                                    Text(
                                      'รอรับเงิน',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      '1,500.00฿',
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 32,
                                color: Colors.grey.shade300,
                              ),
                              Expanded(
                                child: Column(
                                  children: const [
                                    Text(
                                      'ค้างจ่าย',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      '200.00฿',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ===== หัวข้อกลุ่ม =====
                    const Text(
                      'กลุ่มของคุณ (8 กลุ่ม)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ===== รายการกลุ่ม =====
                    _groupItem(
                      iconColor: Colors.orange,
                      title: 'เที่ยวเชียงใหม่',
                      date: '21/12/68 - 24/12/68',
                      amount: '200.00฿',
                      isDebt: true,
                    ),
                    _groupItem(
                      iconColor: Colors.blue,
                      title: 'วันเกิดซูซูย',
                      date: '03/01/69',
                      amount: '1,500.00฿',
                      isDebt: false,
                    ),
                    _groupItem(
                      iconColor: Colors.yellow,
                      title: 'เดทกับแฟน',
                      date: '03/01/69',
                      amount: '350.00฿',
                      isDebt: false,
                    ),

                    const SizedBox(height: 80), // เว้นให้ปุ่มลอย
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Widget ชั่วตราว
Widget _groupItem({
  required Color iconColor,
  required String title,
  required String date,
  required String amount,
  required bool isDebt,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.home, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(date, style: const TextStyle(color: Colors.grey)),
            ],
          ),
        ),
        Text(
          amount,
          style: TextStyle(
            color: isDebt ? Colors.red : Colors.green,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}
