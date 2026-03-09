import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nubbill/screens/home_page.dart';
import 'package:nubbill/services/trip_service.dart';

class JoinGroupDeepLinkPage extends ConsumerStatefulWidget {
  final String joinCode;

  const JoinGroupDeepLinkPage({super.key, required this.joinCode});

  @override
  ConsumerState<JoinGroupDeepLinkPage> createState() =>
      _JoinGroupDeepLinkPageState();
}

class _JoinGroupDeepLinkPageState extends ConsumerState<JoinGroupDeepLinkPage> {
  bool _started = false;

  String _cleanJoinError(Object error) {
    final raw = error.toString();
    final lower = raw.toLowerCase();
    if (lower.contains('backend.max_conn') ||
        lower.contains('error 503') ||
        lower.contains('<html')) {
      return 'เซิร์ฟเวอร์กำลังหนาแน่น กรุณาลองใหม่อีกครั้ง';
    }

    const prefix = 'Exception: ';
    if (raw.startsWith(prefix)) {
      return raw.substring(prefix.length);
    }
    return raw;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _joinGroup());
  }

  Future<void> _joinGroup() async {
    if (_started || !mounted) return;
    _started = true;

    final code = widget.joinCode.trim();
    if (code.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ลิงก์เชิญเข้ากลุ่มไม่ถูกต้อง')),
      );
      context.go('/home');
      return;
    }

    try {
      final tripId = await ref.read(tripServiceProvider).joinTripByCode(code);
      if (!mounted) return;
      ref.invalidate(userTripsProvider);
      ref.invalidate(walletSummaryProvider);
      ref.invalidate(tripsProvider);
      context.go('/groups/$tripId');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เข้าร่วมกลุ่มสำเร็จ')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เข้ากลุ่มไม่สำเร็จ: ${_cleanJoinError(e)}')),
      );
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
