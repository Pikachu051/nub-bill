import 'package:flutter/material.dart';

const String networkTimeoutMessage =
    'การเชื่อมต่อกับเซิร์ฟเวอร์ล้มเหลว ลองตรวจสอบเครือข่ายแล้วมาลองใหม่น้า';

bool isNetworkTimeoutError(Object error) {
  final text = error.toString().toLowerCase();
  const patterns = [
    'timeoutexception',
    'timeout',
    'timed out',
    'socketexception',
    'failed host lookup',
    'connection refused',
    'connection reset',
    'connection closed',
    'network',
    'clientexception',
    'handshakeexception',
  ];

  return patterns.any(text.contains);
}

String errorMessageForDisplay(
  Object error, {
  String fallback = 'เกิดข้อผิดพลาด กรุณาลองใหม่อีกครั้ง',
}) {
  if (isNetworkTimeoutError(error)) {
    return networkTimeoutMessage;
  }
  return fallback;
}

class RetryErrorState extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  final String fallbackMessage;

  const RetryErrorState({
    super.key,
    required this.error,
    required this.onRetry,
    this.fallbackMessage = 'เกิดข้อผิดพลาด กรุณาลองใหม่อีกครั้ง',
  });

  @override
  Widget build(BuildContext context) {
    final message = errorMessageForDisplay(error, fallback: fallbackMessage);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 48, color: Colors.grey[500]),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[700], fontSize: 14),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('ลองใหม่'),
            ),
          ],
        ),
      ),
    );
  }
}
