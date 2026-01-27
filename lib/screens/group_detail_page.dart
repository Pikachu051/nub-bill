import 'package:flutter/material.dart';
import 'package:nubbill/screens/bill_details_page.dart';
import 'package:nubbill/models/bill.dart';
import 'package:nubbill/models/debt.dart';

class GroupDetailPage extends StatefulWidget {
  final String groupId;
  final String groupName;
  final String? groupImageUrl;

  const GroupDetailPage({
    super.key,
    required this.groupId,
    required this.groupName,
    this.groupImageUrl,
  });

  @override
  State<GroupDetailPage> createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends State<GroupDetailPage>
    with SingleTickerProviderStateMixin {
  static const Color primaryColor = Color.fromARGB(255, 129, 206, 242);
  static const Color pinkAccent = Color(0xFFFFB5B5);

  late TabController _tabController;

  // Mock data
  final List<Bill> _bills = [
    Bill(
      id: '1',
      title: 'แม็กโดนัล',
      category: 'อาหาร',
      categoryIcon: Icons.restaurant,
      totalAmount: 450.00,
      yourAmount: 200.00,
      statusLabel: 'คุณค้างจ่าย',
      date: DateTime(2569, 1, 3),
    ),
    Bill(
      id: '2',
      title: 'เคลียร์บิล',
      category: 'อื่นๆ',
      categoryIcon: Icons.swap_horiz,
      totalAmount: 120.00,
      yourAmount: 120.00,
      status: 'cleared',
      statusLabel: 'เพิ่มจ่ายกัน คุณ แล้ว',
      date: DateTime(2569, 1, 3),
    ),
    Bill(
      id: '3',
      title: 'ที่พัก',
      category: 'ที่พัก',
      categoryIcon: Icons.bed,
      totalAmount: 450.00,
      yourAmount: 200.00,
      statusLabel: 'คุณค้างจ่ายแล้ว',
      date: DateTime(2569, 1, 3),
    ),
    Bill(
      id: '4',
      title: 'ค่าน้ำมัน',
      category: 'เดินทาง',
      categoryIcon: Icons.local_gas_station,
      totalAmount: 1100.00,
      yourAmount: 0,
      statusLabel: 'คุณไม่มีส่วนเกี่ยวข้อง',
      date: DateTime(2569, 1, 3),
    ),
    Bill(
      id: '5',
      title: 'ค่าน้ำมัน',
      category: 'เดินทาง',
      categoryIcon: Icons.local_gas_station,
      totalAmount: 140.00,
      yourAmount: 0,
      statusLabel: 'คุณไม่มีส่วนเกี่ยวข้อง',
      date: DateTime(2569, 1, 3),
    ),
    Bill(
      id: '6',
      title: 'ค่าน้ำมัน',
      category: 'เดินทาง',
      categoryIcon: Icons.local_gas_station,
      totalAmount: 140.00,
      yourAmount: 0,
      statusLabel: 'คุณไม่มีส่วนเกี่ยวข้อง',
      date: DateTime(2569, 1, 2),
    ),
    Bill(
      id: '7',
      title: 'ค่าน้ำมัน',
      category: 'เดินทาง',
      categoryIcon: Icons.local_gas_station,
      totalAmount: 140.00,
      yourAmount: 0,
      statusLabel: 'คุณไม่มีส่วนเกี่ยวข้อง',
      date: DateTime(2569, 1, 2),
    ),
    Bill(
      id: '8',
      title: 'ค่าน้ำมัน',
      category: 'เดินทาง',
      categoryIcon: Icons.local_gas_station,
      totalAmount: 140.00,
      yourAmount: 0,
      statusLabel: 'คุณไม่มีส่วนเกี่ยวข้อง',
      date: DateTime(2569, 1, 1),
    ),
    Bill(
      id: '9',
      title: 'ค่าน้ำมัน',
      category: 'เดินทาง',
      categoryIcon: Icons.local_gas_station,
      totalAmount: 140.00,
      yourAmount: 0,
      statusLabel: 'คุณไม่มีส่วนเกี่ยวข้อง',
      date: DateTime(2569, 1, 1),
    ),
    Bill(
      id: '10',
      title: 'ค่าน้ำมัน',
      category: 'เดินทาง',
      categoryIcon: Icons.local_gas_station,
      totalAmount: 140.00,
      yourAmount: 0,
      statusLabel: 'คุณไม่มีส่วนเกี่ยวข้อง',
      date: DateTime(2569, 1, 1),
    ),
  ];

  final List<Debt> _yourDebts = [
    Debt(
      id: '1',
      personName: 'เบ๋เบา',
      amount: 500.00,
      isOwedToYou: false,
      statusLabel: 'คุณค้างจ่าย',
    ),
    Debt(
      id: '2',
      personName: 'กระต่าย',
      amount: 50.00,
      isOwedToYou: false,
      statusLabel: 'คุณค้างจ่าย',
    ),
  ];

  final List<Debt> _friendDebts = [
    Debt(
      id: '3',
      personName: 'บุ๋',
      amount: 620.00,
      isOwedToYou: true,
      statusLabel: 'คุณรอรับเงิน',
    ),
    Debt(
      id: '4',
      personName: 'ออมสิน',
      amount: 320.00,
      isOwedToYou: true,
      statusLabel: 'คุณรอรับเงิน',
    ),
  ];

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

  void _onBillTapped(Bill bill) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BillDetailsPage(
          billId: bill.id,
          billTitle: bill.title,
          totalAmount: bill.totalAmount,
          categoryIcon: bill.categoryIcon,
          date: bill.date,
        ),
      ),
    );
  }

  void _onNotifyDebtor(Debt debt) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('ส่งการแจ้งเตือนไปยัง ${debt.personName} แล้ว')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return <Widget>[
            // Sliver App Bar with Image
            SliverAppBar(
              expandedHeight: 250.0,
              pinned: true,
              backgroundColor: Colors.transparent,
              centerTitle: true,
              leading: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              actions: const [
                Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: Icon(Icons.more_horiz, color: Colors.white),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image(
                      image: widget.groupImageUrl != null
                          ? NetworkImage(widget.groupImageUrl!)
                          : const AssetImage('assets/images/default_trip.jpg')
                                as ImageProvider,
                      fit: BoxFit.cover,
                    ),
                    // Gradient overlay to make text readable
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withValues(alpha: 0.6),
                            Colors.transparent,
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                    // Group Info Overlay
                    Positioned(
                      bottom: 40, // Adjust based on where white sheet starts
                      left: 0,
                      right: 0,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                widget.groupName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.people,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      '2 คน',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.settings,
                                color: Colors.white,
                                size: 20,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: primaryColor,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.airplanemode_active,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'ออกทริป',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      '02/01/69 - 04/01/69',
                                      style: TextStyle(
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
            ),
            // White Sheet Starts Here (Scrolling Part)
            SliverToBoxAdapter(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 8), // Padding top inside white sheet
                    _buildBalanceCard(),
                  ],
                ),
              ),
            ),
            // Sticky Tab Bar
            SliverPersistentHeader(
              delegate: _StickyTabBarDelegate(
                TabBar(
                  controller: _tabController,
                  labelColor: primaryColor,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: primaryColor,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
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
        body: Container(
          color: Colors.white,
          child: TabBarView(
            controller: _tabController,
            children: [_buildBillsTab(), _buildDebtsTab()],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // TODO: Navigate to add bill page
        },
        backgroundColor: primaryColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'เพิ่มบิล',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'สถานะกระเป๋าตังค์',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('ค้างจ่าย', style: TextStyle(fontSize: 16)),
              const Text(
                '- 550.00฿',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: pinkAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('จัดการยอดเงิน'),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.bar_chart, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBillsTab() {
    // Group bills by date
    final groupedBills = <String, List<Bill>>{};
    for (var bill in _bills) {
      final dateKey = '${bill.date.day} มกราคม ${bill.date.year}';
      groupedBills[dateKey] ??= [];
      groupedBills[dateKey]!.add(bill);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: groupedBills.length,
      itemBuilder: (context, index) {
        final dateKey = groupedBills.keys.elementAt(index);
        final bills = groupedBills[dateKey]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  dateKey,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                ),
                const Icon(Icons.tune, color: Colors.grey, size: 20),
              ],
            ),
            const SizedBox(height: 12),
            ...bills.map((bill) => _buildBillItem(bill)),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _buildBillItem(Bill bill) {
    final isCleared = bill.status == 'cleared';
    final isNotInvolved = bill.yourAmount == 0;

    return GestureDetector(
      onTap: () => _onBillTapped(bill),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: Row(
          children: [
            // Category icon with colored background
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isCleared
                    ? Colors.grey[200]
                    : primaryColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                bill.categoryIcon,
                color: isCleared ? Colors.grey : primaryColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),

            // Bill info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bill.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isCleared ? Colors.grey : Colors.black,
                    ),
                  ),
                  Text(
                    'หมวดหมู่จ่าย ${bill.totalAmount.toStringAsFixed(0)}฿',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),

            // Amount and status
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (bill.statusLabel != null)
                  Text(
                    bill.statusLabel!,
                    style: TextStyle(
                      fontSize: 11,
                      color: isCleared || isNotInvolved
                          ? Colors.grey
                          : pinkAccent,
                    ),
                  ),
                if (!isNotInvolved)
                  Text(
                    '${bill.yourAmount.toStringAsFixed(2)}฿',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isCleared ? Colors.grey : pinkAccent,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDebtsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Your debts section
        if (_yourDebts.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'รายการของฉัน',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const Icon(Icons.tune, color: Colors.grey, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          ..._yourDebts.map((debt) => _buildDebtItem(debt)),
          const SizedBox(height: 24),
        ],

        // Friends owe you section
        if (_friendDebts.isNotEmpty) ...[
          const Text(
            'เพื่อนคนอื่น',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          ..._friendDebts.map((debt) => _buildDebtItem(debt)),
        ],
      ],
    );
  }

  Widget _buildDebtItem(Debt debt) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 24,
            backgroundColor: primaryColor.withValues(alpha: 0.2),
            child: Text(
              debt.personName[0],
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Person info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  debt.personName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      debt.isOwedToYou ? 'คุณรอรับเงิน ' : 'คุณค้างจ่าย ',
                      style: TextStyle(
                        fontSize: 12,
                        color: debt.isOwedToYou ? Colors.green : pinkAccent,
                      ),
                    ),
                    Text(
                      '${debt.amount.toStringAsFixed(2)}฿',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: debt.isOwedToYou ? Colors.green : pinkAccent,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Notify button (only for debts owed to you)
          if (debt.isOwedToYou)
            GestureDetector(
              onTap: () => _onNotifyDebtor(debt),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: pinkAccent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_outlined,
                  color: pinkAccent,
                  size: 20,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.group, 'กลุ่ม', true),
              _buildNavItem(Icons.people, 'เพื่อน', false),
              _buildNavItem(Icons.notifications_outlined, 'แจ้งเตือน', false),
              _buildNavItem(Icons.person_outline, 'โปรไฟล์', false),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isActive) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: isActive ? primaryColor : Colors.grey, size: 24),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isActive ? primaryColor : Colors.grey,
          ),
        ),
      ],
    );
  }
}

class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _StickyTabBarDelegate(this._tabBar);

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
  bool shouldRebuild(_StickyTabBarDelegate oldDelegate) {
    return false;
  }
}
