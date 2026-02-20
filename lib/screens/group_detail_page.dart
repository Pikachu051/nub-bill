import 'package:flutter/material.dart';
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
import 'package:nubbill/config/supabase_config.dart';
import 'package:nubbill/widgets/retry_error_state.dart';

class GroupDetailPage extends ConsumerStatefulWidget {
  final String groupId;

  const GroupDetailPage({super.key, required this.groupId});

  @override
  ConsumerState<GroupDetailPage> createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends ConsumerState<GroupDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  StreamSubscription? _expenseSubscription;

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
    _expenseSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tripDetailAsync = ref.watch(tripDetailProvider(widget.groupId));
    final debtsAsync = ref.watch(tripDebtsProvider(widget.groupId));

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
                _buildSliverAppBar(trip, detail, members),
                SliverToBoxAdapter(child: _buildHeaderContent(trip, members)),
                SliverPersistentHeader(
                  delegate: _SliverAppBarDelegate(
                    TabBar(
                      controller: _tabController,
                      labelColor: const Color(0xFF81CEF2),
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: const Color(0xFF81CEF2),
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
            body: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Bill list
                _buildExpensesTab(),
                // Tab 2: Who Owes Who (pairwise debts)
                _buildDebtsTab(debtsAsync),
              ],
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
            icon: const Icon(Icons.receipt_long, color: Colors.white),
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
  ) {
    return SliverAppBar(
      expandedHeight: 240.0,
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
            icon: const Icon(Icons.arrow_back, color: Colors.white),
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
              icon: const Icon(Icons.settings, color: Colors.white),
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
                  await _loadInitialData();
                }
              },
            ),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        stretchModes: const [StretchMode.zoomBackground, StretchMode.fadeTitle],
        title: Column(
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
            ),
            if (trip.balance != 0)
              Text(
                'สถานะ: ${trip.balance >= 0 ? "รอรับเงิน" : "ค้างจ่าย"} ${trip.balance.abs().toStringAsFixed(2)}฿',
                style: TextStyle(
                  color: trip.balance >= 0
                      ? Colors.greenAccent
                      : Colors.redAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
          ],
        ),
        titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
        background: Stack(
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
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
            ),
            // Trip Info Badges
            Positioned(
              bottom: 70, // Above the title area when expanded
              left: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${members.length} คน',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8C9E6C), // Muted green
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              trip.category.icon, // Use category icon
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              trip.category.displayName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (trip.startDate != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.calendar_today,
                                color: Colors.white,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatDateRange(trip.startDate!, trip.endDate),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
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
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderContent(Trip trip, List<TripMember> members) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Personal Balance Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
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
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          trip.balance >= 0 ? 'รอรับเงิน' : 'ค้างจ่าย',
                          style: TextStyle(
                            fontSize: 14,
                            color: trip.balance >= 0
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${trip.balance >= 0 ? "" : "- "}${trip.balance.abs().toStringAsFixed(2)}฿',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: trip.balance >= 0 ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          context.push('/payment');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF81CEF2),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.camera_alt, size: 18),
                        label: const Text('จัดการยอดเงิน'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFF81CEF2)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        onPressed: () {
                          // Show chart/summary
                        },
                        icon: const Icon(
                          Icons.bar_chart,
                          color: Color(0xFF81CEF2),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
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
            Icon(Icons.receipt_long, size: 64, color: Colors.grey[300]),
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
          dateHeader = _buildDateHeader(currentDate);
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

  Widget _buildDateHeader(DateTime date) {
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
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            dateText,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
          Icon(Icons.tune, size: 20, color: Colors.grey[400]),
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
          final result = await context.push('/expenses/${expense.id}');
          if (result == true) {
            _reloadExpenses();
            ref.invalidate(tripDebtsProvider(widget.groupId));
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              // Category icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: expense.categoryColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  expense.categoryIcon,
                  size: 22,
                  color: Colors.black54,
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
            Text(
              'คุณค้างจ่าย',
              style: TextStyle(
                fontSize: 12,
                color: Colors.red[400],
                fontWeight: FontWeight.w500,
              ),
            ),
            if (userOweAmount != null)
              Text(
                '${userOweAmount.toStringAsFixed(2)}฿',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.red[400],
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        );
      case _BillStatus.othersOweYou:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'คุณรอรับเงิน',
              style: TextStyle(
                fontSize: 12,
                color: Colors.green[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${displayAmount.toStringAsFixed(2)}฿',
              style: TextStyle(
                fontSize: 15,
                color: Colors.green[600],
                fontWeight: FontWeight.bold,
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
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              clearedMessage,
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          ],
        );
      case _BillStatus.notInvolved:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'คุณไม่มีส่วนเกี่ยวข้อง',
              style: TextStyle(fontSize: 12, color: Colors.grey[400]),
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
                Icon(
                  Icons.check_circle_outline,
                  size: 64,
                  color: Colors.green[300],
                ),
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
        Icon(Icons.tune, size: 20, color: Colors.grey[400]),
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
        onTap: () {
          if (iOwe) {
            // Navigate to payment
            context.push(
              '/payment',
              extra: {'amount': debt.amount, 'memberId': debt.toMemberId},
            );
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
                Icon(Icons.chevron_right, color: Colors.grey[400]),
              if (theyOweMe)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(
                    Icons.notifications_active,
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
      color: Colors.transparent,
      child: Transform.translate(
        offset: const Offset(0, -16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: _tabBar,
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
