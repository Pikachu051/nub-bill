import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nubbill/services/trip_service.dart';
import 'package:nubbill/services/expense_service.dart';
import 'package:nubbill/services/realtime_service.dart';
import 'package:nubbill/models/trip_model.dart';
import 'package:nubbill/models/trip_member_model.dart';
import 'package:nubbill/models/balance_entry_model.dart';

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

  // Local state for animated list
  final GlobalKey<AnimatedListState> _expenseListKey =
      GlobalKey<AnimatedListState>();
  List<dynamic> _expenses = [];
  bool _isInitialLoad = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Subscribe to realtime expense updates after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialExpenses();
      _subscribeToRealtimeUpdates();
    });
  }

  Future<void> _loadInitialExpenses() async {
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
            if (event.newRecord != null) {
              _addExpenseWithAnimation(event.newRecord!);
            }
            break;
          case RealtimeEventType.update:
            if (event.newRecord != null) {
              _updateExpense(event.newRecord!);
            }
            break;
          case RealtimeEventType.delete:
            if (event.oldRecord != null) {
              _removeExpenseWithAnimation(event.oldRecord!['id']);
            }
            break;
        }
        // Silently refresh balances (no loading state, just update)
        ref.invalidate(tripBalancesProvider(widget.groupId));
      },
    );
  }

  void _addExpenseWithAnimation(Map<String, dynamic> expense) {
    // Insert at the beginning (newest first)
    _expenses.insert(0, expense);
    _expenseListKey.currentState?.insertItem(
      0,
      duration: const Duration(milliseconds: 300),
    );
  }

  void _updateExpense(Map<String, dynamic> updatedExpense) {
    final index = _expenses.indexWhere((e) => e['id'] == updatedExpense['id']);
    if (index != -1 && mounted) {
      setState(() {
        _expenses[index] = updatedExpense;
      });
    }
  }

  void _removeExpenseWithAnimation(String expenseId) {
    final index = _expenses.indexWhere((e) => e['id'] == expenseId);
    if (index != -1) {
      final removedExpense = _expenses[index];
      _expenses.removeAt(index);
      _expenseListKey.currentState?.removeItem(
        index,
        (context, animation) =>
            _buildAnimatedExpenseCard(removedExpense, animation),
        duration: const Duration(milliseconds: 300),
      );
    }
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
    final balancesAsync = ref.watch(tripBalancesProvider(widget.groupId));
    // Note: expensesAsync removed - expenses are managed locally for animations

    return tripDetailAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, _) => Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(child: Text('เกิดข้อผิดพลาด: $err')),
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

        return Scaffold(
          backgroundColor: Colors.grey[50],
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                _buildSliverAppBar(trip),
                SliverToBoxAdapter(child: _buildHeaderContent(trip, members)),
                SliverPersistentHeader(
                  delegate: _SliverAppBarDelegate(
                    TabBar(
                      controller: _tabController,
                      labelColor: const Color(0xFF81CEF2),
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: const Color(0xFF81CEF2),
                      tabs: const [
                        Tab(text: 'ยอดรวม'),
                        Tab(text: 'ใครติดใคร'),
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
                // Tab 1: Expenses Summary (uses local state with animations)
                _buildExpensesTab(),
                // Tab 2: Who Owes Who
                _buildBalancesTab(balancesAsync),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              // Navigate to add expense with trip context
              context.push(
                '/add_expense',
                extra: {
                  'tripId': widget.groupId,
                  'tripName': trip.name,
                  'members': members,
                },
              );
            },
            backgroundColor: const Color(0xFF81CEF2),
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text(
              'เพิ่มบิล',
              style: TextStyle(color: Colors.white),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSliverAppBar(Trip trip) {
    return SliverAppBar(
      expandedHeight: 200.0,
      pinned: true,
      backgroundColor: const Color(0xFF81CEF2),
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          trip.name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
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
                    Colors.black.withValues(alpha: 0.5),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.share, color: Colors.white),
          onPressed: () {
            // Share join code
            _showJoinCodeDialog(trip.joinCode);
          },
        ),
        IconButton(
          icon: const Icon(Icons.settings, color: Colors.white),
          onPressed: () {
            // Trip settings
          },
        ),
      ],
    );
  }

  Widget _buildHeaderContent(Trip trip, List<TripMember> members) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Members Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ...members.take(5).map((m) => _buildMemberAvatar(m)),
                if (members.length > 5)
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.grey[300],
                    child: Text(
                      '+${members.length - 5}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    // Add member
                  },
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.grey[200],
                    child: const Icon(Icons.add, size: 20, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ยอดของคุณ',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      trip.balance >= 0
                          ? '+฿${trip.balance.abs().toStringAsFixed(0)}'
                          : '-฿${trip.balance.abs().toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: trip.balance >= 0 ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
                Text(
                  trip.balance >= 0 ? 'รับคืน' : 'ต้องจ่าย',
                  style: TextStyle(
                    color: trip.balance >= 0 ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberAvatar(TripMember member) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: Column(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFF81CEF2).withValues(alpha: 0.2),
            backgroundImage: member.avatarUrl != null
                ? NetworkImage(member.avatarUrl!)
                : null,
            child: member.avatarUrl == null
                ? Text(
                    member.displayName.isNotEmpty
                        ? member.displayName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  )
                : null,
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 50,
            child: Text(
              member.displayName,
              style: const TextStyle(fontSize: 10),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpensesTab() {
    // Show loading only on initial load
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

    return AnimatedList(
      key: _expenseListKey,
      padding: const EdgeInsets.all(16),
      initialItemCount: _expenses.length,
      itemBuilder: (context, index, animation) {
        if (index >= _expenses.length) return const SizedBox.shrink();
        final expense = _expenses[index];
        return _buildAnimatedExpenseCard(expense, animation);
      },
    );
  }

  Widget _buildAnimatedExpenseCard(
    dynamic expense,
    Animation<double> animation,
  ) {
    return SlideTransition(
      position: animation.drive(
        Tween<Offset>(
          begin: const Offset(1, 0), // Slide from right
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
      ),
      child: FadeTransition(
        opacity: animation,
        child: _buildExpenseCard(expense),
      ),
    );
  }

  Widget _buildExpenseCard(dynamic expense) {
    // Parse expense data
    final description = expense['description'] ?? 'ไม่มีรายละเอียด';
    final amount = (expense['amount'] as num?)?.toDouble() ?? 0;
    final date =
        DateTime.tryParse(expense['expense_date'] ?? '') ?? DateTime.now();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF81CEF2).withValues(alpha: 0.1),
          child: const Icon(Icons.receipt, color: Color(0xFF81CEF2)),
        ),
        title: Text(
          description,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${date.day}/${date.month}/${date.year}'),
        trailing: Text(
          '฿${amount.toStringAsFixed(0)}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        onTap: () {
          context.push('/bill_details', extra: expense);
        },
      ),
    );
  }

  Widget _buildBalancesTab(AsyncValue<List<BalanceEntry>> balancesAsync) {
    return balancesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('เกิดข้อผิดพลาด: $err')),
      data: (balances) {
        if (balances.isEmpty) {
          return const Center(
            child: Text(
              'ไม่มียอดค้างชำระ',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: balances.length,
          itemBuilder: (context, index) {
            final entry = balances[index];
            return _buildBalanceCard(entry);
          },
        );
      },
    );
  }

  Widget _buildBalanceCard(BalanceEntry entry) {
    final isPositive = entry.net > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFF81CEF2).withValues(alpha: 0.2),
              backgroundImage: entry.avatarUrl != null
                  ? NetworkImage(entry.avatarUrl!)
                  : null,
              child: entry.avatarUrl == null
                  ? Text(
                      entry.displayName.isNotEmpty
                          ? entry.displayName[0].toUpperCase()
                          : '?',
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.displayName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    isPositive ? 'ติดคุณ' : 'คุณติด',
                    style: TextStyle(
                      color: isPositive ? Colors.green : Colors.red,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '฿${entry.net.abs().toStringAsFixed(0)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: isPositive ? Colors.green : Colors.red,
                  ),
                ),
                if (entry.net != 0)
                  TextButton(
                    onPressed: () {
                      // Navigate to payment
                      context.push(
                        '/payment',
                        extra: {
                          'amount': entry.net.abs(),
                          'memberId': entry.memberId,
                        },
                      );
                    },
                    child: Text(
                      isPositive ? 'เตือนเพื่อน' : 'จ่ายเงิน',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showJoinCodeDialog(String joinCode) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('รหัสเข้าร่วมกลุ่ม'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                joinCode,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('แชร์รหัสนี้ให้เพื่อนเพื่อเข้าร่วมกลุ่ม'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ปิด'),
          ),
        ],
      ),
    );
  }
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
    return Container(color: Colors.white, child: _tabBar);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
