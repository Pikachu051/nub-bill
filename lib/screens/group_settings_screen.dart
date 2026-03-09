import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:nubbill/models/balance_entry_model.dart';
import 'package:nubbill/models/trip_member_model.dart';
import 'package:nubbill/models/trip_model.dart';
import 'package:nubbill/screens/home_page.dart';
import 'package:nubbill/services/friend_service.dart';
import 'package:nubbill/services/trip_service.dart';
import 'package:nubbill/shared/app_icons.dart';

const String _kFont = 'LINESeedSansTH';

class GroupSettingsScreen extends ConsumerStatefulWidget {
  final String groupId;

  const GroupSettingsScreen({super.key, required this.groupId});

  @override
  ConsumerState<GroupSettingsScreen> createState() =>
      _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends ConsumerState<GroupSettingsScreen> {
  bool _isLeaving = false;
  bool _isDeleting = false;
  bool _isAddingMembers = false;

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(tripDetailProvider(widget.groupId));
    final balancesAsync = ref.watch(tripBalancesProvider(widget.groupId));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xB2141416),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'การตั้งค่ากลุ่ม',
          style: TextStyle(
            fontFamily: _kFont,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('โหลดข้อมูลกลุ่มไม่สำเร็จ: $err'),
          ),
        ),
        data: (detail) {
          if (detail == null) {
            return const Center(child: Text('ไม่พบข้อมูลกลุ่ม'));
          }

          final trip = detail.trip;
          final members = detail.members;

          final myBalance = balancesAsync.maybeWhen(
            data: (entries) => _findMyBalance(entries, detail.myMemberId),
            orElse: () => null,
          );

          final isBalancesLoading = balancesAsync.isLoading;
          final myNet = myBalance?.net ?? 0;
          final hasUnsettledBalance =
              myBalance != null && myNet.abs() >= 0.0001;
          final adminCount = members
              .where(
                (member) =>
                    member.role == 'admin' || member.userId == trip.createdBy,
              )
              .length;
          final isSoleAdminWithOtherMembers =
              detail.myRole == 'admin' && adminCount <= 1 && members.length > 1;

          String? leaveHint;
          if (isBalancesLoading) {
            leaveHint = 'กำลังตรวจสอบยอดคงค้าง...';
          } else if (isSoleAdminWithOtherMembers) {
            leaveHint = 'ต้องมอบสิทธิ์แอดมินให้เพื่อนก่อน ถึงจะออกจากกลุ่มได้';
          } else if (hasUnsettledBalance) {
            leaveHint = 'ต้องเคลียร์ยอดให้ครบก่อนน้า ถึงจะออกจากกลุ่มได้';
          }

          final canLeave = leaveHint == null;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTripHeader(trip, detail),
                const SizedBox(height: 24),
                _buildMembersSection(
                  context,
                  trip,
                  detail,
                  members,
                  balancesAsync,
                ),
                const SizedBox(height: 24),
                const Divider(color: Color(0x19141416), thickness: 1),
                const SizedBox(height: 12),
                _buildLeaveTile(canLeave),
                if (leaveHint != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 36, top: 2),
                    child: Text(
                      leaveHint,
                      style: const TextStyle(
                        color: Color(0x66141416),
                        fontSize: 14,
                        fontFamily: _kFont,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                _buildDeleteTile(detail),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTripHeader(Trip trip, TripDetailResponse detail) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            image: trip.coverUrl != null && trip.coverUrl!.isNotEmpty
                ? DecorationImage(
                    image: NetworkImage(trip.coverUrl!),
                    fit: BoxFit.cover,
                  )
                : null,
            color: const Color(0x1981CEF2),
          ),
          child: trip.coverUrl == null || trip.coverUrl!.isEmpty
              ? Icon(trip.category.icon, color: const Color(0xFF81CEF2))
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                trip.name,
                style: const TextStyle(
                  color: Color(0xB2141416),
                  fontSize: 16,
                  fontFamily: _kFont,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatDateRange(trip.startDate, trip.endDate),
                style: const TextStyle(
                  color: Color(0x7F141416),
                  fontSize: 10,
                  fontFamily: _kFont,
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: detail.myRole == 'admin'
              ? () async {
                  final updated = await context.push<bool>(
                    '/groups/create',
                    extra: {'trip': trip, 'members': detail.members},
                  );
                  if (!mounted) return;
                  if (updated == true) {
                    ref.invalidate(tripDetailProvider(widget.groupId));
                    ref.invalidate(tripBalancesProvider(widget.groupId));
                    ref.invalidate(tripDebtsProvider(widget.groupId));
                    if (mounted) setState(() {});
                  }
                }
              : null,
          child: Text(
            'แก้ไข',
            style: TextStyle(
              color: detail.myRole == 'admin'
                  ? const Color(0xFF81CEF2)
                  : const Color(0x66141416),
              fontSize: 14,
              fontFamily: _kFont,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMembersSection(
    BuildContext context,
    Trip trip,
    TripDetailResponse detail,
    List<TripMember> members,
    AsyncValue<List<BalanceEntry>> balancesAsync,
  ) {
    final entries = balancesAsync.valueOrNull ?? const <BalanceEntry>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'สมาชิกกลุ่ม (${members.length} คน)',
          style: const TextStyle(
            color: Color(0xB2141416),
            fontSize: 16,
            fontFamily: _kFont,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _inviteButton(
                icon: AppIcons.link,
                label: 'โดยลิงก์',
                onTap: () => _openInviteSheet(context, trip),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _inviteButton(
                icon: AppIcons.people,
                label: 'จากรายชื่อ',
                onTap: _isAddingMembers
                    ? null
                    : () => _showAddMembersDialog(detail),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (balancesAsync.isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          for (final member in members)
            _buildMemberTile(
              trip,
              detail,
              member,
              _findBalanceByMember(entries, member.id),
            ),
        ],
      ],
    );
  }

  Widget _inviteButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xB281CEF2)),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: const Color(0xB281CEF2)),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xB281CEF2),
                fontSize: 14,
                fontFamily: _kFont,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberTile(
    Trip trip,
    TripDetailResponse detail,
    TripMember member,
    BalanceEntry? entry,
  ) {
    final net = entry?.net ?? 0;
    final status = net < 0 ? 'ค้างจ่าย' : (net > 0 ? 'รอรับ' : 'เคลียร์');
    final color = net < 0
        ? const Color(0xFFFC5154)
        : (net > 0 ? const Color(0xFF3DCB57) : const Color(0x7F141416));
    final isAdminMember =
        member.userId == trip.createdBy || member.role == 'admin';
    final roleText = isAdminMember ? 'แอดมิน' : 'สมาชิก';
    final canOpenActions =
        detail.myRole == 'admin' && detail.myMemberId != member.id;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: canOpenActions
            ? () => _onMemberTap(member, isAdminMember)
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundImage: member.avatarUrl != null
                        ? NetworkImage(member.avatarUrl!)
                        : null,
                    backgroundColor: const Color(0x1981CEF2),
                    child: member.avatarUrl == null
                        ? Text(
                            member.displayName.isNotEmpty
                                ? member.displayName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: Color(0xFF81CEF2),
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            member.displayName,
                            style: const TextStyle(
                              color: Color(0xB2141416),
                              fontSize: 14,
                              fontFamily: _kFont,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (isAdminMember) ...[
                            const SizedBox(width: 6),
                            const Icon(
                              AppIcons.badgeCheck,
                              size: 14,
                              color: Color(0xFFE0B422),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        roleText,
                        style: const TextStyle(
                          color: Color(0x66141416),
                          fontSize: 12,
                          fontFamily: _kFont,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    status,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontFamily: _kFont,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${net.abs().toStringAsFixed(2)}฿',
                    style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontFamily: _kFont,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeaveTile(bool canLeave) {
    final color = canLeave ? const Color(0xB2141416) : const Color(0x66141416);

    return InkWell(
      onTap: canLeave && !_isLeaving ? _onLeaveGroup : null,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Icon(AppIcons.logout, size: 22, color: color),
            const SizedBox(width: 12),
            Text(
              _isLeaving ? 'กำลังออกจากกลุ่ม...' : 'ออกจากกลุ่ม',
              style: TextStyle(color: color, fontSize: 16, fontFamily: _kFont),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeleteTile(TripDetailResponse detail) {
    final canDelete = detail.myRole == 'admin';

    return InkWell(
      onTap: canDelete && !_isDeleting
          ? () => _onDeleteGroup(detail.trip)
          : null,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Icon(
              AppIcons.delete,
              size: 22,
              color: canDelete
                  ? const Color(0xFFFC5154)
                  : const Color(0x66FC5154),
            ),
            const SizedBox(width: 12),
            Text(
              _isDeleting ? 'กำลังลบกลุ่ม...' : 'ลบกลุ่ม',
              style: TextStyle(
                color: canDelete
                    ? const Color(0xFFFC5154)
                    : const Color(0x66FC5154),
                fontSize: 16,
                fontFamily: _kFont,
              ),
            ),
          ],
        ),
      ),
    );
  }

  BalanceEntry? _findMyBalance(List<BalanceEntry> entries, String? myMemberId) {
    if (myMemberId == null) return null;
    for (final entry in entries) {
      if (entry.memberId == myMemberId) return entry;
    }
    return null;
  }

  BalanceEntry? _findBalanceByMember(
    List<BalanceEntry> entries,
    String memberId,
  ) {
    for (final entry in entries) {
      if (entry.memberId == memberId) return entry;
    }
    return null;
  }

  String _formatDateRange(DateTime? start, DateTime? end) {
    if (start == null || end == null) return '-';

    String pad(int v) => v.toString().padLeft(2, '0');

    final yearStart = (start.year + 543) % 100;
    final yearEnd = (end.year + 543) % 100;

    return '${pad(start.day)}/${pad(start.month)}/${pad(yearStart)} - ${pad(end.day)}/${pad(end.month)}/${pad(yearEnd)}';
  }

  Future<void> _onMemberTap(TripMember member, bool isAdminMember) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.displayName,
                  style: const TextStyle(
                    fontFamily: _kFont,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: Color(0xB2141416),
                  ),
                ),
                const SizedBox(height: 14),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(AppIcons.badgeCheck),
                  title: const Text('มอบสิทธิ์แอดมิน'),
                  enabled: !isAdminMember && !member.isGhost,
                  onTap: !isAdminMember && !member.isGhost
                      ? () => Navigator.of(context).pop('make_admin')
                      : null,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    AppIcons.delete,
                    color: Color(0xFFFC5154),
                  ),
                  title: const Text(
                    'เตะออกจากกลุ่ม',
                    style: TextStyle(color: Color(0xFFFC5154)),
                  ),
                  onTap: () => Navigator.of(context).pop('kick'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (action == null || !mounted) return;

    if (action == 'make_admin') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('ยืนยันการมอบสิทธิ์'),
          content: Text(
            'จะให้ ${member.displayName} เป็นแอดมินกลุ่มจริงๆหย๋อ?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('ไม่เอา'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('ใช่แล้วจ้า'),
            ),
          ],
        ),
      );

      if (confirmed != true || !mounted) return;

      try {
        await ref
            .read(tripServiceProvider)
            .makeAdmin(widget.groupId, member.id);
        if (!mounted) return;
        ref.invalidate(tripDetailProvider(widget.groupId));
        ref.invalidate(tripBalancesProvider(widget.groupId));
        ref.invalidate(tripDebtsProvider(widget.groupId));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ตั้ง ${member.displayName} เป็นแอดมินแล้ว')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('มอบสิทธิ์แอดมินไม่สำเร็จ: $e')));
      }
      return;
    }

    final confirmedKick = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการเตะสมาชิก'),
        content: Text('ต้องการเตะ ${member.displayName} ออกจากกลุ่มใช่ไหม'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFC5154),
            ),
            child: const Text('เตะออกจากกลุ่ม'),
          ),
        ],
      ),
    );

    if (confirmedKick != true || !mounted) return;

    try {
      await ref
          .read(tripServiceProvider)
          .removeMember(widget.groupId, member.id);
      if (!mounted) return;
      ref.invalidate(tripDetailProvider(widget.groupId));
      ref.invalidate(tripBalancesProvider(widget.groupId));
      ref.invalidate(tripDebtsProvider(widget.groupId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เตะ ${member.displayName} ออกจากกลุ่มแล้ว')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('ไม่สามารถเตะสมาชิกได้: $e')));
    }
  }

  Future<void> _showAddMembersDialog(TripDetailResponse detail) async {
    final friends = await ref.read(friendsProvider.future);
    final existingUserIds = detail.members
        .where((member) => member.userId != null)
        .map((member) => member.userId!)
        .toSet();

    final candidates = friends
        .where((friend) => !existingUserIds.contains(friend.id))
        .toList();

    if (!mounted) return;

    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่มีรายชื่อเพื่อนที่เพิ่มได้แล้ว')),
      );
      return;
    }

    final selected = <String>{};

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: const Text('เลือกเพื่อนเข้ากลุ่ม'),
              content: SizedBox(
                width: 360,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: candidates.length,
                  itemBuilder: (context, index) {
                    final friend = candidates[index];
                    final checked = selected.contains(friend.id);

                    return CheckboxListTile(
                      value: checked,
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (value) {
                        setLocalState(() {
                          if (value == true) {
                            selected.add(friend.id);
                          } else {
                            selected.remove(friend.id);
                          }
                        });
                      },
                      title: Text(friend.nickname),
                      subtitle: Text(friend.email ?? ''),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('ยกเลิก'),
                ),
                FilledButton(
                  onPressed: selected.isEmpty
                      ? null
                      : () => Navigator.of(context).pop(true),
                  child: const Text('เพิ่มสมาชิก'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true || selected.isEmpty || !mounted) return;

    setState(() => _isAddingMembers = true);
    try {
      await ref
          .read(tripServiceProvider)
          .addMembers(widget.groupId, userIds: selected.toList());

      if (!mounted) return;
      ref.invalidate(tripDetailProvider(widget.groupId));
      ref.invalidate(tripBalancesProvider(widget.groupId));
      ref.invalidate(tripDebtsProvider(widget.groupId));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('เพิ่มสมาชิกเข้ากลุ่มแล้ว')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('เพิ่มสมาชิกไม่สำเร็จ: $e')));
    } finally {
      if (mounted) setState(() => _isAddingMembers = false);
    }
  }

  void _openInviteSheet(BuildContext context, Trip trip) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) => _InviteByLinkSheet(trip: trip),
    );
  }

  Future<void> _onLeaveGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ออกจากกลุ่ม'),
        content: const Text('ยืนยันว่าจะออกจากกลุ่มนี้ใช่ไหม'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('ออกจากกลุ่ม'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isLeaving = true);
    try {
      await ref.read(tripServiceProvider).leaveTrip(widget.groupId);

      if (!mounted) return;
      ref.invalidate(userTripsProvider);
      ref.invalidate(walletSummaryProvider);
      ref.invalidate(tripsProvider);
      context.go('/home');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ออกจากกลุ่มแล้ว')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ไม่สามารถออกจากกลุ่มได้: ${_cleanError(e)}')),
      );
    } finally {
      if (mounted) setState(() => _isLeaving = false);
    }
  }

  String _cleanError(Object error) {
    final raw = error.toString();
    const prefix = 'Exception: ';
    if (raw.startsWith(prefix)) {
      return raw.substring(prefix.length);
    }
    return raw;
  }

  Future<void> _onDeleteGroup(Trip trip) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ลบกลุ่ม'),
        content: Text(
          'ยืนยันว่าจะลบกลุ่ม ${trip.name} ใช่ไหม\nการกระทำนี้ย้อนกลับไม่ได้',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFC5154),
            ),
            child: const Text('ลบกลุ่ม'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);
    try {
      await ref.read(tripServiceProvider).deleteTrip(widget.groupId);

      if (!mounted) return;
      ref.invalidate(userTripsProvider);
      ref.invalidate(walletSummaryProvider);
      ref.invalidate(tripsProvider);
      context.go('/home');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ลบกลุ่มแล้ว')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('ไม่สามารถลบกลุ่มได้: $e')));
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }
}

class _InviteByLinkSheet extends StatefulWidget {
  final Trip trip;

  const _InviteByLinkSheet({required this.trip});

  @override
  State<_InviteByLinkSheet> createState() => _InviteByLinkSheetState();
}

class _InviteByLinkSheetState extends State<_InviteByLinkSheet> {
  final GlobalKey _qrKey = GlobalKey();
  bool _isSaving = false;

  String get _deepLink => 'nubbill://trip/join/${widget.trip.joinCode}';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0x33141416),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(AppIcons.close),
                ),
                Expanded(
                  child: Text(
                    widget.trip.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xB2141416),
                      fontSize: 24,
                      fontFamily: _kFont,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
            const SizedBox(height: 20),
            RepaintBoundary(
              key: _qrKey,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE9E9E9)),
                ),
                child: QrImageView(
                  data: _deepLink,
                  size: 205,
                  version: QrVersions.auto,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'รหัสเข้ากลุ่ม: ${widget.trip.joinCode}',
              style: const TextStyle(
                color: Color(0xB2141416),
                fontSize: 14,
                fontFamily: _kFont,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _actionButton(
                  icon: AppIcons.copy,
                  label: 'คัดลอกลิงก์',
                  onTap: _copyInviteLink,
                ),
                const SizedBox(width: 24),
                _actionButton(
                  icon: AppIcons.share,
                  label: 'แชร์',
                  onTap: _shareInviteLink,
                ),
                const SizedBox(width: 24),
                _actionButton(
                  icon: AppIcons.download,
                  label: _isSaving ? 'กำลังบันทึก' : 'บันทึก',
                  onTap: _isSaving ? null : _saveQr,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 84,
        child: Column(
          children: [
            Icon(icon, color: const Color(0xB2141416), size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xB2141416),
                fontSize: 14,
                fontFamily: _kFont,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyInviteLink() async {
    await Clipboard.setData(ClipboardData(text: _deepLink));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('คัดลอกลิงก์แล้ว')));
  }

  Future<void> _shareInviteLink() async {
    await Share.share(
      'มาเข้ากลุ่ม ${widget.trip.name} ใน Nub-Bill กัน\n$_deepLink\nรหัสเข้ากลุ่ม: ${widget.trip.joinCode}',
      subject: 'ชวนเข้ากลุ่ม ${widget.trip.name}',
    );
  }

  Future<void> _saveQr() async {
    setState(() => _isSaving = true);
    try {
      final boundary =
          _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}/trip_invite_${widget.trip.joinCode}.png',
      );
      await file.writeAsBytes(byteData.buffer.asUint8List());

      await Gal.putImage(file.path, album: 'NubBill');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('บันทึกรูปเชิญเข้ากลุ่มแล้ว')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('บันทึกไม่สำเร็จ: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
