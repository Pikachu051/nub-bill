import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nubbill/screens/payment_method_options.dart';
import 'package:nubbill/services/profile_service.dart';
import 'package:qr_flutter/qr_flutter.dart';

class AddPaymentMethodScreen extends ConsumerStatefulWidget {
  final PaymentMethod? editingMethod;

  const AddPaymentMethodScreen({super.key, this.editingMethod});

  @override
  ConsumerState<AddPaymentMethodScreen> createState() =>
      _AddPaymentMethodScreenState();
}

class _AddPaymentMethodScreenState
    extends ConsumerState<AddPaymentMethodScreen> {
  final TextEditingController _accountController = TextEditingController();
  final TextEditingController _accountNameController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  PaymentChannelOption _selectedOption = PaymentChannelOptions.kasikorn;
  bool _isSubmitting = false;
  bool _isUploadingQr = false;
  Uint8List? _qrPreview;
  String? _qrImageUrl;
  String? _existingQrImageUrl;

  bool get _isPromptPay => _selectedOption.id == 'promptpay';
  bool get _isEditing => widget.editingMethod != null;

  @override
  void initState() {
    super.initState();

    final editingMethod = widget.editingMethod;
    if (editingMethod == null) return;

    if (editingMethod.type == 'promptpay') {
      _selectedOption = PaymentChannelOptions.promptPay;
      _accountController.text = editingMethod.promptpayId ?? '';
    } else {
      _selectedOption =
          PaymentChannelOptions.byBankName(
            editingMethod.bankName ?? editingMethod.displayName,
          ) ??
          PaymentChannelOptions.kasikorn;
      _accountController.text = editingMethod.accountNumber ?? '';
    }

    _accountNameController.text = editingMethod.accountName ?? '';
    _qrImageUrl = editingMethod.qrImageUrl;
    _existingQrImageUrl = editingMethod.qrImageUrl;
  }

  @override
  void dispose() {
    _accountController.dispose();
    _accountNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF0F0F0),
        centerTitle: true,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(_isEditing ? 'แก้ไขบัญชีรับเงิน' : 'เพิ่มบัญชีรับเงิน'),
        actions: [
          IconButton(
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/payment-methods');
              }
            },
            icon: const Icon(Icons.close, size: 34, color: Color(0xFF8B8B8B)),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionTitle('เลือกช่องทาง'),
                    const SizedBox(height: 12),
                    _buildOptionGrid(),
                    const SizedBox(height: 22),
                    _SectionTitle(
                      _isPromptPay
                          ? 'เลขบัตรประชาชน / เบอร์โทรศัพท์'
                          : 'เลขที่บัญชี',
                    ),
                    const SizedBox(height: 10),
                    _buildField(
                      controller: _accountController,
                      hint: _isPromptPay
                          ? 'กรอกเลขบัตรประชาชน หรือ เบอร์โทรที่ผูก PromptPay'
                          : 'กรอกเลขบัญชี',
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 14),
                    const _SectionTitle('ชื่อบัญชี'),
                    const SizedBox(height: 10),
                    _buildField(
                      controller: _accountNameController,
                      hint: 'กรอกชื่อ',
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const _SectionTitle('คิวอาร์โค้ดบัญชี'),
                        if (_isPromptPay)
                          TextButton(
                            onPressed: _isUploadingQr || _isSubmitting
                                ? null
                                : _generatePromptPayQr,
                            child: const Text(
                              'สร้างอัตโนมัติ',
                              style: TextStyle(
                                color: Color(0xFF81CEF2),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _DashedBorder(
                      radius: 16,
                      color: const Color(0xFF81CEF2),
                      child: Material(
                        color: const Color(0xFFD5E2EA),
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: _isUploadingQr || _isSubmitting
                              ? null
                              : _pickAndUploadQr,
                          child: SizedBox(
                            width: double.infinity,
                            height: 148,
                            child: _qrPreview != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Image.memory(
                                          _qrPreview!,
                                          fit: BoxFit.contain,
                                        ),
                                        if (_isUploadingQr)
                                          Container(
                                            color: Colors.black.withValues(
                                              alpha: 0.16,
                                            ),
                                            alignment: Alignment.center,
                                            child:
                                                const CircularProgressIndicator(),
                                          ),
                                      ],
                                    ),
                                  )
                                : _existingQrImageUrl != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Image.network(
                                          _existingQrImageUrl!,
                                          fit: BoxFit.contain,
                                          errorBuilder:
                                              (
                                                context,
                                                error,
                                                stackTrace,
                                              ) => const Center(
                                                child: Icon(
                                                  Icons.broken_image_outlined,
                                                  size: 42,
                                                  color: Color(0xFF8C9093),
                                                ),
                                              ),
                                        ),
                                        if (_isUploadingQr)
                                          Container(
                                            color: Colors.black.withValues(
                                              alpha: 0.16,
                                            ),
                                            alignment: Alignment.center,
                                            child:
                                                const CircularProgressIndicator(),
                                          ),
                                      ],
                                    ),
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.qr_code_2_rounded,
                                        size: 56,
                                        color: Color(0xFF81CEF2),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _isUploadingQr
                                            ? 'กำลังอัพโหลด...'
                                            : 'แตะเพื่ออัพโหลดรูป QR Code',
                                        style: const TextStyle(
                                          color: Color(0xFF8C9093),
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      if (_isPromptPay)
                                        const Padding(
                                          padding: EdgeInsets.only(top: 4),
                                          child: Text(
                                            'หรือกดปุ่ม "สร้างอัตโนมัติ"',
                                            style: TextStyle(
                                              color: Color(0xFF8C9093),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF81CEF2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(32),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          _isEditing ? 'บันทึกการแก้ไข' : 'เพิ่มช่องทางรับเงิน',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionGrid() {
    return GridView.builder(
      shrinkWrap: true,
      itemCount: PaymentChannelOptions.list.length,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 12,
        childAspectRatio: 3.1,
      ),
      itemBuilder: (context, index) {
        final option = PaymentChannelOptions.list[index];
        final isSelected = option.id == _selectedOption.id;

        return InkWell(
          borderRadius: BorderRadius.circular(999),
          splashFactory: NoSplash.splashFactory,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          onTap: () => setState(() => _selectedOption = option),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? const Color(0xFF81CEF2)
                      : const Color(0xFFACB0B3),
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 12, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 8),
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: ClipOval(
                  child: Image.asset(option.assetPath, width: 30, height: 30),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  option.label,
                  style: const TextStyle(
                    color: Color(0xFF4D4D4D),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 16, color: Color(0xFF4D4D4D)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF969696), fontSize: 16),
        filled: true,
        fillColor: const Color(0xFFD9D9DC),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 22,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Future<void> _pickAndUploadQr() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF81CEF2)),
              title: const Text('ถ่ายรูป'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library,
                color: Color(0xFF81CEF2),
              ),
              title: const Text('เลือกจากแกลเลอรี'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final file = await _imagePicker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 90,
    );

    if (file == null) return;

    final bytes = await file.readAsBytes();
    setState(() {
      _isUploadingQr = true;
      _qrPreview = bytes;
    });

    try {
      final extension = file.path.contains('.')
          ? file.path.split('.').last
          : 'jpg';
      final qrUrl = await ref
          .read(profileServiceProvider)
          .uploadPaymentQr(
            bytes,
            fileName:
                'payment_qr_${DateTime.now().millisecondsSinceEpoch}.$extension',
          );
      if (!mounted) return;

      setState(() => _qrImageUrl = qrUrl);
      _existingQrImageUrl = qrUrl;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('อัพโหลด QR Code สำเร็จ'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('อัพโหลด QR Code ไม่สำเร็จ: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploadingQr = false);
      }
    }
  }

  Future<void> _generatePromptPayQr() async {
    if (!_isPromptPay) return;

    final input = _accountController.text.trim();
    if (input.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณากรอกเลขบัตรประชาชนหรือเบอร์โทรก่อน'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isUploadingQr = true);

    try {
      Uint8List? bytes;
      Object? lastError;

      final candidates = _buildPromptPayPayloadCandidates(input);
      debugPrint('[PromptPay QR] Generating QR for input: $input');
      debugPrint('[PromptPay QR] ${candidates.length} payload candidate(s)');

      for (final payload in candidates) {
        try {
          debugPrint('[PromptPay QR] Trying payload (${payload.length} chars): ${payload.substring(0, math.min(40, payload.length))}...');
          bytes = await _renderQrBytes(payload);
          debugPrint('[PromptPay QR] QR rendered successfully');
          break;
        } catch (error) {
          debugPrint('[PromptPay QR] Render failed: $error');
          lastError = error;
        }
      }

      if (bytes == null) {
        debugPrint('[PromptPay QR] All candidates failed. Last error: $lastError');
        throw Exception(
          'ไม่สามารถสร้าง QR ได้ กรุณาตรวจสอบเลข PromptPay ที่กรอก',
        );
      }

      final qrUrl = await ref
          .read(profileServiceProvider)
          .uploadPaymentQr(
            bytes,
            fileName:
                'promptpay_qr_${DateTime.now().millisecondsSinceEpoch}.png',
          );

      if (!mounted) return;

      setState(() {
        _qrPreview = bytes;
        _qrImageUrl = qrUrl;
        _existingQrImageUrl = qrUrl;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('สร้าง QR พร้อมเพย์สำเร็จ'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('สร้าง QR ไม่สำเร็จ: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploadingQr = false);
      }
    }
  }

  Future<void> _submit() async {
    final accountInput = _accountController.text.trim();
    final accountName = _accountNameController.text.trim();

    if (accountInput.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isPromptPay
                ? 'กรุณากรอกเลขบัตรประชาชน / เบอร์โทรศัพท์'
                : 'กรุณากรอกเลขที่บัญชี',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (accountName.isEmpty) {
      if (!_isPromptPay) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('กรุณากรอกชื่อบัญชี'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() => _isSubmitting = true);

    try {
      final service = ref.read(profileServiceProvider);

      if (_isEditing) {
        await service.updatePaymentMethod(
          id: widget.editingMethod!.id,
          type: _isPromptPay ? 'promptpay' : 'bank_account',
          promptpayId: _isPromptPay ? accountInput : null,
          bankName: _isPromptPay
              ? null
              : PaymentChannelOptions.bankNameForBackend(_selectedOption),
          accountNumber: _isPromptPay ? null : accountInput,
          accountName: _isPromptPay && accountName.isEmpty ? null : accountName,
          displayName: _isPromptPay
              ? PaymentChannelOptions.promptPay.displayName
              : _selectedOption.displayName,
          qrImageUrl: _qrImageUrl,
        );
      } else {
        await service.addPaymentMethod(
          type: _isPromptPay ? 'promptpay' : 'bank_account',
          promptpayId: _isPromptPay ? accountInput : null,
          bankName: _isPromptPay
              ? null
              : PaymentChannelOptions.bankNameForBackend(_selectedOption),
          accountNumber: _isPromptPay ? null : accountInput,
          accountName: _isPromptPay && accountName.isEmpty ? null : accountName,
          displayName: _isPromptPay
              ? PaymentChannelOptions.promptPay.displayName
              : _selectedOption.displayName,
          qrImageUrl: _qrImageUrl,
        );
      }

      ref.invalidate(paymentMethodsProvider);
      ref.invalidate(myProfileProvider);

      if (!mounted) return;
      if (context.canPop()) {
        context.pop(true);
      } else {
        context.go('/payment-methods');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เพิ่มช่องทางรับเงินไม่สำเร็จ: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<Uint8List> _renderQrBytes(String payload) async {
    final painter = QrPainter(
      data: payload,
      version: QrVersions.auto,
      eyeStyle: const QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: Color(0xFF2E2E2E),
      ),
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: Color(0xFF2E2E2E),
      ),
    );

    final byteData = await painter.toImageData(
      1024,
      format: ui.ImageByteFormat.png,
    );

    if (byteData == null) {
      throw Exception('ไม่สามารถสร้างรูป QR ได้');
    }

    return byteData.buffer.asUint8List();
  }

  List<String> _buildPromptPayPayloadCandidates(String rawInput) {
    final normalizedDigits = _normalizePromptPayDigits(
      rawInput.replaceAll(RegExp(r'\D'), ''),
    );

    final candidates = <String>{};
    final emvPayload = _buildPromptPayPayload(normalizedDigits);
    if (emvPayload != null) {
      candidates.add(emvPayload);
    }

    if (normalizedDigits.isNotEmpty) {
      candidates.add('PROMPTPAY:$normalizedDigits');
      candidates.add(normalizedDigits);
    }

    candidates.add('PROMPTPAY:${rawInput.trim()}');
    return candidates.toList();
  }

  String _normalizePromptPayDigits(String digits) {
    if (digits.length == 11 && digits.startsWith('66')) {
      return '0${digits.substring(2)}';
    }
    if (digits.length == 12 && digits.startsWith('660')) {
      return '0${digits.substring(3)}';
    }
    return digits;
  }

  String? _buildPromptPayPayload(String digitsOnly) {
    if (digitsOnly.length != 10 && digitsOnly.length != 13) {
      return null;
    }

    final String proxyType;
    final String proxyValue;

    if (digitsOnly.length == 10) {
      proxyType = '01';
      proxyValue = '0066${digitsOnly.substring(1)}';
    } else {
      proxyType = '02';
      proxyValue = digitsOnly;
    }

    final merchantInfoValue =
        '0016A000000677010111'
        '$proxyType${_formatLength(proxyValue.length)}$proxyValue';

    final payloadWithoutCrc =
        '000201'
        '010211'
        '29${_formatLength(merchantInfoValue.length)}$merchantInfoValue'
        '5802TH'
        '5303764';

    final crc = _crc16Ccitt(
      '$payloadWithoutCrc'
      '6304',
    );
    return '$payloadWithoutCrc'
        '6304$crc';
  }

  String _formatLength(int length) => length.toString().padLeft(2, '0');

  String _crc16Ccitt(String data) {
    var crc = 0xFFFF;

    for (final codeUnit in data.codeUnits) {
      crc ^= (codeUnit & 0xFF) << 8;

      for (var i = 0; i < 8; i++) {
        if ((crc & 0x8000) != 0) {
          crc = (crc << 1) ^ 0x1021;
        } else {
          crc <<= 1;
        }
        crc &= 0xFFFF;
      }
    }

    return crc.toRadixString(16).toUpperCase().padLeft(4, '0');
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF4B4B4B),
        fontSize: 16,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _DashedBorder extends StatelessWidget {
  final Widget child;
  final Color color;
  final double radius;

  const _DashedBorder({
    required this.child,
    required this.color,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(color: color, radius: radius),
      child: child,
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;

  const _DashedBorderPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + 7;
        canvas.drawPath(
          metric.extractPath(distance, math.min(next, metric.length)),
          paint,
        );
        distance = next + 5;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}
