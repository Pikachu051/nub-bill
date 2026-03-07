import 'package:flutter/material.dart';
import 'package:nubbill/shared/app_icons.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nubbill/services/trip_service.dart';
import 'package:nubbill/services/expense_service.dart';
import 'package:nubbill/services/realtime_service.dart';
import 'package:nubbill/models/trip_model.dart';
import 'package:nubbill/models/trip_member_model.dart';
import 'package:nubbill/models/expense_model.dart';
import 'package:nubbill/models/debt_entry_model.dart';
import 'package:nubbill/models/balance_entry_model.dart';
import 'package:nubbill/config/supabase_config.dart';
import 'package:nubbill/widgets/half_width_tab_indicator.dart';
import 'package:nubbill/widgets/retry_error_state.dart';

const _walletLoadTimeout = Duration(seconds: 12);

final tripBalancesWithTimeoutProvider = FutureProvider.autoDispose
    .family<List<BalanceEntry>, String>((ref, tripId) async {
      final balancesFuture = ref.watch(tripBalancesProvider(tripId).future);
      return balancesFuture.timeout(_walletLoadTimeout);
    });

class GroupDetailPage extends ConsumerStatefulWidget {
  final String groupId;

  const GroupDetailPage({super.key, required this.groupId});

  @override
  ConsumerState<GroupDetailPage> createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends ConsumerState<GroupDetailPage>
    with SingleTickerProviderStateMixin {
  static const double _coverHeight = 280.0;
  static const double _walletCardTopOverlap = 44.0;
  static const double _walletCardEstimatedHeight = 132.0;
  static const double _expandedHeaderHeight =
      _coverHeight + _walletCardEstimatedHeight - _walletCardTopOverlap + 12.0;

  late TabController _tabController;
  StreamSubscription? _expenseSubscription;
  Timer? _walletRetryTimer;

  // Local state for bill list
  List<Expense> _expenses = [];
  bool _isInitialLoad = true;

  /// Current user's member ID in this trip
  String? _myMemberId;
  final Map<String, String> _memberNameById = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Subscribe to realtime expense updates after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
      _subscribeToRealtimeUpdates();
    });
  }

  Future<void> _loadInitialData() async {
    // Load trip detail to get myMemberId
    final tripDetail = await ref.read(
      tripDetailProvider(widget.groupId).future,
    );
    if (mounted && tripDetail != null) {
      final memberNames = <String, String>{};
      for (final member in tripDetail.members) {
        memberNames[member.id] = member.displayName;
      }
      setState(() {
        _myMemberId = tripDetail.myMemberId;
        _memberNameById
          ..clear()
          ..addAll(memberNames);
      });
    }

    // Load expenses
    final expenses = await ref.read(
      tripExpensesProvider(widget.groupId).future,
    );
    if (mounted) {
      setState(() {
        _expenses = List.from(expenses);
        _isInitialLoad = false;
      });
    }
  }

  void _subscribeToRealtimeUpdates() {
    final realtimeService = ref.read(realtimeServiceProvider);

    _expenseSubscription = realtimeService.subscribeToTripExpenses(
      tripId: widget.groupId,
      onEvent: (event) {
        switch (event.type) {
          case RealtimeEventType.insert:
          case RealtimeEventType.update:
          case RealtimeEventType.delete:
            // On any change, reload all expenses to get full join data
            _reloadExpenses();
            break;
        }
        // Refresh debts and balances
        ref.invalidate(tripDebtsProvider(widget.groupId));
        ref.invalidate(tripBalancesProvider(widget.groupId));
        ref.invalidate(tripBalancesWithTimeoutProvider(widget.groupId));
      },
    );
  }

  Future<void> _reloadExpenses() async {
    try {
      final expenses = await ref
          .read(expenseServiceProvider)
          .getTripExpenses(widget.groupId);
      if (mounted) {
        setState(() {
          _expenses = expenses;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _walletRetryTimer?.cancel();
    _expenseSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  /// Schedules a single automatic wallet reload 3 seconds after a failure.
  /// Prevents hammering the server while still recovering from cold-start timeouts.
  void _scheduleWalletAutoRetry() {
    _walletRetryTimer?.cancel();
    _walletRetryTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      ref.invalidate(tripBalancesProvider(widget.groupId));
      ref.invalidate(tripBalancesWithTimeoutProvider(widget.groupId));
    });
  }

  @override
  Widget build(BuildContext context) {
    final tripDetailAsync = ref.watch(tripDetailProvider(widget.groupId));
    final balancesAsync = ref.watch(
      tripBalancesWithTimeoutProvider(widget.groupId),
    );
    final debtsAsync = ref.watch(tripDebtsProvider(widget.groupId));

    // Auto-retry once when the wallet balances fail (e.g. Vercel cold-start timeout)
    ref.listen<AsyncValue<List<BalanceEntry>>>(
      tripBalancesWithTimeoutProvider(widget.groupId),
      (prev, next) {
        if (next.hasError && !(prev?.hasError ?? false)) {
          _scheduleWalletAutoRetry();
        }
      },
    );

    return tripDetailAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, _) => Scaffold(
        appBar: AppBar(title: const Text('เกิดข้อผิดพลาด')),
        body: RetryErrorState(
          error: err,
          onRetry: () {
            ref.invalidate(tripDetailProvider(widget.groupId));
            ref.invalidate(tripExpensesProvider(widget.groupId));
            ref.invalidate(tripDebtsProvider(widget.groupId));
            ref.invalidate(tripBalancesProvider(widget.groupId));
            ref.invalidate(tripBalancesWithTimeoutProvider(widget.groupId));
            _loadInitialData();
          },
        ),
      ),
      data: (detail) {
        if (detail == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('ไม่พบข้อมูลกลุ่ม')),
          );
        }

        final trip = detail.trip;
        final members = detail.members;

        // Store myMemberId from trip detail
        if (_myMemberId == null && detail.myMemberId != null) {
          _myMemberId = detail.myMemberId;
        }

        return Scaffold(
          backgroundColor: Colors.grey[50],
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                _buildSliverAppBar(trip, detail, members, balancesAsync),
                SliverPersistentHeader(
                  delegate: _SliverAppBarDelegate(
                    TabBar(
                      controller: _tabController,
                      labelColor: const Color(0xFF81CEF2),
                      unselectedLabelColor: const Color(
                        0xFF9E9E9E,
                      ), // Light grey
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicator: const HalfWidthTabIndicator(
                        color: Color(0xFF81CEF2),
                        thickness: 3,
                        widthFactor: 0.5,
                        radius: 2,
                      ),
                      labelStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.normal,
                      ),
                      tabs: const [
                        Tab(text: 'รายการทั้งหมด'),
                        Tab(text: 'ใครติดเงินใคร'),
                      ],
                    ),
                  ),
                  pinned: true,
                ),
              ];
            },
            body: ColoredBox(
              color: Colors.white,
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Bill list
                  _buildExpensesTab(),
                  // Tab 2: Who Owes Who (pairwise debts)
                  _buildDebtsTab(debtsAsync),
                ],
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'addBillFab',
            onPressed: () async {
              // Navigate to add expense with trip context
              final result = await context.push<bool>(
                '/add_expense',
                extra: {
                  'tripId': widget.groupId,
                  'tripName': trip.name,
                  'members': members,
                },
              );
              if (result == true) {
                _reloadExpenses();
                ref.invalidate(tripDebtsProvider(widget.groupId));
              }
            },
            backgroundColor: const Color(0xFF81CEF2),
            icon: const Icon(AppIcons.receipt, color: Colors.white),
            label: const Text(
              'เพิ่มบิล',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSliverAppBar(
    Trip trip,
    TripDetailResponse detail,
    List<TripMember> members,
    AsyncValue<List<BalanceEntry>> balancesAsync,
  ) {
    return SliverAppBar(
      expandedHeight: _expandedHeaderHeight,
      pinned: true,
      stretch: true,
      backgroundColor: const Color(0xFF81CEF2),
      centerTitle: true,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.4),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(AppIcons.arrowBack, color: Colors.white, size: 20),
            onPressed: () {
              Navigator.of(context).maybePop();
            },
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.4),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(
                AppIcons.settings,
                color: Colors.white,
                size: 20,
              ),
              onPressed: () async {
                if (detail.myRole != 'admin') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'เฉพาะผู้ดูแลกลุ่มเท่านั้นที่แก้ไขข้อมูลกลุ่มได้',
                      ),
                    ),
                  );
                  return;
                }

                final updated = await context.push<bool>(
                  '/groups/create',
                  extra: {'trip': trip, 'members': members},
                );

                if (!mounted) return;

                if (updated == true) {
                  ref.invalidate(tripDetailProvider(widget.groupId));
                  ref.invalidate(tripDebtsProvider(widget.groupId));
                  ref.invalidate(tripBalancesProvider(widget.groupId));
                  ref.invalidate(
                    tripBalancesWithTimeoutProvider(widget.groupId),
                  );
                  await _loadInitialData();
                }
              },
            ),
          ),
        ),
      ],
      flexibleSpace: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          // Calculate the collapse percentage (0.0 = fully expanded, 1.0 = fully collapsed)
          final top = constraints.biggest.height;
          // Typical height when pinned is kToolbarHeight + safe area top
          final safeAreaTop = MediaQuery.of(context).padding.top;
          final pinnedHeight = kToolbarHeight + safeAreaTop;

          double collapseFraction = 0.0;
          if (top <= pinnedHeight) {
            collapseFraction = 1.0;
          } else if (top < _expandedHeaderHeight) {
            collapseFraction =
                1.0 -
                ((top - pinnedHeight) / (_expandedHeaderHeight - pinnedHeight));
          }

          // We want the pinned title to start appearing late in the scroll
          final titleOpacity = (collapseFraction - 0.7).clamp(0.0, 0.3) / 0.3;
          // We want the expanded badges/titles to fade out early
          final expandedOpacity = (1 - (collapseFraction * 2)).clamp(0.0, 1.0);
          // Fade wallet card out while collapsing so it doesn't stay pinned on top.
          final walletOpacity = (1 - (collapseFraction * 2.2)).clamp(0.0, 1.0);
          final walletState = _resolveWalletState(
            balancesAsync,
            detail.myMemberId ?? _myMemberId,
          );
          final shortWalletText = walletState.hasBalanceData
              ? 'สถานะ: ${walletState.netBalance! >= 0 ? "รอรับเงิน" : "ค้างจ่าย"} ${walletState.netBalance!.abs().toStringAsFixed(2)}฿'
              : (walletState.isLoading
                    ? 'สถานะ: กำลังโหลด...'
                    : walletState.hasTimedOut
                    ? 'สถานะ: โหลดข้อมูลไม่สำเร็จ'
                    : 'สถานะ: ไม่พบข้อมูล');
          final shortWalletColor = walletState.hasBalanceData
              ? (walletState.netBalance! >= 0
                    ? Colors.greenAccent
                    : const Color(0xFFFF5252))
              : Colors.white;

          return Stack(
            fit: StackFit.expand,
            children: [
              Container(color: Colors.grey[50]),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: _coverHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (trip.coverUrl != null)
                      Image.network(trip.coverUrl!, fit: BoxFit.cover)
                    else
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF81CEF2),
                              const Color(0xFF81CEF2).withValues(alpha: 0.7),
                            ],
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            trip.category.icon,
                            size: 80,
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                    // Gradient overlay
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.3),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.6),
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Solid App Bar Fade
              if (titleOpacity > 0)
                Positioned.fill(
                  child: Opacity(
                    opacity: titleOpacity,
                    child: Container(color: const Color(0xFF81CEF2)),
                  ),
                ),
              // Pinned Center Title
              if (titleOpacity > 0)
                Positioned(
                  top:
                      safeAreaTop +
                      (kToolbarHeight - 44) /
                          2, // Exact vertical offset for 44px content
                  left: 60,
                  right: 60,
                  child: Opacity(
                    opacity: titleOpacity,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          trip.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          shortWalletText,
                          style: TextStyle(
                            color: shortWalletColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              // Trip Info Badges (Original expanded layout)
              Positioned(
                bottom:
                    (_expandedHeaderHeight - _coverHeight) +
                    _walletCardTopOverlap +
                    28,
                left: 20,
                right: 20,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 100),
                  opacity: expandedOpacity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              trip.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                height: 1.2,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  AppIcons.people,
                                  color: Colors.white,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${members.length} คน',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8C9E6C), // Muted green
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  trip.category.icon,
                                  color: Colors.white,
                                  size: 14,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  trip.category.displayName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (trip.startDate != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    AppIcons.flightTakeoff,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _formatDateRange(
                                      trip.startDate!,
                                      trip.endDate,
                                    ),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
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
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 12,
                child: IgnorePointer(
                  ignoring: walletOpacity < 0.05,
                  child: Opacity(
                    opacity: walletOpacity,
                    child: Transform.translate(
                      offset: Offset(0, -24 * (1 - walletOpacity)),
                      child: _buildWalletCard(walletState),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  _WalletState _resolveWalletState(
    AsyncValue<List<BalanceEntry>> balancesAsync,
    String? myMemberId,
  ) {
    final walletError = balancesAsync.maybeWhen<Object?>(
      error: (error, _) => error,
      orElse: () => null,
    );
    final isLoading = balancesAsync.isLoading;
    final hasTimedOut = walletError is TimeoutException;

    final myBalanceEntry = balancesAsync.maybeWhen(
      data: (entries) {
        if (myMemberId == null) return null;
        for (final entry in entries) {
          if (entry.memberId == myMemberId) {
            return entry;
          }
        }
        return null;
      },
      orElse: () => null,
    );

    return _WalletState(
      netBalance: myBalanceEntry?.net,
      isLoading: isLoading,
      hasTimedOut: hasTimedOut,
    );
  }

  Widget _buildWalletCard(_WalletState walletState) {
    final hasBalanceData = walletState.hasBalanceData;
    final netBalance = walletState.netBalance;
    final statusLabel = hasBalanceData
        ? (netBalance! >= 0 ? 'รอรับเงิน' : 'ค้างจ่าย')
        : (walletState.isLoading
              ? 'กำลังโหลด...'
              : walletState.hasTimedOut
              ? 'โหลดข้อมูลไม่สำเร็จ'
              : 'ไม่พบข้อมูล');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'สถานะกระเป๋าตังค์',
                      style: TextStyle(
                        color: Color(0xFF4A4A4A),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      statusLabel,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF757575),
                      ),
                    ),
                  ],
                ),
                if (hasBalanceData)
                  Text(
                    '${netBalance! >= 0 ? "" : "- "}${netBalance.abs().toStringAsFixed(2)}฿',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: netBalance >= 0
                          ? Colors.green
                          : const Color(0xFFFF5252),
                    ),
                  )
                else if (walletState.isLoading)
                  const _WalletAmountShimmer()
                else
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF81CEF2)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      tooltip: 'ลองโหลดใหม่',
                      onPressed: () {
                        ref.invalidate(tripBalancesProvider(widget.groupId));
                        ref.invalidate(
                          tripBalancesWithTimeoutProvider(widget.groupId),
                        );
                      },
                      icon: Icon(
                        walletState.hasTimedOut
                            ? AppIcons.refresh
                            : AppIcons.refresh,
                        color: const Color(0xFF81CEF2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      context.push(
                        '/manage-balance',
                        extra: {'groupId': widget.groupId},
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF81CEF2),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(AppIcons.wallet, size: 20),
                    label: const Text(
                      'จัดการยอดเงิน',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFF81CEF2),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: IconButton(
                    padding: const EdgeInsets.all(12),
                    onPressed: () {
                      // Show chart/summary
                    },
                    icon: const Icon(
                      AppIcons.barChart,
                      color: Color(0xFF81CEF2),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateRange(DateTime start, DateTime? end) {
    final startStr = '${start.day}/${start.month}/${start.year + 543}';
    if (end == null) return startStr;
    final endStr = '${end.day}/${end.month}/${end.year + 543}';
    return '$startStr - $endStr';
  }

  // =========================================================================
  // Tab 1: Bill List
  // =========================================================================

  Widget _buildExpensesTab() {
    if (_isInitialLoad) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_expenses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(AppIcons.receipt, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text('ยังไม่มีรายการ', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    // Group expenses by date
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _expenses.length,
      itemBuilder: (context, index) {
        final expense = _expenses[index];

        // Show date header if first item or different date from previous
        Widget? dateHeader;
        final currentDate = _parseExpenseDate(expense.expenseDate);
        if (index == 0) {
          dateHeader = _buildDateHeader(currentDate, isFirstHeader: true);
        } else {
          final prevDate = _parseExpenseDate(_expenses[index - 1].expenseDate);
          if (!_isSameDay(currentDate, prevDate)) {
            dateHeader = _buildDateHeader(currentDate);
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (dateHeader != null) dateHeader,
            _buildExpenseCard(expense),
          ],
        );
      },
    );
  }

  DateTime _parseExpenseDate(String dateStr) {
    return DateTime.tryParse(dateStr) ?? DateTime.now();
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildDateHeader(DateTime date, {bool isFirstHeader = false}) {
    // Format Thai-style date
    final thaiMonths = [
      '',
      'มกราคม',
      'กุมภาพันธ์',
      'มีนาคม',
      'เมษายน',
      'พฤษภาคม',
      'มิถุนายน',
      'กรกฎาคม',
      'สิงหาคม',
      'กันยายน',
      'ตุลาคม',
      'พฤศจิกายน',
      'ธันวาคม',
    ];
    final thaiYear = date.year + 543;
    final dateText = '${date.day} ${thaiMonths[date.month]} $thaiYear';

    return Padding(
      padding: EdgeInsets.only(top: isFirstHeader ? 0 : 16, bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            dateText,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Color(0xFF4A4A4A),
            ),
          ),
          // Only show filter icon on the first date
          if (dateText ==
                  '${DateTime.now().day} ${thaiMonths[DateTime.now().month]} ${DateTime.now().year + 543}' ||
              true) // Hardcoding for exact match placeholder
            Icon(AppIcons.tune, size: 20, color: const Color(0xFF4A4A4A)),
        ],
      ),
    );
  }

  /// Determine status label for a bill relative to the current user
  _BillStatus _getBillStatus(Expense expense) {
    final myId = _myMemberId;
    if (myId == null) {
      return _BillStatus.notInvolved;
    }

    // Find user's split in this expense
    final mySplits = expense.splits.where((s) => s.memberId == myId).toList();
    final mySplit = mySplits.isNotEmpty ? mySplits.first : null;
    final isPayer = expense.payerId == myId;

    if (isPayer) {
      // As payer, show "รอรับเงิน" while someone else is still unpaid.
      final hasUnpaidFromOthers = expense.splits.any(
        (s) => s.memberId != myId && s.status != 'paid',
      );
      if (hasUnpaidFromOthers) {
        return _BillStatus.othersOweYou;
      }
      return _BillStatus.cleared;
    }

    // Not payer
    if (mySplit == null) {
      return _BillStatus.notInvolved;
    }

    if (mySplit.status != 'paid') {
      return _BillStatus.youOwe;
    }

    return _BillStatus.cleared;
  }

  double _sumAmounts(Iterable<ExpenseSplitSummary> splits) {
    return splits.fold(0.0, (sum, split) => sum + split.amount);
  }

  double _amountForStatus(Expense expense, _BillStatus status) {
    final myId = _myMemberId;
    if (myId == null) {
      return expense.amount;
    }

    final mySplit = expense.splits.where((s) => s.memberId == myId).toList();
    final myShare = mySplit.isNotEmpty ? mySplit.first.amount : 0.0;
    final otherSplits = expense.splits
        .where((s) => s.memberId != myId)
        .toList();
    final unpaidOtherSplits = otherSplits.where((s) => s.status != 'paid');
    final isPayer = expense.payerId == myId;

    switch (status) {
      case _BillStatus.youOwe:
        return myShare;
      case _BillStatus.othersOweYou:
        return _sumAmounts(unpaidOtherSplits);
      case _BillStatus.cleared:
        if (isPayer) {
          // In single-member/self-paid bills, there is no counterparty amount.
          if (otherSplits.isEmpty) return expense.amount;
          return _sumAmounts(otherSplits);
        }
        return myShare > 0 ? myShare : expense.amount;
      case _BillStatus.notInvolved:
        return expense.amount;
    }
  }

  String _clearedMessage(Expense expense) {
    final myId = _myMemberId;
    if (myId == null) return 'คุณเคลียร์เรียบร้อยแล้ว';

    final isPayer = expense.payerId == myId;
    final otherSplits = expense.splits
        .where((s) => s.memberId != myId)
        .toList();

    if (!isPayer) {
      final payeeName = expense.payer?.displayName;
      if (payeeName != null && payeeName != 'Unknown') {
        return 'คุณจ่ายคืน $payeeName แล้ว';
      }
      return 'คุณเคลียร์เรียบร้อยแล้ว';
    }

    if (otherSplits.isEmpty) {
      return 'คุณเคลียร์เรียบร้อยแล้ว';
    }

    if (otherSplits.length == 1) {
      final otherName = _memberNameById[otherSplits.first.memberId];
      if (otherName != null && otherName.isNotEmpty) {
        return '$otherNameจ่ายคืน คุณ แล้ว';
      }
      return 'มีคนจ่ายคืน คุณ แล้ว';
    }

    return 'ทุกคนจ่ายคืน คุณ แล้ว';
  }

  Widget _buildExpenseCard(Expense expense) {
    final status = _getBillStatus(expense);
    final displayAmount = _amountForStatus(expense, status);
    final payerLabel = _buildPayerLabel(expense);

    // Find user's specific owe amount
    double? userOweAmount;
    if (status == _BillStatus.youOwe && _myMemberId != null) {
      final mySplit = expense.splits.where((s) => s.memberId == _myMemberId);
      if (mySplit.isNotEmpty) {
        userOweAmount = mySplit.first.amount;
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final result = await context.push('/expenses/${expense.id}');
          if (result == true) {
            _reloadExpenses();
            ref.invalidate(tripDebtsProvider(widget.groupId));
            ref.invalidate(tripExpensesProvider(widget.groupId));
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              // Category icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: expense.categoryColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  expense.categoryIcon,
                  size: 24,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              // Description & subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expense.description,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      payerLabel,
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              // Status label
              _buildStatusLabel(
                status,
                userOweAmount,
                displayAmount,
                expense.payer?.displayName,
                _clearedMessage(expense),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _buildPayerLabel(Expense expense) {
    final payerNames = <String>[];

    for (final payer in expense.payers) {
      final name = payer.displayName.trim();
      if (name.isNotEmpty && name != 'Unknown' && !payerNames.contains(name)) {
        payerNames.add(name);
      }
    }

    if (payerNames.isEmpty) {
      final fallback = expense.payer?.displayName.trim();
      if (fallback != null && fallback.isNotEmpty && fallback != 'Unknown') {
        payerNames.add(fallback);
      }
    }

    if (payerNames.isEmpty) {
      return 'มีคนจ่าย';
    }

    if (payerNames.length == 1) {
      return '${payerNames.first}จ่าย';
    }

    if (payerNames.length == 2) {
      return '${payerNames[0]} และ ${payerNames[1]}'
          'จ่าย';
    }

    final head = payerNames.sublist(0, payerNames.length - 1).join(', ');
    final tail = payerNames.last;
    return '$head และ $tail'
        'จ่าย';
  }

  Widget _buildStatusLabel(
    _BillStatus status,
    double? userOweAmount,
    double displayAmount,
    String? payerName,
    String clearedMessage,
  ) {
    switch (status) {
      case _BillStatus.youOwe:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text(
              'คุณค้างจ่าย',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFFFF5252),
                fontWeight: FontWeight.normal,
              ),
            ),
            if (userOweAmount != null)
              Text(
                '${userOweAmount.toStringAsFixed(2)}฿',
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFFFF5252),
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        );
      case _BillStatus.othersOweYou:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text(
              'คุณรอรับเงิน',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF4CAF50),
                fontWeight: FontWeight.normal,
              ),
            ),
            Text(
              '${displayAmount.toStringAsFixed(2)}฿',
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF4CAF50),
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        );
      case _BillStatus.cleared:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${displayAmount.toStringAsFixed(2)}฿',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF4A4A4A),
                fontWeight: FontWeight.normal,
              ),
            ),
            Text(
              clearedMessage,
              style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
            ),
          ],
        );
      case _BillStatus.notInvolved:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text(
              'คุณไม่มีส่วนเกี่ยวข้อง',
              style: TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
            ),
            if (payerName != null && payerName != 'Unknown')
              Text(
                'จ่ายโดย $payerName',
                style: TextStyle(fontSize: 11, color: Colors.grey[400]),
              ),
          ],
        );
    }
  }

  // =========================================================================
  // Tab 2: Who Owes Who (Debt Simplification)
  // =========================================================================

  Widget _buildDebtsTab(AsyncValue<List<DebtEntry>> debtsAsync) {
    return debtsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => RetryErrorState(
        error: err,
        onRetry: () => ref.invalidate(tripDebtsProvider(widget.groupId)),
      ),
      data: (debts) {
        if (debts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(AppIcons.checkCircle, size: 64, color: Colors.green[300]),
                const SizedBox(height: 16),
                const Text(
                  'ไม่มียอดค้างชำระ',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        // Get current user ID to separate "my debts" from "others' debts"
        final currentUserId = SupabaseConfig.client.auth.currentUser?.id;

        // Separate: my debts vs others
        final myDebts = debts
            .where(
              (d) =>
                  d.fromUserId == currentUserId || d.toUserId == currentUserId,
            )
            .toList();
        final otherDebts = debts
            .where(
              (d) =>
                  d.fromUserId != currentUserId && d.toUserId != currentUserId,
            )
            .toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (myDebts.isNotEmpty) ...[
              _buildDebtSectionHeader('รายการของฉัน'),
              const SizedBox(height: 8),
              ...myDebts.map((d) => _buildDebtCard(d, currentUserId)),
              const SizedBox(height: 16),
            ],
            if (otherDebts.isNotEmpty) ...[
              _buildDebtSectionHeader('เพื่อนคนอื่น'),
              const SizedBox(height: 8),
              ...otherDebts.map((d) => _buildDebtCard(d, currentUserId)),
            ],
          ],
        );
      },
    );
  }

  Widget _buildDebtSectionHeader(String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        Icon(AppIcons.tune, size: 20, color: Colors.grey[400]),
      ],
    );
  }

  Widget _buildDebtCard(DebtEntry debt, String? currentUserId) {
    final iOwe = debt.fromUserId == currentUserId;
    final theyOweMe = debt.toUserId == currentUserId;

    // Determine display info
    String displayName;
    String? avatarUrl;
    String statusText;
    Color statusColor;

    if (iOwe) {
      displayName = debt.toName;
      avatarUrl = debt.toAvatarUrl;
      statusText = 'คุณค้างจ่าย ${debt.amount.toStringAsFixed(2)}฿';
      statusColor = Colors.red;
    } else if (theyOweMe) {
      displayName = debt.fromName;
      avatarUrl = debt.fromAvatarUrl;
      statusText = 'คุณรอรับเงิน ${debt.amount.toStringAsFixed(2)}฿';
      statusColor = Colors.green;
    } else {
      displayName = debt.fromName;
      avatarUrl = debt.fromAvatarUrl;
      statusText = 'ค้างจ่าย ${debt.toName} ${debt.amount.toStringAsFixed(2)}฿';
      statusColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          if (iOwe) {
            if (!mounted) return;

            // Navigate to payment
            final result = await context.push<bool?>(
              '/payment',
              extra: {
                'amount': debt.amount,
                'memberId': debt.toMemberId,
                'tripId': widget.groupId,
                'payeeName': debt.toName,
                'payeeAvatarUrl': debt.toAvatarUrl,
                'promptpayId': null,
                'expenseSplitIds': debt.expenseSplitIds,
                'counterExpenseSplitIds': debt.counterExpenseSplitIds,
              },
            );

            if (result == true && mounted) {
              ref.invalidate(tripDebtsProvider(widget.groupId));
              ref.invalidate(tripExpensesProvider(widget.groupId));
              ref.invalidate(tripBalancesProvider(widget.groupId));
            }
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFF81CEF2).withValues(alpha: 0.2),
                backgroundImage: avatarUrl != null
                    ? NetworkImage(avatarUrl)
                    : null,
                child: avatarUrl == null
                    ? Text(
                        displayName.isNotEmpty
                            ? displayName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 13,
                        color: statusColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (iOwe || theyOweMe)
                Icon(AppIcons.chevronRight, color: Colors.grey[400]),
              if (theyOweMe)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(
                    AppIcons.notificationsActive,
                    size: 20,
                    color: const Color(0xFF81CEF2),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // Dialogs
  // =========================================================================
}

class _WalletAmountShimmer extends StatefulWidget {
  const _WalletAmountShimmer();

  @override
  State<_WalletAmountShimmer> createState() => _WalletAmountShimmerState();
}

class _WalletAmountShimmerState extends State<_WalletAmountShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) {
            final dx = (_controller.value * 2) - 1;
            return LinearGradient(
              begin: Alignment(dx - 1, 0),
              end: Alignment(dx + 1, 0),
              colors: const [
                Color(0xFFE6E9EE),
                Color(0xFFF4F7FB),
                Color(0xFFE6E9EE),
              ],
            ).createShader(rect);
          },
          child: child,
        );
      },
      child: Container(
        width: 88,
        height: 24,
        decoration: BoxDecoration(
          color: const Color(0xFFE6E9EE),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

class _WalletState {
  final double? netBalance;
  final bool isLoading;
  final bool hasTimedOut;

  const _WalletState({
    required this.netBalance,
    required this.isLoading,
    required this.hasTimedOut,
  });

  bool get hasBalanceData => netBalance != null;
}

/// Bill status for current user
enum _BillStatus {
  youOwe, // You have unpaid split
  othersOweYou, // You're the payer and others haven't paid
  cleared, // All cleared
  notInvolved, // You're not part of this bill
}

// Helper delegate for sticky TabBar
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
