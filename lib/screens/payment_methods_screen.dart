import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nubbill/screens/payment_method_options.dart';
import 'package:nubbill/services/profile_service.dart';
import 'package:nubbill/widgets/retry_error_state.dart';

class PaymentMethodsScreen extends ConsumerStatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  ConsumerState<PaymentMethodsScreen> createState() =>
      _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends ConsumerState<PaymentMethodsScreen> {
  String? _updatingMethodId;
  final Set<String> _locallyRemovedIds = <String>{};

  Future<void> _goToAddPage() async {
    final result = await context.push<bool>('/add-payment-method');
    if (result == true) {
      ref.invalidate(paymentMethodsProvider);
      ref.invalidate(myProfileProvider);
    }
  }

  Future<void> _goToEditPage(PaymentMethod method) async {
    final result = await context.push<bool>(
      '/add-payment-method',
      extra: method,
    );
    if (result == true) {
      ref.invalidate(paymentMethodsProvider);
      ref.invalidate(myProfileProvider);
    }
  }

  Future<void> _setPrimary(PaymentMethod method) async {
    if (method.isPrimary) return;

    setState(() => _updatingMethodId = method.id);
    try {
      await ref.read(profileServiceProvider).setPrimaryPaymentMethod(method.id);
      ref.invalidate(paymentMethodsProvider);
      ref.invalidate(myProfileProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ไม่สามารถตั้งค่าเป็นบัญชีหลักได้: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _updatingMethodId = null);
    }
  }

  Future<void> _deleteMethod(PaymentMethod method) async {
    try {
      await ref.read(profileServiceProvider).deletePaymentMethod(method.id);
      ref.invalidate(paymentMethodsProvider);
      ref.invalidate(myProfileProvider);
    } catch (e) {
      if (mounted) {
        setState(() => _locallyRemovedIds.remove(method.id));
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ลบช่องทางรับเงินไม่สำเร็จ: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final methodsAsync = ref.watch(paymentMethodsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF0F0F0),
        elevation: 0,
        centerTitle: true,
        title: const Text('ช่องทางการรับเงิน'),
        leading: IconButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/profile');
            }
          },
          icon: const Icon(Icons.chevron_left, size: 28),
        ),
        actions: [
          IconButton(
            onPressed: _goToAddPage,
            icon: const Icon(Icons.add, color: Color(0xFF81CEF2), size: 28),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: methodsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => RetryErrorState(
          error: error,
          onRetry: () => ref.invalidate(paymentMethodsProvider),
        ),
        data: (methods) {
          final visibleMethods = methods
              .where((method) => !_locallyRemovedIds.contains(method.id))
              .toList();

          if (visibleMethods.isEmpty) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(paymentMethodsProvider);
              ref.invalidate(myProfileProvider);
            },
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 24),
              itemBuilder: (context, index) {
                final method = visibleMethods[index];
                return Dismissible(
                  key: ValueKey(method.id),
                  direction: DismissDirection.endToStart,
                  background: _buildDeleteBackground(),
                  confirmDismiss: (_) async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('ลบช่องทางรับเงิน'),
                        content: const Text(
                          'ยืนยันการลบช่องทางรับเงินนี้ใช่หรือไม่?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('ยกเลิก'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text(
                              'ลบ',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    );
                    return confirmed ?? false;
                  },
                  onDismissed: (_) {
                    setState(() => _locallyRemovedIds.add(method.id));
                    _deleteMethod(method);
                  },
                  child: _PaymentMethodCard(
                    method: method,
                    isUpdating: _updatingMethodId == method.id,
                    onSelectPrimary: () => _setPrimary(method),
                    onEdit: () => _goToEditPage(method),
                  ),
                );
              },
              separatorBuilder: (context, _) => const SizedBox(height: 14),
              itemCount: visibleMethods.length,
            ),
          );
        },
      ),
    );
  }

  Widget _buildDeleteBackground() {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFDDE0),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(Icons.delete_outline, color: Colors.red, size: 24),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.account_balance_wallet_outlined,
              size: 64,
              color: Color(0xFFB3B3B3),
            ),
            const SizedBox(height: 12),
            const Text(
              'ยังไม่มีช่องทางรับเงิน',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF5B5B5B),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'เพิ่มบัญชีธนาคารหรือพร้อมเพย์เพื่อเริ่มรับเงิน',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF888888)),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _goToAddPage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF81CEF2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('เพิ่มช่องทางรับเงิน'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentMethodCard extends StatelessWidget {
  final PaymentMethod method;
  final bool isUpdating;
  final VoidCallback onSelectPrimary;
  final VoidCallback onEdit;

  const _PaymentMethodCard({
    required this.method,
    required this.isUpdating,
    required this.onSelectPrimary,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final option = _resolveOption(method);
    final title = method.type == 'promptpay'
        ? PaymentChannelOptions.promptPay.displayName
        : option?.displayName ??
              method.bankName ??
              method.displayName ??
              'บัญชีธนาคาร';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        splashFactory: NoSplash.splashFactory,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        onTap: onSelectPrimary,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          decoration: BoxDecoration(
            color: const Color(0xFFD1DEE8),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: method.isPrimary
                  ? const Color(0xFF81CEF2)
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLeadingIcon(option),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF4E555C),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: onEdit,
                          child: const Padding(
                            padding: EdgeInsets.all(2),
                            child: Icon(
                              Icons.edit,
                              size: 14,
                              color: Color(0xFF8A8A8A),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _maskAccountText(method),
                      style: const TextStyle(
                        fontSize: 20,
                        color: Color(0xFF5E6670),
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'ชื่อ: ${method.accountName ?? method.displayName ?? method.promptpayName ?? '-'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF6D7278),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (method.isPrimary)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF81CEF2),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'เลือกอยู่',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: 24),
                  const SizedBox(height: 34),
                  if (isUpdating)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else if (method.isPrimary)
                    Container(
                      width: 21,
                      height: 21,
                      decoration: const BoxDecoration(
                        color: Color(0xFF81CEF2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 16,
                      ),
                    )
                  else
                    Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: Color(0xFFA7ADB3),
                        shape: BoxShape.circle,
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

  Widget _buildLeadingIcon(PaymentChannelOption? option) {
    if (option != null) {
      return Container(
        width: 42,
        height: 42,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: ClipOval(
          child: Image.asset(option.assetPath, width: 30, height: 30),
        ),
      );
    }

    return Container(
      width: 42,
      height: 42,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.account_balance, color: Color(0xFF6E7A86)),
    );
  }

  static PaymentChannelOption? _resolveOption(PaymentMethod method) {
    if (method.type == 'promptpay') return PaymentChannelOptions.promptPay;
    return PaymentChannelOptions.byBankName(
      method.bankName ?? method.displayName,
    );
  }

  static String _maskAccountText(PaymentMethod method) {
    if (method.type == 'promptpay') {
      final raw = method.promptpayId ?? method.accountNumber ?? '';
      final digits = raw.replaceAll(RegExp(r'\D'), '');
      if (digits.length >= 10) {
        return '${digits.substring(0, 3)}-xxx-xxxx';
      }
      if (digits.length >= 4) {
        return 'xxx-xxx-${digits.substring(digits.length - 4)}';
      }
      return raw.isNotEmpty ? raw : '-';
    }

    final raw = method.accountNumber ?? method.promptpayId ?? '';
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 5) {
      final tail = digits.substring(digits.length - 5);
      return 'xxx-x-x${tail.substring(0, 4)}-${tail.substring(4)}';
    }
    if (digits.length >= 4) {
      final tail = digits.substring(digits.length - 4);
      return 'xxx-x-x${tail.substring(0, 3)}-${tail.substring(3)}';
    }

    return raw.isNotEmpty ? raw : '-';
  }
}
