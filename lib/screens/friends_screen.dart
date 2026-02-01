import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nubbill/services/friend_service.dart';

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('เพื่อน', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1, color: Color(0xFF81CEF2)),
            onPressed: () => _showAddFriendModal(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF81CEF2),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF81CEF2),
          tabs: const [
            Tab(text: 'เพื่อนทั้งหมด'),
            Tab(text: 'คำขอเป็นเพื่อน'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // All Friends Tab
          _AllFriendsTab(),
          // Friend Requests Tab
          _FriendRequestsTab(),
        ],
      ),
    );
  }

  void _showAddFriendModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _AddFriendModal(),
    );
  }
}

class _AllFriendsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendsAsync = ref.watch(friendsProvider);

    return friendsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text('เกิดข้อผิดพลาด: $err'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.invalidate(friendsProvider),
              child: const Text('ลองอีกครั้ง'),
            ),
          ],
        ),
      ),
      data: (friends) {
        if (friends.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                const Text(
                  'ยังไม่มีเพื่อน',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 8),
                const Text(
                  'กดปุ่ม + เพื่อเพิ่มเพื่อน',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(friendsProvider);
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: friends.length,
            itemBuilder: (context, index) {
              final friend = friends[index];
              return _FriendCard(friend: friend);
            },
          ),
        );
      },
    );
  }
}

class _FriendCard extends StatelessWidget {
  final Friend friend;

  const _FriendCard({required this.friend});

  @override
  Widget build(BuildContext context) {
    final isOwed = friend.balance > 0; // They owe you
    final isOwe = friend.balance < 0; // You owe them

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF81CEF2).withValues(alpha: 0.2),
          backgroundImage: friend.avatarUrl != null
              ? NetworkImage(friend.avatarUrl!)
              : null,
          child: friend.avatarUrl == null
              ? Text(
                  friend.nickname.isNotEmpty
                      ? friend.nickname[0].toUpperCase()
                      : '?',
                )
              : null,
        ),
        title: Text(
          friend.nickname,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (friend.balance == 0)
              const Text('เคลียร์กันแล้ว', style: TextStyle(color: Colors.grey))
            else
              Text(
                isOwed
                    ? 'ติดคุณ ฿${friend.balance.abs().toStringAsFixed(0)}'
                    : 'คุณติด ฿${friend.balance.abs().toStringAsFixed(0)}',
                style: TextStyle(
                  color: isOwed
                      ? Colors.green
                      : (isOwe ? Colors.red : Colors.grey),
                ),
              ),
            Text(
              '${friend.sharedTripsCount} กลุ่มร่วมกัน',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: () {
          // TODO: Navigate to friend detail
        },
      ),
    );
  }
}

class _FriendRequestsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(pendingRequestsProvider);

    return requestsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('เกิดข้อผิดพลาด: $err')),
      data: (requests) {
        if (requests.incoming.isEmpty && requests.outgoing.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.mail_outline, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                const Text(
                  'ไม่มีคำขอเป็นเพื่อน',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(pendingRequestsProvider);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (requests.incoming.isNotEmpty) ...[
                Text(
                  'คำขอเข้ามา (${requests.incoming.length})',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                ...requests.incoming.map(
                  (req) => _IncomingRequestCard(request: req),
                ),
              ],
              if (requests.outgoing.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'คำขอที่ส่ง (${requests.outgoing.length})',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                ...requests.outgoing.map((req) {
                  final target = req['target'] as Map<String, dynamic>?;
                  return Card(
                    elevation: 0,
                    color: Colors.grey[50],
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.grey[300],
                        child: Text(
                          target?['nickname']?.toString().isNotEmpty == true
                              ? target!['nickname'][0].toUpperCase()
                              : '?',
                        ),
                      ),
                      title: Text(target?['nickname'] ?? 'Unknown'),
                      subtitle: const Text(
                        'รอการตอบรับ',
                        style: TextStyle(color: Colors.orange),
                      ),
                    ),
                  );
                }),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _IncomingRequestCard extends ConsumerStatefulWidget {
  final FriendRequest request;

  const _IncomingRequestCard({required this.request});

  @override
  ConsumerState<_IncomingRequestCard> createState() =>
      _IncomingRequestCardState();
}

class _IncomingRequestCardState extends ConsumerState<_IncomingRequestCard> {
  bool _isLoading = false;

  Future<void> _accept() async {
    setState(() => _isLoading = true);
    try {
      await ref
          .read(friendServiceProvider)
          .acceptRequest(widget.request.requesterId);
      ref.invalidate(pendingRequestsProvider);
      ref.invalidate(friendsProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('เพิ่มเพื่อนสำเร็จ!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _reject() async {
    setState(() => _isLoading = true);
    try {
      await ref
          .read(friendServiceProvider)
          .rejectRequest(widget.request.requesterId);
      ref.invalidate(pendingRequestsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeDiff = DateTime.now().difference(widget.request.createdAt);
    String timeText;
    if (timeDiff.inMinutes < 60) {
      timeText = '${timeDiff.inMinutes} นาทีที่แล้ว';
    } else if (timeDiff.inHours < 24) {
      timeText = '${timeDiff.inHours} ชม. ที่แล้ว';
    } else {
      timeText = '${timeDiff.inDays} วันที่แล้ว';
    }

    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFF81CEF2).withValues(alpha: 0.2),
              backgroundImage: widget.request.requesterAvatarUrl != null
                  ? NetworkImage(widget.request.requesterAvatarUrl!)
                  : null,
              child: widget.request.requesterAvatarUrl == null
                  ? Text(
                      widget.request.requesterName.isNotEmpty
                          ? widget.request.requesterName[0].toUpperCase()
                          : '?',
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.request.requesterName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    timeText,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            if (_isLoading)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else ...[
              TextButton(
                onPressed: _reject,
                style: TextButton.styleFrom(foregroundColor: Colors.grey),
                child: const Text('ลบ'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _accept,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF81CEF2),
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
                child: const Text('ยืนยัน'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AddFriendModal extends ConsumerStatefulWidget {
  @override
  ConsumerState<_AddFriendModal> createState() => _AddFriendModalState();
}

class _AddFriendModalState extends ConsumerState<_AddFriendModal> {
  final _searchController = TextEditingController();
  List<UserSearchResult> _searchResults = [];
  bool _isSearching = false;
  bool _isSending = false;

  Future<void> _search() async {
    if (_searchController.text.length < 3) return;

    setState(() => _isSearching = true);
    try {
      final results = await ref
          .read(friendServiceProvider)
          .searchUsers(_searchController.text);
      setState(() => _searchResults = results);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _sendRequest(String userId) async {
    setState(() => _isSending = true);
    try {
      await ref.read(friendServiceProvider).sendRequestById(userId);
      ref.invalidate(pendingRequestsProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('ส่งคำขอเป็นเพื่อนแล้ว!')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'เพิ่มเพื่อน',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'ค้นหาด้วยอีเมลหรือชื่อ',
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              suffixIcon: _isSearching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: _search,
                    ),
            ),
            onSubmitted: (_) => _search(),
          ),
          const SizedBox(height: 16),
          if (_searchResults.isNotEmpty)
            ...(_searchResults.map(
              (user) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(
                    0xFF81CEF2,
                  ).withValues(alpha: 0.2),
                  backgroundImage: user.avatarUrl != null
                      ? NetworkImage(user.avatarUrl!)
                      : null,
                  child: user.avatarUrl == null
                      ? Text(
                          user.nickname.isNotEmpty
                              ? user.nickname[0].toUpperCase()
                              : '?',
                        )
                      : null,
                ),
                title: Text(user.nickname),
                subtitle: Text(user.email ?? ''),
                trailing: _buildActionButton(user),
              ),
            ))
          else if (_searchController.text.isNotEmpty && !_isSearching)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'ไม่พบผู้ใช้',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {
              // TODO: Scan QR Code
            },
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('สแกน QR Code'),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(16)),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildActionButton(UserSearchResult user) {
    if (user.friendshipStatus == 'accepted') {
      return const Text(
        'เป็นเพื่อนแล้ว',
        style: TextStyle(color: Colors.green),
      );
    } else if (user.friendshipStatus == 'pending') {
      return Text(
        user.isPendingFromMe ? 'รอตอบรับ' : 'มีคำขอ',
        style: const TextStyle(color: Colors.orange),
      );
    } else {
      return ElevatedButton(
        onPressed: _isSending ? null : () => _sendRequest(user.id),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF81CEF2),
          foregroundColor: Colors.white,
        ),
        child: _isSending
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text('เพิ่ม'),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
