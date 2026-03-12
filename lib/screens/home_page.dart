import 'package:flutter/material.dart';
import 'package:nubbill/shared/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nubbill/services/auth_repository.dart';
import 'package:nubbill/services/profile_service.dart';
import 'package:nubbill/models/trip_model.dart';
import 'package:nubbill/widgets/retry_error_state.dart';
import 'package:nubbill/widgets/group_quick_actions_fab.dart';
import 'package:nubbill/services/trip_service.dart';
import 'package:nubbill/shared/providers/realtime_invalidator.dart';
import 'package:nubbill/shared/widgets/realtime_animated_list.dart';
import 'package:nubbill/shared/widgets/list_animations.dart';

/// Provider for user's groups — derived from wallet summary so balances
/// are always consistent with the wallet card (single API call).
final userTripsProvider = FutureProvider.autoDispose<List<Trip>>((ref) async {
  final wallet = await ref.watch(walletSummaryProvider.future);
  return wallet.trips;
});

/// Provider for wallet summary using the backend's canonical balance logic.
/// Auto-refreshes via walletRealtimeProvider when expenses/settlements/members change.
final walletSummaryProvider =
    FutureProvider.autoDispose<WalletSummary>((ref) async {
  final userId = ref.watch(authUserIdProvider);
  if (userId == null) return const WalletSummary.empty();

  // Watch realtime ticks to auto-refresh.
  ref.watch(walletRealtimeProvider);

  final service = ref.read(tripServiceProvider);
  return service.getWalletSummary();
});

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  void _refreshWallet() {
    if (!mounted) return;
    ref.invalidate(userTripsProvider);
    ref.invalidate(walletSummaryProvider);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authRepositoryProvider).currentUser;
    final profileAsync = ref.watch(myProfileProvider);

    // Get nickname and avatar from profile (with fallback to auth metadata)
    final nickname = profileAsync.when(
      data: (profile) =>
          profile.nickname ?? user?.userMetadata?['nickname'] ?? 'User',
      loading: () => user?.userMetadata?['nickname'] ?? 'User',
      error: (error, stackTrace) => user?.userMetadata?['nickname'] ?? 'User',
    );
    final avatarUrl = profileAsync.when(
      data: (profile) => profile.avatarUrl,
      loading: () => user?.userMetadata?['avatar_url'] as String?,
      error: (error, stackTrace) =>
          user?.userMetadata?['avatar_url'] as String?,
    );

    final tripsAsync = ref.watch(userTripsProvider);
    final walletAsync = ref.watch(walletSummaryProvider);
    const baseWalletTop = 130.0;
    const baseOverlapSpacer = 130.0;
    const baselineTopInset = 24.0;
    final topInset = MediaQuery.paddingOf(context).top;
    // Keep phone layout as baseline and push card/spacer down only on taller insets.
    final extraTopInset = (topInset - baselineTopInset)
        .clamp(0.0, 48.0)
        .toDouble();
    final walletTop = baseWalletTop + extraTopInset;
    final walletOverlapSpacer = baseOverlapSpacer + extraTopInset;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: RefreshIndicator(
        onRefresh: () async {
          // Refresh trips and wallet summary from Supabase with pull-to-refresh
          await Future.wait([
            ref.refresh(userTripsProvider.future),
            ref.refresh(walletSummaryProvider.future),
          ]);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with overlapping wallet card
              Stack(
                clipBehavior: Clip.none,
                children: [
                  // 👇 เอา ClipPath ไว้เป็น background อย่างเดียว
                  ClipPath(
                    clipper: CustomClipPath(),
                    child: Container(
                      width: double.infinity,
                      height: 200,
                      color: const Color(0xFF81CEF2),
                    ),
                  ),

                  // 👇 เอา content ออกมาวางทับ
                  SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: CircleAvatar(
                              radius: 30,
                              backgroundColor: Colors.white24,
                              backgroundImage: avatarUrl != null
                                  ? NetworkImage(avatarUrl)
                                  : null,
                              child: avatarUrl == null
                                  ? const Icon(
                                      AppIcons.person,
                                      size: 30,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'คุณ, $nickname',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'เคลียร์บิลกันเถอะ!',
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
                  ),

                  // Wallet card
                  Positioned(
                    left: 16,
                    right: 16,
                    top: walletTop,
                    child: _buildWalletCard(walletAsync),
                  ),
                ],
              ),

              // Spacing for the overlapping card (wallet card is ~160px tall, positioned at 130, blue header is 180)
              // Card extends from 130 to ~290, so we need 290 - 180 = 110 spacing
              SizedBox(height: walletOverlapSpacer),

              // Groups section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top padding for groups section
                    const SizedBox(height: 20),

                    // Groups Header
                    _buildGroupsHeader(tripsAsync),

                    const SizedBox(height: 12),

                    // Groups List
                    _buildGroupsList(context, ref, tripsAsync),

                    // Bottom padding for FAB
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: GroupQuickActionsFab(
        onCreateGroup: () => context.push('/groups/create'),
        onJoinedGroup: _refreshWallet,
      ),
    );
  }

  //Wallet widget
  Widget _buildWalletCard(AsyncValue<WalletSummary> walletAsync) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: walletAsync.when(
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(),
          ),
        ),
        error: (error, stackTrace) => const Text('ไม่สามารถโหลดข้อมูลได้'),
        data: (wallet) {
          final toReceive = wallet.toReceive;
          final toPay = wallet.toPay;
          final balance = wallet.balance;

          return Column(
            children: [
              const Text(
                'ภาพรวมกระเป๋าตังค์',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                '${balance >= 0 ? '+' : ''}${_formatMoney(balance)}฿',
                style: TextStyle(
                  color: balance >= 0 ? const Color(0xFF81CEF2) : Colors.red,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Container(height: 1, color: Colors.grey[200]),
              const SizedBox(height: 16),
              Row(
                children: [
                  // To Receive
                  Expanded(
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              AppIcons.arrowDown,
                              size: 16,
                              color: Colors.green[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'รอรับเงิน',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_formatMoney(toReceive)}฿',
                          style: TextStyle(
                            color: Colors.green[600],
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 40, color: Colors.grey[300]),
                  // To Pay
                  Expanded(
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              AppIcons.arrowUp,
                              size: 16,
                              color: Colors.red[400],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'ค้างจ่าย',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_formatMoney(toPay)}฿',
                          style: TextStyle(
                            color: Colors.red[400],
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildGroupsHeader(AsyncValue<List<Trip>> tripsAsync) {
    final count = tripsAsync.value?.length ?? 0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'กลุ่มของคุณ ($count กลุ่ม)',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        // Filter icon (from design)
        IconButton(
          onPressed: () {},
          icon: Icon(AppIcons.tune, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildGroupsList(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<Trip>> tripsAsync,
  ) {
    return tripsAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (err, stackTrace) => Center(
        child: RetryErrorState(
          error: err,
          onRetry: () => ref.invalidate(userTripsProvider),
        ),
      ),
      data: (trips) {
        if (trips.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  Icon(AppIcons.groups, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'ยังไม่มีกลุ่ม',
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'กดปุ่มด้านล่างเพื่อสร้างกลุ่มใหม่',
                    style: TextStyle(color: Colors.grey[400], fontSize: 14),
                  ),
                ],
              ),
            ),
          );
        }

        return RealtimeAnimatedColumn<Trip>(
          items: trips,
          keyExtractor: (t) => t.id,
          itemBuilder: (ctx, trip, animation) =>
              slideInBuilder(ctx, _buildGroupCard(ctx, trip), animation),
          removedItemBuilder: (ctx, trip, animation) =>
              slideOutBuilder(ctx, _buildGroupCard(ctx, trip), animation),
        );
      },
    );
  }

  Widget _buildGroupCard(BuildContext context, Trip trip) {
    final balance = trip.balance;
    final isPositive = balance > 0;
    final isNegative = balance < 0;
    final statusLabel = isPositive
        ? 'รอรับเงิน'
        : (isNegative ? 'ค้างจ่าย' : 'เคลียร์');
    final statusColor = isPositive
        ? const Color(0xFF4CAF50)
        : (isNegative ? const Color(0xFFFF5252) : Colors.grey[500]);
    final amountColor = isPositive
        ? const Color(0xFF3DCB57)
        : (isNegative ? const Color(0xFFFF5252) : Colors.grey[500]);

    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: const Color(0xFF81CEF2).withValues(alpha: 0.1),
          backgroundImage: trip.coverUrl != null
              ? NetworkImage(trip.coverUrl!)
              : null,
          child: trip.coverUrl == null
              ? Icon(trip.category.icon, color: const Color(0xFF81CEF2))
              : null,
        ),
        title: Text(trip.name, style: const TextStyle(fontSize: 16)),
        subtitle: Text(
          _formatDateRange(trip.startDate, trip.endDate),
          style: const TextStyle(color: Color(0x80141416), fontSize: 13),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              statusLabel,
              style: TextStyle(
                color: statusColor,
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${_formatMoney(balance.abs())}฿',
              style: TextStyle(
                color: amountColor,
                fontWeight: FontWeight.normal,
                fontSize: 15,
              ),
            ),
          ],
        ),
        onTap: () => context.push('/groups/${trip.id}'),
      ),
    );
  }

  String _formatDateRange(DateTime? start, DateTime? end) {
    if (start == null && end == null) return '';
    if (start == null) return _formatDate(end!);
    if (end == null) return _formatDate(start);
    return '${_formatDate(start)} - ${_formatDate(end)}';
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year + 543}'; // Thai Buddhist year
  }

  String _formatMoney(double amount) {
    if (amount == 0) return '0.00';
    return amount
        .toStringAsFixed(2)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }
}

class CustomClipPath extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    double w = size.width;
    double h = size.height;

    final path = Path();

    path.lineTo(0, h - 50);

    path.quadraticBezierTo(w * 0.5, h + 150, w, h - 50);

    path.lineTo(w, 0);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) {
    return false;
  }
}
