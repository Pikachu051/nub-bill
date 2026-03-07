import 'package:flutter/material.dart';
import 'package:nubbill/shared/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nubbill/services/friend_service.dart';
import 'package:nubbill/widgets/add_friend_modal.dart';
import 'package:nubbill/widgets/retry_error_state.dart';

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _requestsExpanded = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<int>>(friendshipsRealtimeProvider, (previous, next) {
      final prevTick = previous?.valueOrNull;
      final nextTick = next.valueOrNull;
      if (nextTick != null && nextTick != prevTick) {
        ref.invalidate(friendsProvider);
        ref.invalidate(pendingRequestsProvider);
      }
    });

    final friendsAsync = ref.watch(friendsProvider);
    final requestsAsync = ref.watch(pendingRequestsProvider);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'รายชื่อเพื่อน',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(friendsProvider);
          ref.invalidate(pendingRequestsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              // Search bar + Add friend button row
              _buildSearchRow(context),

              const SizedBox(height: 20),

              // Friend requests section (collapsible)
              _buildFriendRequestsSection(requestsAsync),

              // Friends list header
              _buildFriendsHeader(friendsAsync),

              const SizedBox(height: 12),

              // Friends list
              _buildFriendsList(friendsAsync),

              // Bottom padding for FAB
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'friendsCreateGroupFab',
        onPressed: () => context.push('/groups/create'),
        backgroundColor: const Color(0xFF81CEF2),
        icon: const Icon(AppIcons.add, color: Colors.white),
        label: const Text(
          'สร้างกลุ่มใหม่',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildSearchRow(BuildContext context) {
    return Row(
      children: [
        // Search bar
        Expanded(
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(22),
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'ค้นหาเพื่อน...',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                prefixIcon: Icon(
                  AppIcons.search,
                  color: Colors.grey[400],
                  size: 20,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Add friend button
        GestureDetector(
          onTap: () => _showAddFriendModal(context),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF81CEF2),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(
              AppIcons.personAdd,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFriendRequestsSection(
    AsyncValue<PendingRequests> requestsAsync,
  ) {
    return requestsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (requests) {
        if (requests.incoming.isEmpty) return const SizedBox.shrink();

        return Column(
          children: [
            // Header with expand/collapse
            GestureDetector(
              onTap: () =>
                  setState(() => _requestsExpanded = !_requestsExpanded),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'คำขอเป็นเพื่อน (${requests.incoming.length})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Icon(
                    _requestsExpanded
                        ? AppIcons.chevronUp
                        : AppIcons.chevronDown,
                    color: Colors.grey[600],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Request cards
            if (_requestsExpanded)
              ...requests.incoming.map(
                (req) => _IncomingRequestCard(request: req),
              ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _buildFriendsHeader(AsyncValue<List<Friend>> friendsAsync) {
    final count = friendsAsync.value?.length ?? 0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'เพื่อนของคุณ ($count คน)',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        IconButton(
          onPressed: () {
            // TODO: Show filter options
          },
          icon: Icon(AppIcons.tune, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildFriendsList(AsyncValue<List<Friend>> friendsAsync) {
    return friendsAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (err, _) => Center(
        child: RetryErrorState(
          error: err,
          onRetry: () {
            ref.invalidate(friendsProvider);
            ref.invalidate(pendingRequestsProvider);
          },
        ),
      ),
      data: (friends) {
        // Apply search filter
        final filtered = _searchQuery.isEmpty
            ? friends
            : friends
                  .where((f) => f.nickname.toLowerCase().contains(_searchQuery))
                  .toList();

        if (friends.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  Icon(AppIcons.people, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  const Text(
                    'ยังไม่มีเพื่อน',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'กดปุ่มเพิ่มเพื่อนเพื่อเริ่มต้น',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        }

        if (filtered.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  Icon(AppIcons.searchOff, size: 48, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  const Text(
                    'ไม่พบเพื่อนที่ค้นหา',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          children: filtered
              .map((friend) => _FriendCard(friend: friend))
              .toList(),
        );
      },
    );
  }

  void _showAddFriendModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const AddFriendModal(),
    );
  }
}

class _FriendCard extends ConsumerStatefulWidget {
  final Friend friend;

  const _FriendCard({required this.friend});

  @override
  ConsumerState<_FriendCard> createState() => _FriendCardState();
}

class _FriendCardState extends ConsumerState<_FriendCard> {
  bool _isSendingReminder = false;

  Future<void> _onPressRemind() async {
    if (_isSendingReminder || widget.friend.balance <= 0) return;

    final confirmed = await _showRemindDialog(widget.friend.nickname);
    if (!confirmed || !mounted) return;

    setState(() => _isSendingReminder = true);
    try {
      await ref
          .read(friendServiceProvider)
          .sendPaymentReminder(friendUserId: widget.friend.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ส่งการแจ้งเตือนไปยัง ${widget.friend.nickname} แล้ว'),
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
    } finally {
      if (mounted) setState(() => _isSendingReminder = false);
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

  @override
  Widget build(BuildContext context) {
    final friend = widget.friend;
    final isOwed = friend.balance > 0; // They owe you

    String balanceLabel;
    String balanceAmount;
    Color balanceColor;

    if (friend.balance == 0) {
      balanceLabel = 'ไม่มียอดค้างต่อกัน';
      balanceAmount = '';
      balanceColor = Colors.grey;
    } else if (isOwed) {
      balanceLabel = 'คุณรอรับเงิน';
      balanceAmount = '+${friend.balance.abs().toStringAsFixed(2)}฿';
      balanceColor = const Color(0xFF81CEF2);
    } else {
      balanceLabel = 'คุณค้างจ่าย';
      balanceAmount = '-${friend.balance.abs().toStringAsFixed(2)}฿';
      balanceColor = Colors.red;
    }

    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: const Color(0xFF81CEF2).withValues(alpha: 0.2),
          backgroundImage: friend.avatarUrl != null
              ? NetworkImage(friend.avatarUrl!)
              : null,
          child: friend.avatarUrl == null
              ? Text(
                  friend.nickname.isNotEmpty
                      ? friend.nickname[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: Color(0xFF81CEF2),
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                )
              : null,
        ),
        title: Text(friend.nickname, style: const TextStyle(fontSize: 16)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  balanceLabel,
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
                if (balanceAmount.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    balanceAmount,
                    style: TextStyle(
                      color: balanceColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: isOwed ? _onPressRemind : null,
              icon: _isSendingReminder
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      AppIcons.notifications,
                      color: isOwed
                          ? const Color(0xFF81CEF2)
                          : Colors.grey[350],
                      size: 24,
                    ),
            ),
          ],
        ),
        onTap: () {
          // TODO: Navigate to friend detail
        },
      ),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFF81CEF2).withValues(alpha: 0.2),
              backgroundImage: widget.request.requesterAvatarUrl != null
                  ? NetworkImage(widget.request.requesterAvatarUrl!)
                  : null,
              child: widget.request.requesterAvatarUrl == null
                  ? Text(
                      widget.request.requesterName.isNotEmpty
                          ? widget.request.requesterName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Color(0xFF81CEF2),
                        fontWeight: FontWeight.bold,
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
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
