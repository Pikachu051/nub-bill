import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nubbill/models/expense_category.dart';
import 'package:nubbill/models/expense_detail_model.dart';
import 'package:nubbill/models/trip_member_model.dart';
import 'package:nubbill/services/expense_service.dart';
import 'package:nubbill/services/trip_service.dart';
import 'package:nubbill/shared/app_icons.dart';

// ── palette  (exact Figma tokens) ────────────────────────────────────────────
const Color _kBlue = Color(0xFF81CEF2);
const Color _kText70 = Color(0xB2141416); // primary text
const Color _kText50 = Color(0x7F141416); // secondary label
const Color _kText40 = Color(0x66141416); // icons / placeholder
const Color _kText20 = Color(0x33141416); // strong placeholder
const Color _kFill10 = Color(0x19141416); // input bg / mode switcher bg
const Color _kFill30 = Color(0x4C141416); // unchecked "select all"
const String _kFont = 'LINESeedSansTH';

// ─────────────────────────────────────────────────────────────────────────────

enum _ComposerMode { equal, itemized }

// ─────────────────────────────────────────────────────────────────────────────

class AddExpenseScreen extends ConsumerStatefulWidget {
  final String? tripId;
  final String? tripName;
  final List<TripMember>? members;
  final String? expenseId;
  final bool isEdit;

  const AddExpenseScreen({
    super.key,
    this.tripId,
    this.tripName,
    this.members,
    this.expenseId,
    this.isEdit = false,
  });

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

// ─────────────────────────────────────────────────────────────────────────────

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  // ── controllers / focus ───────────────────────────────────────────────────
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _amountFocusNode = FocusNode();
  final _memberSearchController = TextEditingController();

  // ── async flags ───────────────────────────────────────────────────────────
  bool _isInitializing = true;
  bool _isSaving = false;
  String? _error;
  String _memberSearchQuery = '';

  // ── data ──────────────────────────────────────────────────────────────────
  DateTime _date = DateTime.now();
  _ComposerMode _mode = _ComposerMode.equal;
  ExpenseCategory _category = ExpenseCategory.food;
  List<_MemberDraft> _memberDrafts = [];
  Set<String> _selectedSplitMemberIds = {};
  List<_ItemDraft> _itemDrafts = [];
  Set<String> _selectedPayerIds = {};
  Map<String, double> _payerAmountsByMemberId = {};
  String? _primaryPayerId;

  bool get _isEdit =>
      widget.isEdit && (widget.expenseId?.trim().isNotEmpty ?? false);
  double get _itemizedTotal =>
      _itemDrafts.fold(0, (sum, itemDraft) => sum + itemDraft.lineTotal);
  double get _enteredAmount =>
      double.tryParse(_amountController.text.trim()) ?? 0;
  double get _currentExpenseAmount =>
      _mode == _ComposerMode.itemized ? _itemizedTotal : _enteredAmount;
  List<_MemberDraft> get _filteredMemberDrafts {
    final normalizedQuery = _memberSearchQuery.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return _memberDrafts;
    return _memberDrafts
        .where(
          (memberDraft) =>
              memberDraft.name.toLowerCase().contains(normalizedQuery),
        )
        .toList();
  }

  // ── lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_handleAmountChanged);
    _memberSearchController.addListener(_handleMemberSearchChanged);
    _initializeScreen();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _amountFocusNode.dispose();
    _memberSearchController.dispose();
    super.dispose();
  }

  // ── initialisation ────────────────────────────────────────────────────────

  Future<void> _initializeScreen() async {
    try {
      List<TripMember> tripMembers = widget.members ?? [];
      if (tripMembers.isEmpty && (widget.tripId?.isNotEmpty ?? false)) {
        final tripDetail = await ref
            .read(tripServiceProvider)
            .getTripDetail(widget.tripId!);
        tripMembers = tripDetail?.members ?? [];
      }
      _setMemberDrafts(tripMembers);
      if (_isEdit) {
        final expenseDetail = await ref
            .read(expenseServiceProvider)
            .getExpenseDetail(widget.expenseId!);
        _applyExpenseDetail(expenseDetail);
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  void _setMemberDrafts(List<TripMember> tripMembers) {
    final memberDrafts = tripMembers
        .map(
          (tripMember) => _MemberDraft(
            id: tripMember.id,
            name: tripMember.displayName,
            avatarUrl: tripMember.avatarUrl,
          ),
        )
        .toList();
    _memberDrafts = memberDrafts;
    _selectedSplitMemberIds = memberDrafts
        .map((memberDraft) => memberDraft.id)
        .toSet();
    if (memberDrafts.isEmpty) {
      _selectedPayerIds = {};
      _payerAmountsByMemberId = {};
      _primaryPayerId = null;
      return;
    }

    final defaultPayerId = memberDrafts.first.id;
    _selectedPayerIds = {defaultPayerId};
    _primaryPayerId = defaultPayerId;
    _syncPayerSelection(rebalanceAmounts: true);
  }

  void _applyExpenseDetail(ExpenseDetail? expenseDetail) {
    if (expenseDetail == null) return;
    _descriptionController.text = expenseDetail.description;
    _category = expenseDetail.category;
    _date = DateTime.tryParse(expenseDetail.expenseDate) ?? DateTime.now();
    final memberIds = _memberDrafts
        .map((memberDraft) => memberDraft.id)
        .toSet();
    _selectedSplitMemberIds = expenseDetail.splits
        .map((split) => split.memberId)
        .where(memberIds.contains)
        .toSet();
    if (_selectedSplitMemberIds.isEmpty) {
      _selectedSplitMemberIds = memberIds;
    }
    _itemDrafts = expenseDetail.items
        .map(
          (item) => _ItemDraft(
            id: item.id,
            name: item.name,
            amount: item.amount,
            quantity: item.quantity,
            sharedIds:
                (item.sharedByMemberIds.isEmpty
                        ? memberIds
                        : item.sharedByMemberIds.toSet())
                    .where(memberIds.contains)
                    .toSet(),
          ),
        )
        .toList();
    _mode = expenseDetail.splitType == 'itemized'
        ? _ComposerMode.itemized
        : _ComposerMode.equal;

    if (expenseDetail.payers.isNotEmpty) {
      _selectedPayerIds = expenseDetail.payers
          .map((payerEntry) => payerEntry.memberId)
          .where(memberIds.contains)
          .toSet();
      _payerAmountsByMemberId = {
        for (final payerEntry in expenseDetail.payers)
          if (memberIds.contains(payerEntry.memberId))
            payerEntry.memberId: payerEntry.amount,
      };
      _primaryPayerId = _selectedPayerIds.contains(expenseDetail.payerId)
          ? expenseDetail.payerId
          : (_selectedPayerIds.isEmpty ? null : _selectedPayerIds.first);
    } else {
      _primaryPayerId = memberIds.contains(expenseDetail.payerId)
          ? expenseDetail.payerId
          : (_memberDrafts.isEmpty ? null : _memberDrafts.first.id);
      _selectedPayerIds = _primaryPayerId == null ? {} : {_primaryPayerId!};
      _payerAmountsByMemberId = _primaryPayerId == null
          ? {}
          : {_primaryPayerId!: expenseDetail.amount};
    }

    if (_mode == _ComposerMode.itemized) {
      _syncTotalAmount();
    } else {
      _amountController.text = expenseDetail.amount.toStringAsFixed(2);
      _syncPayerSelection();
    }
  }

  // ── computed ──────────────────────────────────────────────────────────────

  void _handleAmountChanged() {
    if (!mounted || _mode != _ComposerMode.equal) return;
    setState(() => _syncPayerSelection());
  }

  void _handleMemberSearchChanged() {
    if (!mounted) return;
    setState(() {
      _memberSearchQuery = _memberSearchController.text;
    });
  }

  void _syncTotalAmount() {
    _amountController.text = _itemizedTotal.toStringAsFixed(2);
    _syncPayerSelection(rebalanceAmounts: true);
  }

  void _syncPayerSelection({bool rebalanceAmounts = false}) {
    final validMemberIds = _memberDrafts
        .map((memberDraft) => memberDraft.id)
        .toSet();
    _selectedPayerIds = _selectedPayerIds
        .where(validMemberIds.contains)
        .toSet();

    if (_selectedPayerIds.isEmpty && _primaryPayerId != null) {
      if (validMemberIds.contains(_primaryPayerId)) {
        _selectedPayerIds = {_primaryPayerId!};
      }
    }

    if (_selectedPayerIds.isEmpty && _memberDrafts.isNotEmpty) {
      _selectedPayerIds = {_memberDrafts.first.id};
    }

    if (_primaryPayerId == null ||
        !_selectedPayerIds.contains(_primaryPayerId)) {
      _primaryPayerId = _selectedPayerIds.isEmpty
          ? null
          : _selectedPayerIds.first;
    }

    _payerAmountsByMemberId.removeWhere(
      (memberId, _) => !_selectedPayerIds.contains(memberId),
    );

    final totalAmount = _currentExpenseAmount;
    if (_selectedPayerIds.length <= 1) {
      if (_primaryPayerId != null) {
        _payerAmountsByMemberId = {_primaryPayerId!: totalAmount};
      }
      return;
    }

    final selectedPayerList = _selectedPayerIds.toList();
    final currentPayerTotal = selectedPayerList.fold<double>(
      0,
      (sum, memberId) => sum + (_payerAmountsByMemberId[memberId] ?? 0),
    );
    final hasEveryPayerAmount = selectedPayerList.every(
      (memberId) => (_payerAmountsByMemberId[memberId] ?? 0) > 0,
    );

    if (rebalanceAmounts ||
        !hasEveryPayerAmount ||
        (currentPayerTotal - totalAmount).abs() > 0.01) {
      _payerAmountsByMemberId = _distributeAmountAcrossMembers(
        totalAmount,
        selectedPayerList,
      );
    }
  }

  Map<String, double> _distributeAmountAcrossMembers(
    double totalAmount,
    List<String> memberIds,
  ) {
    if (memberIds.isEmpty) return {};
    final totalCents = (totalAmount * 100).round();
    final baseShare = totalCents ~/ memberIds.length;
    final remainder = totalCents % memberIds.length;
    return {
      for (final entry in memberIds.asMap().entries)
        entry.value: (baseShare + (entry.key < remainder ? 1 : 0)) / 100,
    };
  }

  // ── actions ───────────────────────────────────────────────────────────────

  void _showSnackBar(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _save() async {
    if (_isInitializing || _isSaving) return;
    if (widget.tripId?.isEmpty ?? true) {
      return _showSnackBar('กรุณาเลือกกลุ่ม');
    }

    final descriptionText = _descriptionController.text.trim();
    if (descriptionText.isEmpty) {
      return _showSnackBar('กรุณากรอกชื่อบิล');
    }

    _syncPayerSelection();
    if (_primaryPayerId == null || _selectedPayerIds.isEmpty) {
      return _showSnackBar('กรุณาเลือกคนจ่าย');
    }

    final splitType = _mode == _ComposerMode.equal ? 'equal' : 'itemized';
    double amount;
    List<String>? splitMemberIds;
    List<Map<String, dynamic>>? itemPayloads;
    List<Map<String, dynamic>>? payerPayloads;

    if (_mode == _ComposerMode.equal) {
      amount = _enteredAmount;
      if (amount <= 0) return _showSnackBar('กรุณากรอกยอดเงิน');
      if (_selectedSplitMemberIds.isEmpty) {
        return _showSnackBar('กรุณาเลือกผู้หารอย่างน้อย 1 คน');
      }
      splitMemberIds = _selectedSplitMemberIds.toList();
    } else {
      if (_itemDrafts.isEmpty) {
        return _showSnackBar('กรุณาเพิ่มรายการอย่างน้อย 1 รายการ');
      }
      if (_itemDrafts.any((itemDraft) => itemDraft.sharedIds.isEmpty)) {
        return _showSnackBar('ทุกรายการต้องมีผู้หาร');
      }
      amount = _itemizedTotal;
      if (amount <= 0) return _showSnackBar('ยอดรวมต้องมากกว่า 0');
      itemPayloads = _itemDrafts
          .map(
            (itemDraft) => {
              'name': itemDraft.name,
              'amount': itemDraft.amount,
              'quantity': itemDraft.quantity,
              'shared_by_member_ids': itemDraft.sharedIds.toList(),
            },
          )
          .toList();
    }

    if (_selectedPayerIds.length > 1) {
      payerPayloads = _selectedPayerIds
          .map(
            (memberId) => {
              'member_id': memberId,
              'amount': _payerAmountsByMemberId[memberId] ?? 0,
            },
          )
          .toList();

      if (payerPayloads.any((payer) => (payer['amount'] as double) <= 0)) {
        return _showSnackBar('ยอดของผู้จ่ายแต่ละคนต้องมากกว่า 0');
      }

      final payerTotal = payerPayloads.fold<double>(
        0,
        (sum, payer) => sum + (payer['amount'] as double),
      );
      if ((payerTotal - amount).abs() > 0.01) {
        return _showSnackBar('ยอดรวมผู้จ่ายต้องเท่ากับยอดบิล');
      }
    }

    setState(() => _isSaving = true);
    try {
      final expenseService = ref.read(expenseServiceProvider);
      if (_isEdit) {
        await expenseService.updateExpense(
          widget.expenseId!,
          description: descriptionText,
          amount: amount,
          category: _category,
          splitType: splitType,
          payerMemberId: _primaryPayerId,
          payers: payerPayloads,
          expenseDate: _date,
          splitMemberIds: splitMemberIds,
          items: itemPayloads,
        );
      } else {
        await expenseService.createExpense(
          tripId: widget.tripId!,
          description: descriptionText,
          amount: amount,
          category: _category,
          splitType: splitType,
          payerMemberId: _primaryPayerId,
          payers: payerPayloads,
          expenseDate: _date,
          splitMemberIds: splitMemberIds,
          items: itemPayloads,
        );
      }
      ref.invalidate(tripExpensesProvider(widget.tripId!));
      ref.invalidate(tripBalancesProvider(widget.tripId!));
      ref.invalidate(tripDebtsProvider(widget.tripId!));
      if (_isEdit) ref.invalidate(expenseDetailProvider(widget.expenseId!));
      if (mounted) {
        _showSnackBar(_isEdit ? 'อัปเดตบิลสำเร็จ' : 'เพิ่มบิลสำเร็จ');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) _showSnackBar('บันทึกไม่สำเร็จ: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (pickedDate != null && mounted) setState(() => _date = pickedDate);
  }

  Future<void> _pickPayers() async {
    final selectedPayerIds = Set<String>.from(_selectedPayerIds);
    final primaryPayerId = ValueNotifier<String?>(_primaryPayerId);
    final amountControllers = <String, TextEditingController>{
      for (final memberDraft in _memberDrafts)
        memberDraft.id: TextEditingController(
          text: (_payerAmountsByMemberId[memberDraft.id] ?? 0).toStringAsFixed(
            2,
          ),
        ),
    };

    void ensureLocalPayerState({bool rebalanceAmounts = false}) {
      if (selectedPayerIds.isEmpty) {
        primaryPayerId.value = null;
        return;
      }

      if (primaryPayerId.value == null ||
          !selectedPayerIds.contains(primaryPayerId.value)) {
        primaryPayerId.value = selectedPayerIds.first;
      }

      if (selectedPayerIds.length <= 1) {
        final onlyPayerId = selectedPayerIds.first;
        amountControllers[onlyPayerId]?.text = _currentExpenseAmount
            .toStringAsFixed(2);
        return;
      }

      final currentTotal = selectedPayerIds.fold<double>(
        0,
        (sum, memberId) =>
            sum +
            (double.tryParse(amountControllers[memberId]?.text ?? '') ?? 0),
      );
      final shouldRebalance =
          rebalanceAmounts ||
          selectedPayerIds.any(
            (memberId) =>
                (double.tryParse(amountControllers[memberId]?.text ?? '') ??
                    0) <=
                0,
          ) ||
          (currentTotal - _currentExpenseAmount).abs() > 0.01;

      if (!shouldRebalance) return;
      final distributedAmounts = _distributeAmountAcrossMembers(
        _currentExpenseAmount,
        selectedPayerIds.toList(),
      );
      for (final entry in distributedAmounts.entries) {
        amountControllers[entry.key]?.text = entry.value.toStringAsFixed(2);
      }
    }

    ensureLocalPayerState(rebalanceAmounts: true);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (bottomSheetContext, setBottomSheetState) {
          final viewInsets = MediaQuery.viewInsetsOf(bottomSheetContext);
          return Padding(
            padding: EdgeInsets.only(bottom: viewInsets.bottom),
            child: SafeArea(
              child: SizedBox(
                height:
                    (MediaQuery.sizeOf(bottomSheetContext).height * 0.78 -
                            viewInsets.bottom)
                        .clamp(200.0, double.infinity),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: _kFill10,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'เลือกคนจ่าย',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        fontFamily: _kFont,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'เลือกได้หลายคน และยอดรวมผู้จ่ายต้องเท่ากับยอดบิล',
                      style: TextStyle(
                        color: _kText50,
                        fontSize: 12,
                        fontFamily: _kFont,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        itemCount: _memberDrafts.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, index) {
                          final memberDraft = _memberDrafts[index];
                          final isSelected = selectedPayerIds.contains(
                            memberDraft.id,
                          );
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFEAF6FD)
                                  : const Color(0xFFF7F9FC),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? _kBlue
                                    : const Color(0xFFE4EAF1),
                              ),
                            ),
                            child: Column(
                              children: [
                                InkWell(
                                  onTap: () {
                                    setBottomSheetState(() {
                                      if (isSelected) {
                                        selectedPayerIds.remove(memberDraft.id);
                                      } else {
                                        selectedPayerIds.add(memberDraft.id);
                                      }
                                      ensureLocalPayerState(
                                        rebalanceAmounts: true,
                                      );
                                    });
                                  },
                                  child: Row(
                                    children: [
                                      _buildAvatar(memberDraft, radius: 18),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          memberDraft.name,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            fontFamily: _kFont,
                                          ),
                                        ),
                                      ),
                                      Icon(
                                        isSelected
                                            ? AppIcons.checkCircleFilled
                                            : AppIcons.circleUnchecked,
                                        color: isSelected
                                            ? _kBlue
                                            : const Color(0xFFBCC6D4),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isSelected) ...[
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Container(
                                          height: 44,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                AppIcons.money,
                                                size: 16,
                                                color: _kText40,
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: TextField(
                                                  controller:
                                                      amountControllers[memberDraft
                                                          .id],
                                                  keyboardType:
                                                      const TextInputType.numberWithOptions(
                                                        decimal: true,
                                                      ),
                                                  inputFormatters: [
                                                    FilteringTextInputFormatter.allow(
                                                      RegExp(r'^\d*\.?\d{0,2}'),
                                                    ),
                                                  ],
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w700,
                                                    color: _kText70,
                                                    fontFamily: _kFont,
                                                  ),
                                                  decoration:
                                                      const InputDecoration.collapsed(
                                                        hintText: '0.00',
                                                        hintStyle: TextStyle(
                                                          color: _kText20,
                                                          fontFamily: _kFont,
                                                        ),
                                                      ),
                                                ),
                                              ),
                                              const Text(
                                                '฿',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                  color: _kText50,
                                                  fontFamily: _kFont,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      GestureDetector(
                                        onTap: () {
                                          setBottomSheetState(() {
                                            primaryPayerId.value =
                                                memberDraft.id;
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                primaryPayerId.value ==
                                                    memberDraft.id
                                                ? _kBlue
                                                : Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                          child: Text(
                                            'คนหลัก',
                                            style: TextStyle(
                                              color:
                                                  primaryPayerId.value ==
                                                      memberDraft.id
                                                  ? Colors.white
                                                  : _kText50,
                                              fontWeight: FontWeight.w700,
                                              fontFamily: _kFont,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            if (selectedPayerIds.isEmpty) {
                              _showSnackBar('กรุณาเลือกคนจ่ายอย่างน้อย 1 คน');
                              return;
                            }

                            final nextPayerAmounts = <String, double>{};
                            for (final memberId in selectedPayerIds) {
                              final payerAmount =
                                  double.tryParse(
                                    amountControllers[memberId]?.text.trim() ??
                                        '',
                                  ) ??
                                  0;
                              if (payerAmount <= 0) {
                                _showSnackBar(
                                  'ยอดของผู้จ่ายแต่ละคนต้องมากกว่า 0',
                                );
                                return;
                              }
                              nextPayerAmounts[memberId] = payerAmount;
                            }

                            final payerTotal = nextPayerAmounts.values
                                .fold<double>(
                                  0,
                                  (sum, payerAmount) => sum + payerAmount,
                                );
                            if ((payerTotal - _currentExpenseAmount).abs() >
                                0.01) {
                              _showSnackBar('ยอดรวมผู้จ่ายต้องเท่ากับยอดบิล');
                              return;
                            }

                            setState(() {
                              _selectedPayerIds = Set<String>.from(
                                selectedPayerIds,
                              );
                              _primaryPayerId = primaryPayerId.value;
                              _payerAmountsByMemberId = nextPayerAmounts;
                              _syncPayerSelection();
                            });
                            Navigator.pop(bottomSheetContext);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kBlue,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: const Text(
                            'บันทึกผู้จ่าย',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontFamily: _kFont,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    // Defer disposal to the next frame to avoid interacting with any
    // bottom-sheet transition widgets that may still reference controllers.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      primaryPayerId.dispose();
      for (final controller in amountControllers.values) {
        controller.dispose();
      }
    });
  }

  // ── item dialogs ──────────────────────────────────────────────────────────

  Future<void> _addItemFlow() async {
    final itemSeed = await _seedDialog();
    if (itemSeed == null || !mounted) return;
    final itemDraft = await _detailDialog(
      initial: _ItemDraft(
        name: itemSeed.name,
        amount: itemSeed.amount,
        quantity: itemSeed.quantity,
        sharedIds: _memberDrafts.map((memberDraft) => memberDraft.id).toSet(),
      ),
    );
    if (itemDraft == null || !mounted) return;
    setState(() {
      _itemDrafts = [..._itemDrafts, itemDraft];
      _syncTotalAmount();
    });
  }

  Future<_ItemSeed?> _seedDialog() async {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    final quantityController = TextEditingController(text: '1');

    final result = await showDialog<_ItemSeed>(
      context: context,
      builder: (ctx) {
        final screenHeight = MediaQuery.sizeOf(ctx).height;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 32,
            vertical: 56,
          ),
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 380,
                maxHeight: screenHeight * 0.78,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDialogHeader(
                        icon: AppIcons.receipt,
                        title: 'เพิ่มรายการ',
                        subtitle:
                            'ใส่ชื่อ ราคา และจำนวนของรายการก่อนเลือกผู้หาร',
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _kBlue.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            _dialogField(
                              nameController,
                              'ชื่อรายการ',
                              hint: 'เช่น หมูกระทะ',
                              icon: AppIcons.description,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  flex: 7,
                                  child: _dialogField(
                                    amountController,
                                    'ราคา / ชิ้น',
                                    hint: '0.00',
                                    keyboard:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    icon: AppIcons.money,
                                    suffixText: '฿',
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                        RegExp(r'^\d*\.?\d{0,2}'),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 5,
                                  child: _dialogField(
                                    quantityController,
                                    'จำนวน',
                                    hint: '1',
                                    keyboard: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _kText70,
                                minimumSize: const Size.fromHeight(48),
                                side: BorderSide(
                                  color: _kBlue.withValues(alpha: 0.2),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                'ยกเลิก',
                                style: TextStyle(
                                  fontFamily: _kFont,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                final itemName = nameController.text.trim();
                                final itemAmount =
                                    double.tryParse(
                                      amountController.text.trim(),
                                    ) ??
                                    0;
                                final itemQuantity =
                                    int.tryParse(
                                      quantityController.text.trim(),
                                    ) ??
                                    0;
                                if (itemName.isEmpty) {
                                  _showSnackBar('กรุณากรอกชื่อ');
                                  return;
                                }
                                if (itemAmount <= 0) {
                                  _showSnackBar('กรุณากรอกราคา');
                                  return;
                                }
                                if (itemQuantity <= 0) {
                                  _showSnackBar('กรุณากรอกจำนวน');
                                  return;
                                }
                                Navigator.pop(
                                  ctx,
                                  _ItemSeed(
                                    name: itemName,
                                    amount: itemAmount,
                                    quantity: itemQuantity,
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _kBlue,
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                'ถัดไป',
                                style: TextStyle(
                                  fontFamily: _kFont,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      nameController.dispose();
      amountController.dispose();
      quantityController.dispose();
    });
    return result;
  }

  Future<_ItemDraft?> _detailDialog({required _ItemDraft initial}) async {
    final nameController = TextEditingController(text: initial.name);
    final amountController = TextEditingController(
      text: initial.amount.toStringAsFixed(2),
    );
    final quantityController = TextEditingController(
      text: initial.quantity.toString(),
    );
    final availableMemberIds = _memberDrafts
        .map((memberDraft) => memberDraft.id)
        .toSet();
    final selectedSharedMemberIds =
        (initial.sharedIds.isEmpty ? availableMemberIds : initial.sharedIds)
            .where(availableMemberIds.contains)
            .toSet();

    final result = await showDialog<_ItemDraft>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 28,
              vertical: 40,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 392,
                maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.76,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDialogHeader(
                        icon: AppIcons.edit,
                        title: 'รายละเอียดรายการ',
                        subtitle:
                            'แก้ชื่อ ราคา จำนวน และเลือกผู้ที่ต้องหารรายการนี้',
                      ),
                      const SizedBox(height: 18),
                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: _kBlue.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Column(
                                  children: [
                                    _dialogField(
                                      nameController,
                                      'ชื่อรายการ',
                                      hint: 'เช่น หมูกระทะ',
                                      icon: AppIcons.description,
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          flex: 7,
                                          child: _dialogField(
                                            amountController,
                                            'ราคา / ชิ้น',
                                            hint: '0.00',
                                            keyboard:
                                                const TextInputType.numberWithOptions(
                                                  decimal: true,
                                                ),
                                            icon: AppIcons.money,
                                            suffixText: '฿',
                                            inputFormatters: [
                                              FilteringTextInputFormatter.allow(
                                                RegExp(r'^\d*\.?\d{0,2}'),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _dialogField(
                                            quantityController,
                                            'จำนวน',
                                            hint: '1',
                                            keyboard: TextInputType.number,
                                            inputFormatters: [
                                              FilteringTextInputFormatter
                                                  .digitsOnly,
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),
                              Container(
                                padding: const EdgeInsets.fromLTRB(
                                  14,
                                  14,
                                  14,
                                  10,
                                ),
                                decoration: BoxDecoration(
                                  color: _kFill10,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'ผู้หารรายการนี้',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: _kText70,
                                            fontFamily: _kFont,
                                          ),
                                        ),
                                        Text(
                                          '${selectedSharedMemberIds.length} คน',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: _kText50,
                                            fontFamily: _kFont,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    ..._memberDrafts.map((memberDraft) {
                                      final isSelected = selectedSharedMemberIds
                                          .contains(memberDraft.id);
                                      return GestureDetector(
                                        onTap: () => setDialogState(() {
                                          if (isSelected) {
                                            selectedSharedMemberIds.remove(
                                              memberDraft.id,
                                            );
                                          } else {
                                            selectedSharedMemberIds.add(
                                              memberDraft.id,
                                            );
                                          }
                                        }),
                                        child: Container(
                                          margin: const EdgeInsets.only(
                                            bottom: 8,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 12,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? _kBlue.withValues(alpha: 0.12)
                                                : Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            border: Border.all(
                                              color: isSelected
                                                  ? _kBlue
                                                  : Colors.transparent,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              _buildAvatar(
                                                memberDraft,
                                                radius: 15,
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  memberDraft.name,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w700,
                                                    color: _kText70,
                                                    fontFamily: _kFont,
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                width: 22,
                                                height: 22,
                                                decoration: BoxDecoration(
                                                  color: isSelected
                                                      ? _kBlue
                                                      : Colors.white,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: isSelected
                                                        ? _kBlue
                                                        : _kText20,
                                                  ),
                                                ),
                                                child: isSelected
                                                    ? const Icon(
                                                        AppIcons.check,
                                                        size: 12,
                                                        color: Colors.white,
                                                      )
                                                    : null,
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _kText70,
                                minimumSize: const Size.fromHeight(48),
                                side: BorderSide(
                                  color: _kBlue.withValues(alpha: 0.2),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                'ยกเลิก',
                                style: TextStyle(
                                  fontFamily: _kFont,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                final itemName = nameController.text.trim();
                                final itemAmount =
                                    double.tryParse(
                                      amountController.text.trim(),
                                    ) ??
                                    0;
                                final itemQuantity =
                                    int.tryParse(
                                      quantityController.text.trim(),
                                    ) ??
                                    0;
                                if (itemName.isEmpty) {
                                  _showSnackBar('กรุณากรอกชื่อ');
                                  return;
                                }
                                if (itemAmount <= 0) {
                                  _showSnackBar('กรุณากรอกราคา');
                                  return;
                                }
                                if (itemQuantity <= 0) {
                                  _showSnackBar('กรุณากรอกจำนวน');
                                  return;
                                }
                                if (selectedSharedMemberIds.isEmpty) {
                                  _showSnackBar('กรุณาเลือกผู้หาร');
                                  return;
                                }
                                Navigator.pop(
                                  ctx,
                                  _ItemDraft(
                                    id: initial.id,
                                    name: itemName,
                                    amount: itemAmount,
                                    quantity: itemQuantity,
                                    sharedIds: Set.from(
                                      selectedSharedMemberIds,
                                    ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _kBlue,
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                'บันทึก',
                                style: TextStyle(
                                  fontFamily: _kFont,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      nameController.dispose();
      amountController.dispose();
      quantityController.dispose();
    });
    return result;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: _kBlue,
      body: Column(
        children: [
          // status-bar safe space
          SizedBox(height: MediaQuery.of(context).viewPadding.top),

          // ── blue header ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildNav(),
                const SizedBox(height: 20),
                _buildModeTabs(),
                const SizedBox(height: 20),
                _buildAmountArea(),
                const SizedBox(height: 16),
                _buildPayerChip(),
                const SizedBox(height: 20),
              ],
            ),
          ),

          // ── white card ──────────────────────────────────────────────────
          Expanded(child: _buildWhiteCard()),
        ],
      ),
    );
  }

  // ── nav row ───────────────────────────────────────────────────────────────

  Widget _buildNav() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: _isSaving ? null : () => Navigator.pop(context),
          child: Text(
            'ยกเลิก',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
              fontFamily: _kFont,
            ),
          ),
        ),
        Text(
          _isEdit ? 'แก้ไขบิล' : 'สร้างบิลใหม่',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            fontFamily: _kFont,
          ),
        ),
        GestureDetector(
          onTap: _isSaving ? null : _save,
          child: Text(
            _isSaving ? 'กำลังบันทึก...' : 'เพิ่มเลย!',
            style: TextStyle(
              color: _isSaving
                  ? Colors.white.withValues(alpha: 0.5)
                  : Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              fontFamily: _kFont,
            ),
          ),
        ),
      ],
    );
  }

  // ── mode tabs ─────────────────────────────────────────────────────────────

  Widget _buildModeTabs() {
    return Container(
      height: 47,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        // 10% dark overlay on blue = slightly darker pill background
        color: _kFill10,
        borderRadius: BorderRadius.circular(50),
      ),
      child: Row(
        children: [
          Expanded(
            child: _modeTab(
              'หารเท่ากัน',
              _mode == _ComposerMode.equal,
              () => setState(() {
                _mode = _ComposerMode.equal;
                _syncPayerSelection();
              }),
            ),
          ),
          Expanded(
            child: _modeTab(
              'แยกรายการ',
              _mode == _ComposerMode.itemized,
              () => setState(() {
                _mode = _ComposerMode.itemized;
                _syncTotalAmount();
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeTab(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: active ? _kBlue : _kText70,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              fontFamily: _kFont,
            ),
          ),
        ),
      ),
    );
  }

  // ── amount area ───────────────────────────────────────────────────────────

  Widget _buildAmountArea() {
    final isReadOnly = _mode == _ComposerMode.itemized;
    return Column(
      children: [
        Text(
          'จ่ายไปเท่าไหร่นะ?',
          style: TextStyle(color: _kText50, fontSize: 12, fontFamily: _kFont),
        ),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 160, maxWidth: 210),
          child: Container(
            padding: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withValues(alpha: 0.45),
                  width: 1.5,
                ),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: TextField(
                    controller: _amountController,
                    readOnly: isReadOnly,
                    focusNode: _amountFocusNode,
                    textAlign: TextAlign.center,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}'),
                      ),
                    ],
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: _kText70,
                      fontFamily: _kFont,
                    ),
                    decoration: const InputDecoration.collapsed(
                      hintText: '0.00',
                      hintStyle: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: _kText50,
                        fontFamily: _kFont,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  '฿',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: _kText70,
                    fontFamily: _kFont,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isReadOnly) ...[
          const SizedBox(height: 6),
          Text(
            'ยอดรวมคำนวณจากรายการย่อย',
            style: TextStyle(color: _kText50, fontSize: 11, fontFamily: _kFont),
          ),
        ],
      ],
    );
  }

  // ── payer chip ────────────────────────────────────────────────────────────

  Widget _buildPayerChip() {
    final selectedPayers = _memberDrafts
        .where((memberDraft) => _selectedPayerIds.contains(memberDraft.id))
        .toList();
    final payerLabel = selectedPayers.isEmpty
        ? 'เลือกคนจ่าย'
        : selectedPayers.length == 1
        ? selectedPayers.first.name
        : '${selectedPayers.length} คนร่วมจ่าย';

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'จ่ายโดย: ',
              style: TextStyle(
                color: _kText50,
                fontSize: 12,
                fontFamily: _kFont,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _pickPayers,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 250),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildPayerAvatarStack(selectedPayers),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        payerLabel,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _kBlue,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          fontFamily: _kFont,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(AppIcons.chevronDown, size: 12, color: _kBlue),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (selectedPayers.length > 1) ...[
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: selectedPayers
                .map((memberDraft) => _buildPayerAmountChip(memberDraft))
                .toList(),
          ),
        ],
      ],
    );
  }

  // ── white card container ──────────────────────────────────────────────────

  Widget _buildWhiteCard() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(38)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(38)),
        child: _isInitializing
            ? const Center(child: CircularProgressIndicator(color: _kBlue))
            : _error != null
            ? _buildErrorState()
            : _memberDrafts.isEmpty
            ? _buildEmptyState()
            : _buildCardContent(),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(AppIcons.error, size: 32, color: Color(0xFFEF5350)),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: _kFont),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isInitializing = true;
                  _error = null;
                });
                _initializeScreen();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _kBlue,
                foregroundColor: Colors.white,
              ),
              child: const Text(
                'ลองใหม่',
                style: TextStyle(fontFamily: _kFont),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Text(
        'ไม่พบสมาชิกในกลุ่มนี้',
        style: TextStyle(color: _kText50, fontFamily: _kFont),
      ),
    );
  }

  Widget _buildCardContent() {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 3 category chips ─────────────────────────────────────────
          _buildCategoryRow(),
          const SizedBox(height: 28),

          // ── bill details section label ────────────────────────────────
          const Text(
            'รายละเอียดบิล',
            style: TextStyle(
              color: _kText70,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              fontFamily: _kFont,
            ),
          ),
          const SizedBox(height: 14),

          // ── bill name input ───────────────────────────────────────────
          _pillField(_descriptionController, 'กรอกชื่อบิล'),
          const SizedBox(height: 12),

          // ── date  +  attach photo ─────────────────────────────────────
          _buildDatePhotoRow(),
          const SizedBox(height: 28),

          // ── mode-specific content ─────────────────────────────────────
          if (_mode == _ComposerMode.equal)
            _buildEqualContent()
          else
            _buildItemizedContent(),
        ],
      ),
    );
  }

  // ── category chips ────────────────────────────────────────────────────────

  Widget _buildCategoryRow() {
    final cats = ExpenseCategory.values;
    return Row(
      children: cats.asMap().entries.map((entry) {
        final i = entry.key;
        final cat = entry.value;
        final selected = cat == _category;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < cats.length - 1 ? 10 : 0),
            child: GestureDetector(
              onTap: () => setState(() => _category = cat),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: selected
                      ? cat.color.withValues(alpha: 0.18)
                      : const Color(0xFFF7F8FA),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected ? cat.color : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: cat.color,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(cat.icon, size: 20, color: Colors.white),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      cat.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: selected ? const Color(0xFF141416) : _kText40,
                        fontFamily: _kFont,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── white-card pill text field ────────────────────────────────────────────

  Widget _pillField(
    TextEditingController ctrl,
    String hint, {
    TextInputType keyboard = TextInputType.text,
  }) {
    return SizedBox(
      height: 48,
      child: TextField(
        controller: ctrl,
        keyboardType: keyboard,
        style: const TextStyle(
          color: _kText70,
          fontSize: 16,
          fontFamily: _kFont,
        ),
        decoration: InputDecoration(
          filled: true,
          fillColor: _kFill10,
          hintText: hint,
          hintStyle: const TextStyle(
            color: _kText20,
            fontSize: 16,
            fontFamily: _kFont,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  // ── date + photo row ──────────────────────────────────────────────────────

  Widget _buildDatePhotoRow() {
    final d = _date;
    final dateStr =
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _pickDate,
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: const ShapeDecoration(
                color: _kFill10,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(30)),
                ),
              ),
              child: Row(
                children: [
                  const Icon(AppIcons.calendar, size: 16, color: _kText40),
                  const SizedBox(width: 10),
                  Text(
                    dateStr,
                    style: const TextStyle(
                      color: _kText70,
                      fontSize: 16,
                      fontFamily: _kFont,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 122,
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: const ShapeDecoration(
            color: _kFill10,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(30)),
            ),
          ),
          child: const Row(
            children: [
              Icon(AppIcons.imagePlus, size: 16, color: _kText40),
              SizedBox(width: 8),
              Text(
                'แนบรูป',
                style: TextStyle(
                  color: _kText20,
                  fontSize: 16,
                  fontFamily: _kFont,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  EQUAL MODE CONTENT
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildEqualContent() {
    final selectedMembers = _memberDrafts
        .where(
          (memberDraft) => _selectedSplitMemberIds.contains(memberDraft.id),
        )
        .toList();
    final filteredMembers = _filteredMemberDrafts;
    final allSelected =
        _selectedSplitMemberIds.length == _memberDrafts.length &&
        _memberDrafts.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // section header
        Text(
          'หารกับใครบ้าง? (${selectedMembers.length} คน)',
          style: const TextStyle(
            color: _kText70,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            fontFamily: _kFont,
          ),
        ),
        const SizedBox(height: 12),

        // selected member chips — horizontal scroll
        if (selectedMembers.isNotEmpty)
          SizedBox(
            height: 84,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: selectedMembers.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, index) =>
                  _buildAvatarChip(selectedMembers[index]),
            ),
          ),
        const SizedBox(height: 16),
        _buildMemberSearchBar(),
        const SizedBox(height: 16),

        // list header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _memberSearchQuery.trim().isEmpty
                  ? 'สมาชิก (${_memberDrafts.length} คน)'
                  : 'สมาชิกที่ค้นหา (${filteredMembers.length}/${_memberDrafts.length} คน)',
              style: const TextStyle(
                color: _kText70,
                fontSize: 14,
                fontFamily: _kFont,
              ),
            ),
            GestureDetector(
              onTap: () => setState(() {
                if (allSelected) {
                  _selectedSplitMemberIds.clear();
                } else {
                  _selectedSplitMemberIds = _memberDrafts
                      .map((memberDraft) => memberDraft.id)
                      .toSet();
                }
              }),
              child: Row(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: allSelected ? _kBlue : _kFill30,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: allSelected
                        ? const Icon(
                            AppIcons.check,
                            size: 10,
                            color: Colors.white,
                          )
                        : null,
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'เลือกทั้งหมด',
                    style: TextStyle(
                      color: _kText70,
                      fontSize: 12,
                      fontFamily: _kFont,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // friend rows
        if (filteredMembers.isEmpty)
          _buildEmptyMemberSearchState()
        else
          ...filteredMembers.map(_buildFriendRow),

        // split summary
        if (selectedMembers.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildSplitSummary(selectedMembers.length),
        ],
      ],
    );
  }

  Widget _buildMemberSearchBar() {
    return SizedBox(
      height: 48,
      child: TextField(
        controller: _memberSearchController,
        style: const TextStyle(
          color: _kText70,
          fontSize: 14,
          fontFamily: _kFont,
        ),
        decoration: InputDecoration(
          filled: true,
          fillColor: _kFill10,
          hintText: 'ค้นหาชื่อเพื่อนที่ต้องการเพิ่มเข้ากลุ่ม',
          hintStyle: const TextStyle(
            color: _kText20,
            fontSize: 14,
            fontFamily: _kFont,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
          prefixIcon: const Icon(AppIcons.search, size: 18, color: _kText40),
          prefixIconConstraints: const BoxConstraints(minWidth: 42),
          suffixIcon: _memberSearchQuery.isEmpty
              ? null
              : IconButton(
                  onPressed: () => _memberSearchController.clear(),
                  icon: const Icon(AppIcons.close, size: 16, color: _kText40),
                  splashRadius: 16,
                ),
          suffixIconConstraints: const BoxConstraints(minWidth: 34),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyMemberSearchState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
      decoration: BoxDecoration(
        color: _kFill10,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        children: [
          Icon(AppIcons.searchOff, color: _kText40, size: 22),
          SizedBox(height: 8),
          Text(
            'ไม่พบสมาชิกที่ค้นหา',
            style: TextStyle(color: _kText50, fontFamily: _kFont),
          ),
        ],
      ),
    );
  }

  // avatar chip — 48 px circle + blue check badge + name
  Widget _buildAvatarChip(_MemberDraft m) {
    return SizedBox(
      width: 56,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.bottomCenter,
            clipBehavior: Clip.none,
            children: [
              _buildAvatar(m, radius: 24),
              Positioned(
                bottom: -2,
                child: Container(
                  width: 18,
                  height: 18,
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: _kBlue,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    AppIcons.check,
                    size: 10,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            m.name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _kText70,
              fontSize: 11,
              fontFamily: _kFont,
            ),
          ),
        ],
      ),
    );
  }

  // friend row — 40 px avatar + name + Figma-style checkbox
  Widget _buildFriendRow(_MemberDraft m) {
    final checked = _selectedSplitMemberIds.contains(m.id);
    return GestureDetector(
      onTap: () => setState(() {
        if (checked) {
          _selectedSplitMemberIds.remove(m.id);
        } else {
          _selectedSplitMemberIds.add(m.id);
        }
      }),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            _buildAvatar(m, radius: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                m.name,
                style: const TextStyle(
                  color: _kText70,
                  fontSize: 14,
                  fontFamily: _kFont,
                ),
              ),
            ),
            // Figma: checked = blue rounded-square, unchecked = grey circle
            checked
                ? Container(
                    width: 20,
                    height: 20,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: _kBlue,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      AppIcons.check,
                      size: 12,
                      color: Colors.white,
                    ),
                  )
                : Container(
                    width: 20,
                    height: 20,
                    decoration: const ShapeDecoration(
                      color: _kFill10,
                      shape: OvalBorder(),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildSplitSummary(int count) {
    final amount = _enteredAmount;
    final each = count > 0 ? amount / count : 0.0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF6FD),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'หาร $count คน',
            style: const TextStyle(
              color: Color(0xFF1D4B64),
              fontSize: 13,
              fontFamily: _kFont,
            ),
          ),
          Text(
            'คนละ ${each.toStringAsFixed(2)} ฿',
            style: const TextStyle(
              color: _kBlue,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              fontFamily: _kFont,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayerAmountChip(_MemberDraft memberDraft) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildAvatar(memberDraft, radius: 9),
          const SizedBox(width: 6),
          Text(
            '${memberDraft.name} ${(_payerAmountsByMemberId[memberDraft.id] ?? 0).toStringAsFixed(2)} ฿',
            style: const TextStyle(
              color: _kBlue,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              fontFamily: _kFont,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayerAvatarStack(List<_MemberDraft> payers) {
    if (payers.isEmpty) {
      return CircleAvatar(radius: 10, backgroundColor: _kFill10);
    }
    if (payers.length == 1) {
      return _buildAvatar(payers.first, radius: 10);
    }

    final visiblePayers = payers.take(3).toList();
    return SizedBox(
      width: 18 + (visiblePayers.length * 12),
      height: 22,
      child: Stack(
        children: [
          for (final entry in visiblePayers.asMap().entries)
            Positioned(
              left: entry.key * 12,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: _buildAvatar(entry.value, radius: 10),
              ),
            ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  ITEMIZED MODE CONTENT
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildItemizedContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // header + add button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'รายการย่อย',
              style: TextStyle(
                color: _kText70,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                fontFamily: _kFont,
              ),
            ),
            GestureDetector(
              onTap: _addItemFlow,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF6FD),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(AppIcons.add, size: 14, color: _kBlue),
                    SizedBox(width: 4),
                    Text(
                      'เพิ่มรายการ',
                      style: TextStyle(
                        color: _kBlue,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        fontFamily: _kFont,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // empty state
        if (_itemDrafts.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32),
            decoration: BoxDecoration(
              color: _kFill10,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Column(
              children: [
                Icon(AppIcons.receipt, color: _kText40, size: 28),
                SizedBox(height: 8),
                Text(
                  'ยังไม่มีรายการย่อย',
                  style: TextStyle(color: _kText50, fontFamily: _kFont),
                ),
                SizedBox(height: 2),
                Text(
                  'กด "เพิ่มรายการ" เพื่อระบุว่าใครหารที่ไหนบ้าง',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: _kText40,
                    fontFamily: _kFont,
                  ),
                ),
              ],
            ),
          )
        else
          ..._itemDrafts.asMap().entries.map(
            (entry) => _buildItemCard(entry.key, entry.value),
          ),

        // total
        if (_itemDrafts.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF6FD),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'ยอดรวมรายการ',
                  style: TextStyle(
                    color: Color(0xFF1D4B64),
                    fontSize: 13,
                    fontFamily: _kFont,
                  ),
                ),
                Text(
                  '${_itemizedTotal.toStringAsFixed(2)} ฿',
                  style: const TextStyle(
                    color: _kBlue,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    fontFamily: _kFont,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildItemCard(int idx, _ItemDraft item) {
    final shared = _memberDrafts
        .where((m) => item.sharedIds.contains(m.id))
        .toList();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kFill10,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _kText70,
                        fontFamily: _kFont,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.amount.toStringAsFixed(2)} × ${item.quantity}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: _kText50,
                        fontFamily: _kFont,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${item.lineTotal.toStringAsFixed(2)} ฿',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: _kText70,
                  fontFamily: _kFont,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () async {
                  final updatedItem = await _detailDialog(initial: item);
                  if (updatedItem != null && mounted) {
                    setState(() {
                      _itemDrafts[idx] = updatedItem;
                      _syncTotalAmount();
                    });
                  }
                },
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(AppIcons.edit, size: 16, color: _kText40),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() {
                  _itemDrafts.removeAt(idx);
                  _syncTotalAmount();
                }),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    AppIcons.delete,
                    size: 16,
                    color: Color(0xFFEF5350),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: shared
                .map(
                  (m) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0x1A141416)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildAvatar(m, radius: 9),
                        const SizedBox(width: 5),
                        Text(
                          m.name,
                          style: const TextStyle(
                            fontSize: 11,
                            color: _kText70,
                            fontFamily: _kFont,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  // ── avatar helpers ────────────────────────────────────────────────────────

  Widget _buildAvatar(_MemberDraft? memberDraft, {required double radius}) {
    if (memberDraft == null) {
      return CircleAvatar(radius: radius, backgroundColor: _kFill10);
    }
    if (memberDraft.avatarUrl?.isNotEmpty ?? false) {
      return ClipOval(
        child: Image.network(
          memberDraft.avatarUrl!,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) =>
              _buildInitialAvatar(memberDraft, radius: radius),
        ),
      );
    }
    return _buildInitialAvatar(memberDraft, radius: radius);
  }

  Widget _buildInitialAvatar(
    _MemberDraft memberDraft, {
    required double radius,
  }) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: _kBlue.withValues(alpha: 0.2),
      child: Text(
        memberDraft.name.isNotEmpty ? memberDraft.name[0].toUpperCase() : '?',
        style: TextStyle(
          fontSize: radius * 0.75,
          fontWeight: FontWeight.w700,
          color: _kBlue,
          fontFamily: _kFont,
        ),
      ),
    );
  }

  // ── dialog field ──────────────────────────────────────────────────────────

  Widget _buildDialogHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: _kBlue.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: _kBlue, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _kText70,
                  fontFamily: _kFont,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: _kText50,
                  fontFamily: _kFont,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _dialogField(
    TextEditingController ctrl,
    String label, {
    String? hint,
    TextInputType keyboard = TextInputType.text,
    IconData? icon,
    String? suffixText,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: _kText50,
            fontWeight: FontWeight.w700,
            fontFamily: _kFont,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 52,
          child: TextField(
            controller: ctrl,
            keyboardType: keyboard,
            inputFormatters: inputFormatters,
            style: const TextStyle(
              fontSize: 15,
              color: _kText70,
              fontWeight: FontWeight.w700,
              fontFamily: _kFont,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              hintText: hint,
              hintStyle: const TextStyle(
                color: _kText20,
                fontSize: 15,
                fontFamily: _kFont,
              ),
              prefixIcon: icon == null
                  ? null
                  : Icon(icon, size: 18, color: _kText40),
              prefixIconConstraints: const BoxConstraints(minWidth: 42),
              suffixText: suffixText,
              suffixStyle: const TextStyle(
                color: _kText50,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                fontFamily: _kFont,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: _kBlue.withValues(alpha: 0.55)),
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Helper data classes
// ─────────────────────────────────────────────────────────────────────────────

class _MemberDraft {
  final String id;
  final String name;
  final String? avatarUrl;
  const _MemberDraft({required this.id, required this.name, this.avatarUrl});
}

class _ItemSeed {
  final String name;
  final double amount;
  final int quantity;
  const _ItemSeed({
    required this.name,
    required this.amount,
    required this.quantity,
  });
}

class _ItemDraft {
  final String? id;
  final String name;
  final double amount;
  final int quantity;
  final Set<String> sharedIds;
  double get lineTotal => amount * quantity;
  const _ItemDraft({
    this.id,
    required this.name,
    required this.amount,
    required this.quantity,
    required this.sharedIds,
  });
}
