import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:nubbill/services/trip_service.dart';
import 'package:nubbill/shared/app_icons.dart';

const String _kFont = 'LINESeedSansTH';
const Color _kFabBlue = Color(0xFF81CEF2);

class GroupQuickActionsFab extends ConsumerStatefulWidget {
  final VoidCallback onCreateGroup;
  final VoidCallback? onJoinedGroup;

  const GroupQuickActionsFab({
    super.key,
    required this.onCreateGroup,
    this.onJoinedGroup,
  });

  @override
  ConsumerState<GroupQuickActionsFab> createState() =>
      _GroupQuickActionsFabState();
}

class _GroupQuickActionsFabState extends ConsumerState<GroupQuickActionsFab>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;

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

  Future<void> _scanToJoinGroup() async {
    final code = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _JoinGroupScannerSheet(),
    );

    if (!mounted || code == null || code.trim().isEmpty) return;

    final normalizedCode = code.trim().toUpperCase();

    try {
      final tripId = await ref.read(tripServiceProvider).joinTripByCode(normalizedCode);
      widget.onJoinedGroup?.call();
      if (!mounted) return;
      setState(() => _expanded = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เข้าร่วมกลุ่มสำเร็จ')),
      );
      context.push('/groups/$tripId');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เข้ากลุ่มไม่สำเร็จ: ${_cleanJoinError(e)}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: _expanded
              ? Column(
                  key: const ValueKey('expandedActions'),
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _ActionPillButton(
                      icon: AppIcons.qrScanner,
                      label: 'สแกนเข้ากลุ่ม',
                      onTap: _scanToJoinGroup,
                    ),
                    const SizedBox(height: 8),
                    _ActionPillButton(
                      icon: AppIcons.people,
                      label: 'สร้างกลุ่มใหม่',
                      onTap: () {
                        setState(() => _expanded = false);
                        widget.onCreateGroup();
                      },
                    ),
                    const SizedBox(height: 10),
                  ],
                )
              : const SizedBox.shrink(key: ValueKey('collapsedActions')),
        ),
        _MainExpandableFab(
          expanded: _expanded,
          onCreateGroup: widget.onCreateGroup,
          onToggleExpanded: () => setState(() => _expanded = !_expanded),
        ),
      ],
    );
  }
}

class _MainExpandableFab extends StatelessWidget {
  final bool expanded;
  final VoidCallback onCreateGroup;
  final VoidCallback onToggleExpanded;

  const _MainExpandableFab({
    required this.expanded,
    required this.onCreateGroup,
    required this.onToggleExpanded,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: _kFabBlue,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: onCreateGroup,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(AppIcons.people, color: Colors.white, size: 20),
                    SizedBox(width: 4),
                    Text(
                      'สร้างกลุ่มใหม่',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontFamily: _kFont,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              width: 1,
              height: 20,
              margin: const EdgeInsets.symmetric(horizontal: 10),
              color: Colors.white.withValues(alpha: 0.72),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onToggleExpanded,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: const Icon(AppIcons.chevronUp, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionPillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionPillButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _kFabBlue,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontFamily: _kFont,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JoinGroupScannerSheet extends StatefulWidget {
  const _JoinGroupScannerSheet();

  @override
  State<_JoinGroupScannerSheet> createState() => _JoinGroupScannerSheetState();
}

class _JoinGroupScannerSheetState extends State<_JoinGroupScannerSheet> {
  final MobileScannerController _controller = MobileScannerController(
    facing: CameraFacing.back,
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _handlingScan = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _extractJoinCode(String raw) {
    final value = raw.trim();
    final uri = Uri.tryParse(value);

    if (uri != null && uri.scheme == 'nubbill') {
      final host = uri.host;
      final segments = uri.pathSegments;
      final isTripJoin =
          (host == 'trip' && segments.length >= 2 && segments[0] == 'join') ||
          (segments.length >= 3 && segments[0] == 'trip' && segments[1] == 'join');

      if (isTripJoin) {
        final code = host == 'trip' ? segments[1] : segments[2];
        return code.trim().isEmpty ? null : code.trim();
      }
    }

    final plain = value.replaceAll(RegExp(r'\s+'), '');
    if (RegExp(r'^[A-Za-z0-9]{4,20}$').hasMatch(plain)) {
      return plain;
    }

    final joinPathMatch = RegExp(r'join/([A-Za-z0-9]{4,20})').firstMatch(value);
    final fromPath = joinPathMatch?.group(1);
    if (fromPath != null && fromPath.isNotEmpty) {
      return fromPath;
    }

    return null;
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handlingScan) return;

    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null || raw.isEmpty) continue;

      final code = _extractJoinCode(raw);
      if (code == null) continue;

      _handlingScan = true;
      _controller.stop();
      Navigator.of(context).pop(code);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.72,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0x33141416),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'สแกนเข้ากลุ่ม',
              style: TextStyle(
                color: Color(0xB2141416),
                fontSize: 20,
                fontFamily: _kFont,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'สแกน QR คำเชิญกลุ่ม Nub-Bill',
              style: TextStyle(
                color: Color(0x99141416),
                fontSize: 14,
                fontFamily: _kFont,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: MobileScanner(
                    controller: _controller,
                    onDetect: _onDetect,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
