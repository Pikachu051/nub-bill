import 'package:flutter/material.dart';
import 'package:nubbill/shared/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nubbill/models/expense_model.dart';
import 'package:nubbill/models/trip_member_model.dart';
import 'package:nubbill/screens/friend_bills_page.dart';
import 'package:nubbill/services/expense_service.dart';
import 'package:nubbill/services/friend_service.dart';
import 'package:nubbill/services/payment_service.dart';
import 'package:nubbill/services/trip_service.dart';
import 'package:nubbill/models/debt_entry_model.dart';
import 'package:nubbill/widgets/half_width_tab_indicator.dart';
import 'package:nubbill/widgets/retry_error_state.dart';

class ManageBalancePage extends ConsumerStatefulWidget {
  final String groupId;

  const ManageBalancePage({super.key, required this.groupId});

  @override
  ConsumerState<ManageBalancePage> createState() => _ManageBalancePageState();
}

class _ManageBalancePageState extends ConsumerState<ManageBalancePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final Set<String> _locallyVerifiedSplitIds = <String>{};
  final Set<String> _manualVerifyingMembers = <String>{};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tripDetailAsync = ref.watch(tripDetailProvider(widget.groupId));
    final expensesAsync = ref.watch(tripExpensesProvider(widget.groupId));
    final debtsAsync = ref.watch(tripDebtsProvider(widget.groupId));

    return tripDetailAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        appBar: _buildAppBar(context),
        body: RetryErrorState(
          error: error,
          onRetry: () => ref.invalidate(tripDetailProvider(widget.groupId)),
        ),
      ),
      data: (tripDetail) {
        if (tripDetail == null || tripDetail.myMemberId == null) {
          return Scaffold(
            appBar: _buildAppBar(context),
            body: const Center(child: Text('ไม่พบข้อมูลสมาชิกของคุณในกลุ่ม')),
          );
        }

        final myMemberId = tripDetail.myMemberId!;
        final memberById = <String, TripMember>{
          for (final member in tripDetail.members) member.id: member,
        };

        return expensesAsync.when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (error, _) => Scaffold(
            appBar: _buildAppBar(context),
            body: RetryErrorState(
              error: error,
              onRetry: () =>
                  ref.invalidate(tripExpensesProvider(widget.groupId)),
            ),
          ),
          data: (expenses) {
            final debtByCounterparty = <String, DebtEntry>{
              for (final entry in debtsAsync.value ?? [])
                if (entry.fromMemberId == myMemberId) entry.toMemberId: entry,
            };
            final collectDebtByFriend = <String, DebtEntry>{
              for (final entry in debtsAsync.value ?? [])
                if (entry.toMemberId == myMemberId) entry.fromMemberId: entry,
            };
            final grouped = _groupFriendBalances(
              expenses: expenses,
              myMemberId: myMemberId,
              memberById: memberById,
              debtByCounterparty: debtByCounterparty,
              collectDebtByFriend: collectDebtByFriend,
            );

            return Scaffold(
              backgroundColor: const Color(0xFFF4F4F4),
              appBar: _buildAppBar(context),
              body: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Color(0xFFD8D8D8), width: 1),
                      ),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      labelColor: const Color(0xFF81CEF2),
                      unselectedLabelColor: const Color(0xFF7E7E7E),
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicator: const HalfWidthTabIndicator(
                        color: Color(0xFF81CEF2),
                        thickness: 3,
                        widthFactor: 0.5,
                        radius: 2,
                      ),
                      labelStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                      tabs: const [
                        Tab(text: 'ค้างจ่าย'),
                        Tab(text: 'รอรับ'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildPayTab(grouped.oweSummaries),
                        _buildCollectTab(
                          summaries: grouped.collectSummaries,
                          myMemberId: myMemberId,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFFF4F4F4),
      surfaceTintColor: const Color(0xFFF4F4F4),
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(
          AppIcons.chevronLeft,
          color: Color(0xFF5E5E5E),
          size: 26,
        ),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: const Text(
        'จัดการยอดเงิน',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Color.fromARGB(179, 14, 14, 16),
        ),
      ),
    );
  }

  Widget _buildPayTab(List<_FriendDebtSummary> summaries) {
    final total = summaries.fold<double>(
      0,
      (sum, summary) => sum + summary.totalAmount,
    );

    return Column(
      children: [
        Expanded(
          child: summaries.isEmpty
              ? const _EmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                  itemCount: summaries.length,
                  itemBuilder: (context, index) {
                    final summary = summaries[index];
                    return _FriendSummaryRow(
                      key: ValueKey('owe-${summary.memberId}'),
                      summary: summary,
                      isPayTab: true,
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute<bool>(
                            builder: (_) => FriendBillsPage(
                              groupId: widget.groupId,
                              friendName: summary.name,
                              friendMemberId: summary.memberId,
                              friendAvatarUrl: summary.avatarUrl,
                              bills: summary.bills,
                              counterSplitIds: summary.counterSplitIds,
                              allForwardSplitIds: summary.allForwardSplitIds,
                            ),
                          ),
                        );
                        ref.invalidate(tripExpensesProvider(widget.groupId));
                        ref.invalidate(tripDebtsProvider(widget.groupId));
                        ref.invalidate(tripBalancesProvider(widget.groupId));
                      },
                    );
                  },
                ),
        ),
        _TotalBar(
          label: 'รวมยอดค้างจ่ายทั้งหมด:',
          total: total,
          amountColor: const Color(0xFFFF7373),
        ),
      ],
    );
  }

  Widget _buildCollectTab({
    required List<_FriendDebtSummary> summaries,
    required String myMemberId,
  }) {
    final total = summaries.fold<double>(
      0,
      (sum, summary) => sum + summary.totalAmount,
    );

    return Column(
      children: [
        Expanded(
          child: summaries.isEmpty
              ? const _EmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                  itemCount: summaries.length,
                  itemBuilder: (context, index) {
                    final summary = summaries[index];

                    return _FriendSummaryRow(
                      key: ValueKey('collect-${summary.memberId}'),
                      summary: summary,
                      isPayTab: false,
                      onRemind: () => _onRemindPressed(summary),
                      isVerifying: _manualVerifyingMembers.contains(
                        summary.memberId,
                      ),
                      onManualVerify: () =>
                          _onManualVerifyPressed(summary, myMemberId),
                    );
                  },
                ),
        ),
        _TotalBar(
          label: 'รวมยอดรอรับทั้งหมด:',
          total: total,
          amountColor: const Color(0xFF37BF61),
        ),
      ],
    );
  }

  Future<void> _onManualVerifyPressed(
    _FriendDebtSummary summary,
    String myMemberId,
  ) async {
    if (_manualVerifyingMembers.contains(summary.memberId) ||
        summary.bills.isEmpty) {
      return;
    }

    final confirmed = await _showManualVerifyDialog(summary.name);
    if (!confirmed) return;

    setState(() {
      _manualVerifyingMembers.add(summary.memberId);
    });

    try {
      final paymentService = ref.read(paymentServiceProvider);
      final settlementSplitIds = summary.allForwardSplitIds.isNotEmpty
          ? summary.allForwardSplitIds
          : summary.bills.map((bill) => bill.splitId).toList();

      final settlementId = await paymentService.createSettlementForManualVerify(
        payerMemberId: summary.memberId,
        payeeMemberId: myMemberId,
        tripId: widget.groupId,
        amount: summary.totalAmount,
        expenseSplitIds: settlementSplitIds,
      );

      await paymentService.manualVerify(settlementId: settlementId);

      if (!mounted) return;
      setState(() {
        _locallyVerifiedSplitIds.addAll(settlementSplitIds);
        _locallyVerifiedSplitIds.addAll(summary.counterSplitIds);
      });

      ref.invalidate(tripExpensesProvider(widget.groupId));
      ref.invalidate(tripDebtsProvider(widget.groupId));
      ref.invalidate(tripBalancesProvider(widget.groupId));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('เคลียร์ยอดเรียบร้อยแล้ว'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ไม่สามารถยืนยันการรับเงินได้: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _manualVerifyingMembers.remove(summary.memberId);
        });
      }
    }
  }

  Future<void> _onRemindPressed(_FriendDebtSummary summary) async {
    final friendUserId = summary.userId;
    if (friendUserId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ไม่สามารถแจ้งเตือนได้สำหรับสมาชิกที่ยังไม่ผูกบัญชี'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final confirmed = await _showRemindDialog(summary.name);
    if (!confirmed || !mounted) return;

    try {
      await ref
          .read(friendServiceProvider)
          .sendPaymentReminder(friendUserId: friendUserId, tripId: widget.groupId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ส่งการแจ้งเตือนไปยัง ${summary.name} แล้ว'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ส่งการแจ้งเตือนไม่สำเร็จ: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<bool> _showRemindDialog(String friendName) async {
    final result = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.42),
      builder: (context) {
        return AlertDialog(
          title: Text('จะเตือน $friendName ละน้า'),
          content: Text('ระบบจะแจ้งเตือนไปยัง $friendName แล้วนะ'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('ยืนยัน'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  Future<bool> _showManualVerifyDialog(String friendName) async {
    final result = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.42),
      builder: (context) {
        return Dialog(
          elevation: 0,
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(AppIcons.wallet, size: 56, color: Color(0xFF8ECFF0)),
                const SizedBox(height: 10),
                const Text(
                  'ได้รับเงินแล้วใช่มั้ย?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF585858),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'ถ้าได้เงินจาก $friendName แล้ว\nกดยืนยันเพื่อเคลียร์ยอดได้เลย',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF959595),
                    height: 1.35,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF92D2F2)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26),
                          ),
                        ),
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text(
                          'ขอดูก่อน',
                          style: TextStyle(
                            color: Color(0xFF8BCDEF),
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF81CEF2),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26),
                          ),
                        ),
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text(
                          'ได้รับแล้ว',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    return result ?? false;
  }

  _GroupedSummaries _groupFriendBalances({
    required List<Expense> expenses,
    required String myMemberId,
    required Map<String, TripMember> memberById,
    Map<String, DebtEntry> debtByCounterparty = const {},
    Map<String, DebtEntry> collectDebtByFriend = const {},
  }) {
    final oweMap = <String, _FriendDebtAccumulator>{};
    final collectMap = <String, _FriendDebtAccumulator>{};

    for (final expense in expenses) {
      for (final split in expense.splits) {
        if (split.status == 'paid') continue;
        if (split.amount <= 0) continue;
        if (_locallyVerifiedSplitIds.contains(split.id)) continue;

        // Use expense_payers for multi-payer support.
        // Fall back to the single payer_id when the list is absent/empty.
        final effectivePayers = expense.payers.isNotEmpty
            ? expense.payers
            : [
                ExpensePayerInfo(
                  memberId: expense.payerId,
                  amount: expense.amount,
                ),
              ];
        final totalPaid =
            effectivePayers.fold(0.0, (s, p) => s + p.amount);
        if (totalPaid <= 0) continue;

        final visual = _buildBillVisual(expense);

        for (final payer in effectivePayers) {
          // A payer does not owe themselves.
          if (payer.memberId == split.memberId) continue;

          // Portion of this split that this specific payer covered.
          final portionOwed = split.amount * payer.amount / totalPaid;
          if (portionOwed < 0.005) continue;

          final bill = FriendBillItem(
            splitId: split.id,
            expenseId: expense.id,
            title: expense.description.isEmpty
                ? 'ไม่ระบุรายการ'
                : expense.description,
            date: _parseDate(expense.expenseDate),
            amount: portionOwed,
            icon: visual.icon,
            iconBackground: visual.background,
          );

          if (split.memberId == myMemberId) {
            // I owe this payer.
            final friend = memberById[payer.memberId];
            oweMap
                .putIfAbsent(
                  payer.memberId,
                  () => _FriendDebtAccumulator(
                    memberId: payer.memberId,
                    name: friend?.displayName ?? 'Unknown',
                    avatarUrl: friend?.avatarUrl,
                    userId: friend?.userId,
                  ),
                )
                .addBill(bill);
          } else if (payer.memberId == myMemberId) {
            // This split member owes me.
            final friend = memberById[split.memberId];
            collectMap
                .putIfAbsent(
                  split.memberId,
                  () => _FriendDebtAccumulator(
                    memberId: split.memberId,
                    name: friend?.displayName ?? 'Unknown',
                    avatarUrl: friend?.avatarUrl,
                    userId: friend?.userId,
                  ),
                )
                .addBill(bill);
          }
        }
      }
    }

    // Net debts between the same two people.
    // If I owe friend X and friend X also owes me, cancel out the smaller side.
    final allFriendIds = <String>{
      ...oweMap.keys,
      ...collectMap.keys,
    };

    // Track split IDs from cancelled counter-obligations so they can be
    // marked paid together with the forward splits.
    final counterSplitsByFriend = <String, List<String>>{};
    // Track ALL forward split IDs (before netting reduction) so the settlement
    // can mark every related split as paid, including the "cancelled" ones.
    final allForwardSplitsByFriend = <String, List<String>>{};

    for (final friendId in allFriendIds) {
      final oweAcc = oweMap[friendId];
      final collectAcc = collectMap[friendId];
      if (oweAcc == null || collectAcc == null) continue;

      final oweTotal = oweAcc.totalAmount;
      final collectTotal = collectAcc.totalAmount;

      if ((oweTotal - collectTotal).abs() < 0.005) {
        // Exactly cancel — remove both
        oweMap.remove(friendId);
        collectMap.remove(friendId);
      } else if (oweTotal > collectTotal) {
        // I still owe net: remove from collect; reduce owe bills greedily.
        // Save the FULL forward split list BEFORE subtractAmount drops entries.
        allForwardSplitsByFriend[friendId] = oweAcc.allSplitIds;
        counterSplitsByFriend[friendId] = collectAcc.allSplitIds;
        collectMap.remove(friendId);
        oweMap[friendId] = oweAcc.subtractAmount(collectTotal);
      } else {
        // Friend still owes me net: remove from owe; reduce collect bills greedily
        oweMap.remove(friendId);
        collectMap[friendId] = collectAcc.subtractAmount(oweTotal);
      }
    }

    List<_FriendDebtSummary> toSortedList(
      Map<String, _FriendDebtAccumulator> source, {
      Map<String, List<String>>? counterSplits,
      Map<String, List<String>>? allForwardSplits,
      Map<String, DebtEntry>? backendLookup,
    }) {
      final list = source.entries.map((entry) {
        final backend = backendLookup?[entry.key];
        return entry.value.toSummary(
          counterSplitIds: backend?.counterExpenseSplitIds
              ?? counterSplits?[entry.key]
              ?? [],
          allForwardSplitIds: backend?.expenseSplitIds
              ?? allForwardSplits?[entry.key]
              ?? [],
        );
      }).toList();
      list.sort((a, b) {
        final amountCompare = b.totalAmount.compareTo(a.totalAmount);
        if (amountCompare != 0) return amountCompare;
        return a.name.compareTo(b.name);
      });
      return list;
    }

    return _GroupedSummaries(
      oweSummaries: toSortedList(
        oweMap,
        counterSplits: counterSplitsByFriend,
        allForwardSplits: allForwardSplitsByFriend,
        backendLookup: debtByCounterparty,
      ),
      collectSummaries: toSortedList(
        collectMap,
        backendLookup: collectDebtByFriend,
      ),
    );
  }

  DateTime _parseDate(String rawDate) {
    try {
      return DateTime.parse(rawDate);
    } catch (_) {
      return DateTime.now();
    }
  }

  _BillVisual _buildBillVisual(Expense expense) {
    final desc = expense.description.toLowerCase();
    if (desc.contains('อาหาร') ||
        desc.contains('ข้าว') ||
        desc.contains('กิน') ||
        desc.contains('มื้อ') ||
        desc.contains('restaurant')) {
      return const _BillVisual(
        icon: AppIcons.restaurant,
        background: Color(0xFFE4CA76),
      );
    }
    if (desc.contains('น้ำมัน') ||
        desc.contains('ค่ารถ') ||
        desc.contains('แท็กซี่') ||
        desc.contains('เดินทาง') ||
        desc.contains('transport')) {
      return const _BillVisual(
        icon: AppIcons.localGasStation,
        background: Color(0xFFA9ADB2),
      );
    }
    if (desc.contains('ที่พัก') ||
        desc.contains('โรงแรม') ||
        desc.contains('hotel') ||
        desc.contains('พัก')) {
      return const _BillVisual(
        icon: AppIcons.home,
        background: Color(0xFFE8B0D4),
      );
    }

    return const _BillVisual(
      icon: AppIcons.receipt,
      background: Color(0xFFB3B9BE),
    );
  }
}

class _FriendSummaryRow extends StatelessWidget {
  final _FriendDebtSummary summary;
  final bool isPayTab;
  final VoidCallback? onTap;
  final VoidCallback? onRemind;
  final VoidCallback? onManualVerify;
  final bool isVerifying;

  const _FriendSummaryRow({
    super.key,
    required this.summary,
    required this.isPayTab,
    this.onTap,
    this.onRemind,
    this.onManualVerify,
    this.isVerifying = false,
  });

  @override
  Widget build(BuildContext context) {
    final amountColor = isPayTab
        ? const Color(0xFFFF7878)
        : const Color(0xFF3FBE67);
    final statusText = isPayTab ? 'คุณค้างจ่าย' : 'คุณรอรับเงิน';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              _AvatarCircle(name: summary.name, avatarUrl: summary.avatarUrl),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            summary.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Color(0xFF5A5A5A),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE3F2FB),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${summary.billCount} รายการ',
                            style: const TextStyle(
                              color: Color(0xFF8BCDEE),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$statusText ${summary.totalAmount.toStringAsFixed(2)}฿',
                      style: TextStyle(
                        fontSize: 14,
                        color: amountColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (isPayTab)
                const Icon(
                  AppIcons.chevronRight,
                  color: Color(0xFFB3B3B3),
                  size: 22,
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _CircleIconButton(
                      icon: AppIcons.notificationsActive,
                      onPressed: onRemind,
                      foregroundColor: const Color(0xFF81CEF2),
                      backgroundColor: Colors.transparent,
                      borderColor: const Color(0xFF8ED0F0),
                    ),
                    const SizedBox(width: 8),
                    _CircleIconButton(
                      icon: isVerifying
                          ? AppIcons.hourglassTop
                          : AppIcons.check,
                      onPressed: isVerifying ? null : onManualVerify,
                      foregroundColor: Colors.white,
                      backgroundColor: const Color(0xFF38BF5E),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  final String name;
  final String? avatarUrl;

  const _AvatarCircle({required this.name, this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 23,
      backgroundColor: const Color(0xFFDDE8EE),
      backgroundImage: avatarUrl != null && avatarUrl!.isNotEmpty
          ? NetworkImage(avatarUrl!)
          : null,
      child: avatarUrl == null || avatarUrl!.isEmpty
          ? Text(
              name.isNotEmpty ? name.substring(0, 1) : '?',
              style: const TextStyle(
                color: Color(0xFF5A5A5A),
                fontWeight: FontWeight.w700,
              ),
            )
          : null,
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color foregroundColor;
  final Color backgroundColor;
  final Color? borderColor;

  const _CircleIconButton({
    required this.icon,
    required this.onPressed,
    required this.foregroundColor,
    required this.backgroundColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 38,
      height: 38,
      child: Material(
        color: backgroundColor,
        shape: CircleBorder(
          side: borderColor == null
              ? BorderSide.none
              : BorderSide(color: borderColor!, width: 2),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Icon(icon, color: foregroundColor, size: 18),
        ),
      ),
    );
  }
}

class _TotalBar extends StatelessWidget {
  final String label;
  final double total;
  final Color amountColor;

  const _TotalBar({
    required this.label,
    required this.total,
    required this.amountColor,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, 14, 20, 14 + bottomInset),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F4),
        border: Border(top: BorderSide(color: Colors.grey.shade200, width: 1)),
      ),
      child: Align(
        alignment: Alignment.centerRight,
        child: RichText(
          textAlign: TextAlign.end,
          text: TextSpan(
            style: const TextStyle(
              color: Color(0xFF7B7B7B),
              fontWeight: FontWeight.w500,
              fontSize: 14,
              fontFamily: 'LINESeedSansTH',
            ),
            children: [
              TextSpan(text: '$label '),
              TextSpan(
                text: '${total.toStringAsFixed(2)}฿',
                style: TextStyle(
                  color: amountColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  fontFamily: 'LINESeedSansTH',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'ไม่มียอดค้างชำระ',
        style: TextStyle(
          color: Color(0xFF9A9A9A),
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _FriendDebtSummary {
  final String memberId;
  final String name;
  final String? avatarUrl;
  final String? userId;
  final List<FriendBillItem> bills;
  final double totalAmount;
  final List<String> counterSplitIds;
  /// All forward split IDs before netting reduction. When non-empty, the
  /// settlement must use these instead of just the visible bill split IDs so
  /// that every related debt is properly cleared in the database.
  final List<String> allForwardSplitIds;

  const _FriendDebtSummary({
    required this.memberId,
    required this.name,
    required this.avatarUrl,
    required this.userId,
    required this.bills,
    required this.totalAmount,
    this.counterSplitIds = const [],
    this.allForwardSplitIds = const [],
  });

  int get billCount => bills.length;
}

class _FriendDebtAccumulator {
  final String memberId;
  final String name;
  final String? avatarUrl;
  final String? userId;
  final List<FriendBillItem> _bills = [];
  double _totalAmount = 0;

  double get totalAmount => _totalAmount;

  List<String> get allSplitIds => _bills.map((b) => b.splitId).toList();

  _FriendDebtAccumulator({
    required this.memberId,
    required this.name,
    required this.avatarUrl,
    required this.userId,
  });

  void addBill(FriendBillItem bill) {
    _bills.add(bill);
    _totalAmount += bill.amount;
  }

  /// Returns a new accumulator with bills reduced by [subtractAmount].
  /// Bills are removed from smallest-first until the amount is cancelled.
  _FriendDebtAccumulator subtractAmount(double subtractAmount) {
    final result = _FriendDebtAccumulator(
      memberId: memberId,
      name: name,
      avatarUrl: avatarUrl,
      userId: userId,
    );

    // Sort bills smallest first so we cancel the most bills possible
    final sorted = [..._bills]..sort((a, b) => a.amount.compareTo(b.amount));
    double remaining = subtractAmount;

    for (final bill in sorted) {
      if (remaining <= 0) {
        result.addBill(bill);
      } else if (bill.amount <= remaining + 0.005) {
        // This bill is fully covered by the netting — drop it
        remaining -= bill.amount;
      } else {
        // Partially covered — keep with reduced amount
        final reduced = FriendBillItem(
          splitId: bill.splitId,
          expenseId: bill.expenseId,
          title: bill.title,
          date: bill.date,
          amount: bill.amount - remaining,
          icon: bill.icon,
          iconBackground: bill.iconBackground,
        );
        result.addBill(reduced);
        remaining = 0;
      }
    }

    return result;
  }

  _FriendDebtSummary toSummary({
    List<String> counterSplitIds = const [],
    List<String> allForwardSplitIds = const [],
  }) {
    return _FriendDebtSummary(
      memberId: memberId,
      name: name,
      avatarUrl: avatarUrl,
      userId: userId,
      bills: List<FriendBillItem>.unmodifiable(_bills),
      totalAmount: _totalAmount,
      counterSplitIds: counterSplitIds,
      allForwardSplitIds: allForwardSplitIds,
    );
  }
}

class _GroupedSummaries {
  final List<_FriendDebtSummary> oweSummaries;
  final List<_FriendDebtSummary> collectSummaries;

  const _GroupedSummaries({
    required this.oweSummaries,
    required this.collectSummaries,
  });
}

class _BillVisual {
  final IconData icon;
  final Color background;

  const _BillVisual({required this.icon, required this.background});
}
