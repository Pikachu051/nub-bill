import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nubbill/services/auth_repository.dart';
import 'package:nubbill/services/profile_service.dart';
import 'package:nubbill/models/trip_model.dart';
import 'package:nubbill/config/supabase_config.dart';

/// Provider for user's groups directly from Supabase
final userTripsProvider = FutureProvider<List<Trip>>((ref) async {
  final userId = SupabaseConfig.currentUser?.id;
  if (userId == null) return [];

  try {
    // Get trips where user is a member
    final response = await SupabaseConfig.client
        .from('trip_members')
        .select('trip:trips(*)')
        .eq('user_id', userId);

    final trips = <Trip>[];
    for (final item in response as List) {
      if (item['trip'] != null) {
        trips.add(Trip.fromJson(item['trip'] as Map<String, dynamic>));
      }
    }
    return trips;
  } catch (e) {
    debugPrint('Failed to load trips: $e');
    rethrow; // Let AsyncValue.error handle it gracefully
  }
});

/// Provider for wallet summary (total owed to user & user owes)
final walletSummaryProvider = FutureProvider<Map<String, double>>((ref) async {
  try {
    final userId = SupabaseConfig.currentUser?.id;
    if (userId == null) return {'toReceive': 0.0, 'toPay': 0.0};

    // Get member IDs for this user
    final memberResponse = await SupabaseConfig.client
        .from('trip_members')
        .select('id')
        .eq('user_id', userId);

    final memberIds = (memberResponse as List)
        .map((m) => m['id'] as String)
        .toList();

    if (memberIds.isEmpty) return {'toReceive': 0.0, 'toPay': 0.0};

    double toPay = 0.0;
    double toReceive = 0.0;

    // Get expense splits where user owes money (unpaid)
    try {
      final owesResponse = await SupabaseConfig.client
          .from('expense_splits')
          .select('amount')
          .inFilter('member_id', memberIds)
          .eq('status', 'unpaid');

      for (final split in owesResponse as List) {
        toPay += (split['amount'] as num).toDouble();
      }
    } catch (e) {
      // Expense splits query failed, continue with 0
      debugPrint('Wallet - expense_splits query failed: $e');
    }

    // Get expenses created by user's members where others owe money
    try {
      final toReceiveResponse = await SupabaseConfig.client
          .from('expenses')
          .select('expense_splits(amount, status)')
          .inFilter('payer_id', memberIds);

      for (final expense in toReceiveResponse as List) {
        final splits = expense['expense_splits'] as List? ?? [];
        for (final split in splits) {
          if (split['status'] == 'unpaid') {
            toReceive += (split['amount'] as num).toDouble();
          }
        }
      }
    } catch (e) {
      // Expenses query failed, continue with 0
      debugPrint('Wallet - expenses query failed: $e');
    }

    return {'toReceive': toReceive, 'toPay': toPay};
  } catch (e) {
    debugPrint('Wallet provider error: $e');
    return {'toReceive': 0.0, 'toPay': 0.0};
  }
});

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authRepositoryProvider).currentUser;
    final profileAsync = ref.watch(myProfileProvider);

    // Get nickname and avatar from profile (with fallback to auth metadata)
    final nickname = profileAsync.when(
      data: (profile) =>
          profile.nickname ?? user?.userMetadata?['nickname'] ?? 'User',
      loading: () => user?.userMetadata?['nickname'] ?? 'User',
      error: (_, __) => user?.userMetadata?['nickname'] ?? 'User',
    );
    final avatarUrl = profileAsync.when(
      data: (profile) => profile.avatarUrl,
      loading: () => user?.userMetadata?['avatar_url'] as String?,
      error: (_, __) => user?.userMetadata?['avatar_url'] as String?,
    );

    final tripsAsync = ref.watch(userTripsProvider);
    final walletAsync = ref.watch(walletSummaryProvider);

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
                                      Icons.person,
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
                    top: 130,
                    child: _buildWalletCard(walletAsync),
                  ),
                ],
              ),

              // Spacing for the overlapping card (wallet card is ~160px tall, positioned at 130, blue header is 180)
              // Card extends from 130 to ~290, so we need 290 - 180 = 110 spacing
              const SizedBox(height: 130),

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
                    _buildGroupsList(context, tripsAsync),

                    // Bottom padding for FAB
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      // FAB for creating new group
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'createGroupFab',
        onPressed: () => context.push('/groups/create'),
        backgroundColor: const Color(0xFF81CEF2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
        icon: const Icon(Icons.people, color: Colors.white),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text(
              'สร้างกลุ่มใหม่',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(width: 8),
            Text(
              '|',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(width: 8),
            Icon(Icons.keyboard_arrow_up, color: Colors.white, size: 24),
          ],
        ),
      ),
    );
  }

//Wallet widget
  Widget _buildWalletCard(AsyncValue<Map<String, double>> walletAsync) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
        error: (_, __) => const Text('ไม่สามารถโหลดข้อมูลได้'),
        data: (wallet) {
          final toReceive = wallet['toReceive'] ?? 0;
          final toPay = wallet['toPay'] ?? 0;
          final balance = toReceive - toPay;

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
                              Icons.arrow_downward,
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
                              Icons.arrow_upward,
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
          onPressed: () {
            // TODO: Show filter options
          },
          icon: Icon(Icons.tune, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildGroupsList(
    BuildContext context,
    AsyncValue<List<Trip>> tripsAsync,
  ) {
    return tripsAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              const Icon(Icons.wifi_off, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text(
                'ไม่สามารถเชื่อมต่อได้',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'กรุณาตรวจสอบอินเทอร์เน็ตแล้วลองใหม่',
                style: TextStyle(color: Colors.grey[500], fontSize: 14),
              ),
            ],
          ),
        ),
      ),
      data: (trips) {
        if (trips.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  Icon(Icons.group_outlined, size: 64, color: Colors.grey[300]),
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

        return Column(
          children: trips
              .map((trip) => _buildGroupCard(context, trip))
              .toList(),
        );
      },
    );
  }

  Widget _buildGroupCard(BuildContext context, Trip trip) {
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: const Color(0xFF81CEF2).withOpacity(0.1),
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
              'ค้างจ่าย',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
            const SizedBox(height: 2),
            Text(
              '0.00฿', // TODO: Calculate from expense_splits
              style: TextStyle(
                color: Colors.red[400],
                fontWeight: FontWeight.bold,
                fontSize: 14,
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
