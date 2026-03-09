import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nubbill/models/expense_category.dart';
import 'package:nubbill/models/expense_model.dart';
import 'package:nubbill/services/expense_service.dart';
import 'package:nubbill/services/trip_service.dart';
import 'package:nubbill/shared/app_icons.dart';
import 'package:nubbill/widgets/retry_error_state.dart';

const String _kFont = 'LINESeedSansTH';

class GroupOverviewPage extends ConsumerWidget {
  final String groupId;

  const GroupOverviewPage({super.key, required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripDetailAsync = ref.watch(tripDetailProvider(groupId));
    final expensesAsync = ref.watch(tripExpensesProvider(groupId));

    return tripDetailAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        backgroundColor: const Color(0xFFF4F4F4),
        appBar: _buildAppBar(context),
        body: RetryErrorState(
          error: error,
          onRetry: () => ref.invalidate(tripDetailProvider(groupId)),
        ),
      ),
      data: (tripDetail) {
        if (tripDetail == null) {
          return Scaffold(
            backgroundColor: const Color(0xFFF4F4F4),
            appBar: _buildAppBar(context),
            body: const Center(child: Text('ไม่พบข้อมูลกลุ่ม')),
          );
        }

        return expensesAsync.when(
          loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (error, _) => Scaffold(
            backgroundColor: const Color(0xFFF4F4F4),
            appBar: _buildAppBar(context),
            body: RetryErrorState(
              error: error,
              onRetry: () => ref.invalidate(tripExpensesProvider(groupId)),
            ),
          ),
          data: (expenses) {
            final summary = _TripOverviewSummary.from(
              expenses: expenses,
              myMemberId: tripDetail.myMemberId,
            );

            return Scaffold(
              backgroundColor: const Color(0xFFF4F4F4),
              appBar: _buildAppBar(context),
              body: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _MySpendSection(summary: summary),
                      const SizedBox(height: 36),
                      _CategorySection(
                        summary: summary,
                        onCategoryTap: (category) {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => GroupCategoryOverviewPage(
                                groupId: groupId,
                                category: category,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
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
        onPressed: () => context.pop(),
        icon: const Icon(AppIcons.chevronLeft, color: Color(0xFF5E5E5E), size: 26),
      ),
      title: const Text(
        'ภาพรวม',
        style: TextStyle(
          fontFamily: _kFont,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Color(0xB2141416),
        ),
      ),
    );
  }
}

class GroupCategoryOverviewPage extends ConsumerWidget {
  final String groupId;
  final ExpenseCategory category;

  const GroupCategoryOverviewPage({
    super.key,
    required this.groupId,
    required this.category,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripDetailAsync = ref.watch(tripDetailProvider(groupId));
    final expensesAsync = ref.watch(tripExpensesProvider(groupId));

    return tripDetailAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        backgroundColor: const Color(0xFFF4F4F4),
        appBar: _buildAppBar(context),
        body: RetryErrorState(
          error: error,
          onRetry: () => ref.invalidate(tripDetailProvider(groupId)),
        ),
      ),
      data: (tripDetail) {
        return expensesAsync.when(
          loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (error, _) => Scaffold(
            backgroundColor: const Color(0xFFF4F4F4),
            appBar: _buildAppBar(context),
            body: RetryErrorState(
              error: error,
              onRetry: () => ref.invalidate(tripExpensesProvider(groupId)),
            ),
          ),
          data: (expenses) {
            final summary = _TripOverviewSummary.from(
              expenses: expenses,
              myMemberId: tripDetail?.myMemberId,
            );
            final categorySummary = summary.byCategory[category];
            final categoryExpenses = (categorySummary?.expenses ?? <Expense>[])
              ..sort((a, b) => _expenseSortDate(b).compareTo(_expenseSortDate(a)));

            return Scaffold(
              backgroundColor: const Color(0xFFF4F4F4),
              appBar: _buildAppBar(context),
              body: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: Column(
                    children: [
                      _CategoryHeadlineCard(
                        categorySummary: categorySummary,
                        totalTripAmount: summary.totalTripAmount,
                      ),
                      const SizedBox(height: 24),
                      Expanded(
                        child: categoryExpenses.isEmpty
                            ? const _EmptyCategoryExpenses()
                            : _CategoryExpenseList(expenses: categoryExpenses),
                      ),
                    ],
                  ),
                ),
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
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(AppIcons.chevronLeft, color: Color(0xFF5E5E5E), size: 26),
      ),
      title: const Text(
        'จัดการยอดเงิน',
        style: TextStyle(
          fontFamily: _kFont,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Color(0xB2141416),
        ),
      ),
    );
  }
}

class _MySpendSection extends StatelessWidget {
  final _TripOverviewSummary summary;

  const _MySpendSection({required this.summary});

  @override
  Widget build(BuildContext context) {
    final percent = summary.totalTripAmount <= 0
        ? 0.0
        : (summary.myPaidAmount / summary.totalTripAmount).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ทริปนี้เราจ่ายไปเท่าไหร่?',
          style: TextStyle(
            fontFamily: _kFont,
            color: Color(0xB2141416),
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: SizedBox(
            width: 239,
            height: 239,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(239, 239),
                  painter: _SingleRingPainter(
                    percent: percent,
                    baseColor: const Color(0x33141416),
                    fillColor: const Color(0xFF81CEF2),
                    strokeWidth: 26,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${summary.myPaidAmount.toStringAsFixed(2)}฿',
                      style: const TextStyle(
                        fontFamily: _kFont,
                        color: Color(0xFF81CEF2),
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'คิดเป็น ${(percent * 100).toStringAsFixed(0)}% ของยอดรวม',
                      style: const TextStyle(
                        fontFamily: _kFont,
                        color: Color(0xB2141416),
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          decoration: ShapeDecoration(
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            shadows: const [
              BoxShadow(
                color: Color(0x1E333333),
                blurRadius: 12,
                offset: Offset(4, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: _LegendAmount(
                  dotColor: const Color(0xFF81CEF2),
                  label: 'ส่วนของฉัน',
                  amount: summary.myPaidAmount,
                  amountColor: const Color(0xFF81CEF2),
                ),
              ),
              Container(width: 1, height: 20, color: const Color(0x7F141416)),
              Expanded(
                child: _LegendAmount(
                  dotColor: const Color(0xFFD9D9D9),
                  label: 'ยอดรวมกลุ่ม',
                  amount: summary.totalTripAmount,
                  amountColor: const Color(0xB2141416),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CategorySection extends StatelessWidget {
  final _TripOverviewSummary summary;
  final ValueChanged<ExpenseCategory> onCategoryTap;

  const _CategorySection({required this.summary, required this.onCategoryTap});

  @override
  Widget build(BuildContext context) {
    final categorySummaries = summary.sortedCategories;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'หมดไปกับค่าอะไรบ้าง?',
          style: TextStyle(
            fontFamily: _kFont,
            color: Color(0xB2141416),
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: SizedBox(
            width: 239,
            height: 239,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(239, 239),
                  painter: _DonutPainter(
                    segments: categorySummaries
                        .map(
                          (summaryItem) => _DonutSegment(
                            color: summaryItem.category.color,
                            ratio: summary.totalTripAmount <= 0
                                ? 0
                                : (summaryItem.totalAmount / summary.totalTripAmount),
                          ),
                        )
                        .toList(),
                    strokeWidth: 36,
                    baseColor: const Color(0xFFEDEDED),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'ยอดรวม',
                      style: TextStyle(
                        fontFamily: _kFont,
                        color: Color(0xB2141416),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${summary.totalTripAmount.toStringAsFixed(2)}฿',
                      style: const TextStyle(
                        fontFamily: _kFont,
                        color: Color(0xFF81CEF2),
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: const [
            Icon(AppIcons.category, size: 20, color: Color(0xB2141416)),
            SizedBox(width: 4),
            Text(
              'หมวดหมู่',
              style: TextStyle(
                fontFamily: _kFont,
                color: Color(0xB2141416),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (categorySummaries.isEmpty)
          const _EmptyCategoryCard()
        else
          ...categorySummaries.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _CategoryRowCard(
                summary: item,
                totalTripAmount: summary.totalTripAmount,
                onTap: () => onCategoryTap(item.category),
              ),
            ),
          ),
      ],
    );
  }
}

class _CategoryHeadlineCard extends StatelessWidget {
  final _CategorySummary? categorySummary;
  final double totalTripAmount;

  const _CategoryHeadlineCard({
    required this.categorySummary,
    required this.totalTripAmount,
  });

  @override
  Widget build(BuildContext context) {
    final summary = categorySummary;
    if (summary == null) {
      return const SizedBox.shrink();
    }

    final ratio = totalTripAmount <= 0 ? 0.0 : summary.totalAmount / totalTripAmount;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        shadows: const [
          BoxShadow(
            color: Color(0x1E333333),
            blurRadius: 12,
            offset: Offset(4, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 43,
                  height: 43,
                  decoration: ShapeDecoration(
                    color: summary.category.color,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(summary.category.icon, color: const Color(0xFF141416), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        summary.category.label,
                        style: const TextStyle(
                          fontFamily: _kFont,
                          color: Color(0xB2141416),
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: ShapeDecoration(
                          color: const Color(0x3381CEF2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: Text(
                          '${summary.expenses.length} รายการ',
                          style: const TextStyle(
                            fontFamily: _kFont,
                            color: Color(0xFF81CEF2),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${summary.totalAmount.toStringAsFixed(2)}฿',
                style: const TextStyle(
                  fontFamily: _kFont,
                  color: Color(0xFFFC5154),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${(ratio * 100).toStringAsFixed(0)}% ของยอดรวม',
                style: const TextStyle(
                  fontFamily: _kFont,
                  color: Color(0x7F141416),
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryExpenseList extends StatelessWidget {
  final List<Expense> expenses;

  const _CategoryExpenseList({required this.expenses});

  @override
  Widget build(BuildContext context) {
    final grouped = <DateTime, List<Expense>>{};
    for (final expense in expenses) {
      final date = _expenseSortDate(expense);
      final key = DateTime(date.year, date.month, date.day);
      grouped.putIfAbsent(key, () => <Expense>[]).add(expense);
    }

    final dates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: dates.length,
      itemBuilder: (context, index) {
        final date = dates[index];
        final dateExpenses = grouped[date]!..sort((a, b) => _expenseSortDate(b).compareTo(_expenseSortDate(a)));

        return Padding(
          padding: EdgeInsets.only(bottom: index == dates.length - 1 ? 0 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  _formatThaiDate(date),
                  style: const TextStyle(
                    fontFamily: _kFont,
                    color: Color(0xB2141416),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ...dateExpenses.map(
                (expense) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ExpenseRowCard(expense: expense),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ExpenseRowCard extends StatelessWidget {
  final Expense expense;

  const _ExpenseRowCard({required this.expense});

  @override
  Widget build(BuildContext context) {
    final payerName = expense.payer?.displayName ?? 'ไม่ระบุคนจ่าย';
    final avatarUrl = expense.payer?.avatarUrl;
    final firstChar = payerName.isNotEmpty ? payerName.characters.first.toUpperCase() : '?';

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => context.push('/expenses/${expense.id}'),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFFE6EEF4),
              backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                  ? NetworkImage(avatarUrl)
                  : null,
              child: avatarUrl == null || avatarUrl.isEmpty
                  ? Text(
                      firstChar,
                      style: const TextStyle(
                        fontFamily: _kFont,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF5E5E5E),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expense.description.isEmpty ? 'ไม่มีชื่อรายการ' : expense.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: _kFont,
                      color: Color(0xB2141416),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$payerNameจ่าย',
                    style: const TextStyle(
                      fontFamily: _kFont,
                      color: Color(0x7F141416),
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${expense.amount.toStringAsFixed(2)}฿',
              style: const TextStyle(
                fontFamily: _kFont,
                color: Color(0xFFFC5154),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryRowCard extends StatelessWidget {
  final _CategorySummary summary;
  final double totalTripAmount;
  final VoidCallback onTap;

  const _CategoryRowCard({
    required this.summary,
    required this.totalTripAmount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final percent = totalTripAmount <= 0 ? 0.0 : summary.totalAmount / totalTripAmount;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: ShapeDecoration(
                  color: summary.category.color,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                alignment: Alignment.center,
                child: Icon(summary.category.icon, color: const Color(0xFF141416), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          summary.category.label,
                          style: const TextStyle(
                            fontFamily: _kFont,
                            color: Color(0xB2141416),
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: ShapeDecoration(
                            color: const Color(0x3381CEF2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          ),
                          child: Text(
                            '${summary.expenses.length} รายการ',
                            style: const TextStyle(
                              fontFamily: _kFont,
                              color: Color(0xFF81CEF2),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(percent * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontFamily: _kFont,
                        color: Color(0x7F141416),
                        fontSize: 10,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${summary.totalAmount.toStringAsFixed(2)}฿',
                style: const TextStyle(
                  fontFamily: _kFont,
                  color: Color(0xB2141416),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(AppIcons.chevronRight, size: 20, color: Color(0x7F141416)),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegendAmount extends StatelessWidget {
  final Color dotColor;
  final String label;
  final double amount;
  final Color amountColor;

  const _LegendAmount({
    required this.dotColor,
    required this.label,
    required this.amount,
    required this.amountColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: ShapeDecoration(color: dotColor, shape: const OvalBorder()),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontFamily: _kFont,
                color: Color(0x7F141416),
                fontSize: 10,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${amount.toStringAsFixed(2)}฿',
          style: TextStyle(
            fontFamily: _kFont,
            color: amountColor,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _EmptyCategoryCard extends StatelessWidget {
  const _EmptyCategoryCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'ยังไม่มีค่าใช้จ่ายในทริปนี้',
        style: TextStyle(
          fontFamily: _kFont,
          color: Color(0x7F141416),
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}

class _EmptyCategoryExpenses extends StatelessWidget {
  const _EmptyCategoryExpenses();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(AppIcons.receipt, size: 54, color: Color(0xFFC7C7C7)),
          SizedBox(height: 12),
          Text(
            'ยังไม่มีรายการในหมวดนี้',
            style: TextStyle(
              fontFamily: _kFont,
              color: Color(0x7F141416),
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _SingleRingPainter extends CustomPainter {
  final double percent;
  final Color baseColor;
  final Color fillColor;
  final double strokeWidth;

  const _SingleRingPainter({
    required this.percent,
    required this.baseColor,
    required this.fillColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) / 2) - strokeWidth / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final basePaint = Paint()
      ..color = baseColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, basePaint);
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * percent, false, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _SingleRingPainter oldDelegate) {
    return oldDelegate.percent != percent ||
        oldDelegate.baseColor != baseColor ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

class _DonutPainter extends CustomPainter {
  final List<_DonutSegment> segments;
  final double strokeWidth;
  final Color baseColor;

  const _DonutPainter({
    required this.segments,
    required this.strokeWidth,
    required this.baseColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) / 2) - strokeWidth / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final basePaint = Paint()
      ..color = baseColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, basePaint);

    var start = -math.pi / 2;
    for (final segment in segments) {
      if (segment.ratio <= 0) continue;
      final sweep = (math.pi * 2) * segment.ratio;
      final paint = Paint()
        ..color = segment.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.baseColor != baseColor ||
        oldDelegate.segments != segments;
  }
}

class _DonutSegment {
  final Color color;
  final double ratio;

  const _DonutSegment({required this.color, required this.ratio});
}

class _TripOverviewSummary {
  final double totalTripAmount;
  final double myPaidAmount;
  final Map<ExpenseCategory, _CategorySummary> byCategory;

  const _TripOverviewSummary({
    required this.totalTripAmount,
    required this.myPaidAmount,
    required this.byCategory,
  });

  List<_CategorySummary> get sortedCategories {
    final list = byCategory.values.toList();
    list.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
    return list;
  }

  factory _TripOverviewSummary.from({
    required List<Expense> expenses,
    required String? myMemberId,
  }) {
    final totalTripAmount = expenses.fold<double>(
      0,
      (sum, expense) => sum + expense.amount,
    );

    var myPaidAmount = 0.0;
    if (myMemberId != null && myMemberId.isNotEmpty) {
      for (final expense in expenses) {
        if (expense.payers.isNotEmpty) {
          final mineInSplitPayers = expense.payers
              .where((payer) => payer.memberId == myMemberId)
              .fold<double>(0, (sum, payer) => sum + payer.amount);
          myPaidAmount += mineInSplitPayers;
          continue;
        }
        if (expense.payerId == myMemberId) {
          myPaidAmount += expense.amount;
        }
      }
    }

    final byCategory = <ExpenseCategory, _CategorySummary>{};
    for (final expense in expenses) {
      final existing = byCategory[expense.category];
      if (existing == null) {
        byCategory[expense.category] = _CategorySummary(
          category: expense.category,
          totalAmount: expense.amount,
          expenses: [expense],
        );
      } else {
        byCategory[expense.category] = existing.copyWith(
          totalAmount: existing.totalAmount + expense.amount,
          expenses: [...existing.expenses, expense],
        );
      }
    }

    return _TripOverviewSummary(
      totalTripAmount: totalTripAmount,
      myPaidAmount: myPaidAmount,
      byCategory: byCategory,
    );
  }
}

class _CategorySummary {
  final ExpenseCategory category;
  final double totalAmount;
  final List<Expense> expenses;

  const _CategorySummary({
    required this.category,
    required this.totalAmount,
    required this.expenses,
  });

  _CategorySummary copyWith({double? totalAmount, List<Expense>? expenses}) {
    return _CategorySummary(
      category: category,
      totalAmount: totalAmount ?? this.totalAmount,
      expenses: expenses ?? this.expenses,
    );
  }
}

DateTime _expenseSortDate(Expense expense) {
  final expenseDate = DateTime.tryParse(expense.expenseDate);
  if (expenseDate == null) {
    return DateTime.tryParse(expense.createdAt) ??
        DateTime.tryParse(expense.updatedAt) ??
        DateTime.now();
  }

  final hasExplicitTime =
      expenseDate.hour != 0 ||
      expenseDate.minute != 0 ||
      expenseDate.second != 0 ||
      expenseDate.millisecond != 0 ||
      expenseDate.microsecond != 0;

  if (hasExplicitTime) return expenseDate;

  final createdAt = DateTime.tryParse(expense.createdAt);
  if (createdAt != null) {
    return DateTime(
      expenseDate.year,
      expenseDate.month,
      expenseDate.day,
      createdAt.hour,
      createdAt.minute,
      createdAt.second,
      createdAt.millisecond,
      createdAt.microsecond,
    );
  }

  return expenseDate;
}

String _formatThaiDate(DateTime date) {
  const months = [
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

  return '${date.day} ${months[date.month]} ${date.year + 543}';
}