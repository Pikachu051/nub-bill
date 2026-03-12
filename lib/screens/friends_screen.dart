import 'package:flutter/material.dart';
import 'package:nubbill/shared/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nubbill/services/friend_service.dart';
import 'package:nubbill/services/trip_service.dart';
import 'package:nubbill/widgets/add_friend_modal.dart';
import 'package:nubbill/widgets/group_quick_actions_fab.dart';
import 'package:nubbill/widgets/retry_error_state.dart';
import 'package:nubbill/shared/widgets/realtime_animated_list.dart';
import 'package:nubbill/shared/widgets/list_animations.dart';
import 'package:nubbill/shared/widgets/animated_item_wrapper.dart';

const String _kFont = 'LINESeedSansTH';

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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'รายชื่อเพื่อน',
          style: TextStyle(
            color: Color(0xB2141416),
            fontSize: 20,
            fontFamily: _kFont,
            fontWeight: FontWeight.w600,
          ),
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
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSearchRow(context),
              const SizedBox(height: 24),
              _buildFriendRequestsSection(requestsAsync),
              _buildFriendsHeader(friendsAsync),
              const SizedBox(height: 12),
              _buildFriendsList(friendsAsync),
            ],
          ),
        ),
      ),
      floatingActionButton: GroupQuickActionsFab(
        onCreateGroup: () => context.push('/groups/create'),
        onJoinedGroup: () {
          ref.invalidate(tripsProvider);
        },
      ),
    );
  }

  Widget _buildSearchRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0x19141416),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              children: [
                const Icon(AppIcons.search, color: Color(0x66141416), size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    textAlignVertical: TextAlignVertical.center,
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: 'ค้นหาเพื่อน. . .',
                      hintStyle: TextStyle(
                        color: Color(0x66141416),
                        fontSize: 16,
                        fontFamily: _kFont,
                        fontWeight: FontWeight.w400,
                      ),
                      filled: false,
                      fillColor: Colors.transparent,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    style: const TextStyle(
                      color: Color(0xB2141416),
                      fontSize: 16,
                      fontFamily: _kFont,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        InkWell(
          onTap: () => _showAddFriendModal(context),
          borderRadius: BorderRadius.circular(15),
          child: Container(
            width: 48,
            height: 48,
            decoration: ShapeDecoration(
              color: const Color(0xFF81CEF2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            child: const Icon(
              AppIcons.personAdd,
              color: Colors.white,
              size: 24,
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () =>
                  setState(() => _requestsExpanded = !_requestsExpanded),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'คำขอเป็นเพื่อน (${requests.incoming.length})',
                    style: const TextStyle(
                      color: Color(0xB2141416),
                      fontSize: 16,
                      fontFamily: _kFont,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Icon(
                    _requestsExpanded
                        ? AppIcons.chevronUp
                        : AppIcons.chevronDown,
                    color: const Color(0x7F141416),
                    size: 20,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_requestsExpanded)
              ...requests.incoming.asMap().entries.map(
                (entry) => AnimatedItemWrapper(
                  key: ValueKey(entry.value.id),
                  index: entry.key,
                  child: _IncomingRequestCard(request: entry.value),
                ),
              ),
            const SizedBox(height: 24),
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
          style: const TextStyle(
            color: Color(0xB2141416),
            fontSize: 16,
            fontFamily: _kFont,
            fontWeight: FontWeight.w600,
          ),
        ),
        InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(12),
          child: const Padding(
            padding: EdgeInsets.all(2),
            child: Icon(AppIcons.tune, color: Color(0x7F141416), size: 20),
          ),
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
                    style: TextStyle(
                      color: Color(0x7F141416),
                      fontFamily: _kFont,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'กดปุ่มเพิ่มเพื่อนเพื่อเริ่มต้น',
                    style: TextStyle(
                      color: Color(0x7F141416),
                      fontSize: 12,
                      fontFamily: _kFont,
                    ),
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
                    style: TextStyle(
                      color: Color(0x7F141416),
                      fontFamily: _kFont,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return RealtimeAnimatedColumn<Friend>(
          items: filtered,
          keyExtractor: (f) => f.id,
          itemBuilder: (ctx, friend, animation) =>
              slideInBuilder(ctx, Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _FriendCard(friend: friend),
              ), animation),
          removedItemBuilder: (ctx, friend, animation) =>
              slideOutBuilder(ctx, Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _FriendCard(friend: friend),
              ), animation),
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
      balanceColor = const Color(0x7F141416);
    } else if (isOwed) {
      balanceLabel = 'คุณรอรับเงิน';
      balanceAmount = '+${friend.balance.abs().toStringAsFixed(2)}฿';
      balanceColor = const Color(0xFF3DCB57);
    } else {
      balanceLabel = 'คุณค้างจ่าย';
      balanceAmount = '-${friend.balance.abs().toStringAsFixed(2)}฿';
      balanceColor = const Color(0xFFFC5154);
    }

    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0x1981CEF2),
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
                              fontSize: 18,
                              fontFamily: _kFont,
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      friend.nickname,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xB2141416),
                        fontSize: 16,
                        fontFamily: _kFont,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      balanceLabel,
                      style: TextStyle(
                        color: balanceColor,
                        fontSize: 12,
                        fontFamily: _kFont,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    if (balanceAmount.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        balanceAmount,
                        style: TextStyle(
                          color: balanceColor,
                          fontSize: 14,
                          fontFamily: _kFont,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ],
                ),
                if (isOwed) ...[
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: _isSendingReminder ? null : _onPressRemind,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: ShapeDecoration(
                        shape: RoundedRectangleBorder(
                          side: const BorderSide(
                            width: 1,
                            color: Color(0xFF81CEF2),
                          ),
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: Center(
                        child: _isSendingReminder
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF81CEF2),
                                ),
                              )
                            : const Icon(
                                AppIcons.notifications,
                                color: Color(0xFF81CEF2),
                                size: 16,
                              ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
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
      color: const Color(0xFFF8FBFD),
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                    style: const TextStyle(
                      color: Color(0xB2141416),
                      fontFamily: _kFont,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    timeText,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0x7F141416),
                      fontFamily: _kFont,
                    ),
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
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0x7F141416),
                ),
                child: const Text('ลบ', style: TextStyle(fontFamily: _kFont)),
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
                child: const Text(
                  'ยืนยัน',
                  style: TextStyle(fontFamily: _kFont),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
