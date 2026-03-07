import 'package:flutter/material.dart';
import 'package:nubbill/shared/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nubbill/models/expense_detail_model.dart';
import 'package:nubbill/services/expense_service.dart';
import 'package:nubbill/services/trip_service.dart';
import 'package:nubbill/models/trip_member_model.dart';

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

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  String _selectedSplitType = 'equal'; // equal, exact, percent
  bool _isMultiPayer = false;
  final _amountController = TextEditingController(text: '');
  final _descriptionController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  bool _isInitializing = true;
  String? _initializationError;
  String? _payerMemberId;

  // Member selection state
  List<Map<String, dynamic>> _memberState = [];
  bool get _isEditMode =>
      widget.isEdit && (widget.expenseId?.isNotEmpty ?? false);

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  Future<void> _initializeForm() async {
    try {
      List<TripMember> members = widget.members ?? const <TripMember>[];
      if (members.isEmpty &&
          widget.tripId != null &&
          widget.tripId!.isNotEmpty) {
        final detail = await ref
            .read(tripServiceProvider)
            .getTripDetail(widget.tripId!);
        members = detail?.members ?? const <TripMember>[];
      }

      _initializeMembers(members);

      if (_isEditMode) {
        final detail = await ref
            .read(expenseServiceProvider)
            .getExpenseDetail(widget.expenseId!);
        _applyExpenseDetail(detail);
      }
    } catch (e) {
      _initializationError = e.toString();
    } finally {
      if (mounted) {
        setState(() => _isInitializing = false);
      }
    }
  }

  void _initializeMembers(List<TripMember> members) {
    if (members.isNotEmpty) {
      _memberState = members
          .map(
            (m) => {
              'id': m.id,
              'name': m.displayName,
              'avatar': m.displayName.isNotEmpty
                  ? m.displayName[0].toUpperCase()
                  : '?',
              'avatarUrl': m.avatarUrl,
              'selected': true,
              'amount': 0.0,
              'percent': 0.0,
              'payerAmount': 0.0,
            },
          )
          .toList();

      // Set first member as default payer
      _payerMemberId = members.first.id;
    } else {
      // Empty state - will show message to select trip
      _memberState = [];
    }
  }

  void _applyExpenseDetail(ExpenseDetail detail) {
    _descriptionController.text = detail.description;
    _amountController.text = detail.amount.toStringAsFixed(2);
    _selectedDate = DateTime.tryParse(detail.expenseDate) ?? DateTime.now();
    _selectedSplitType = switch (detail.splitType) {
      'exact' => 'exact',
      'percent' => 'percent',
      _ => 'equal',
    };
    _payerMemberId = detail.payerId;

    for (final member in _memberState) {
      member['selected'] = false;
      member['amount'] = 0.0;
      member['percent'] = 0.0;
      member['payerAmount'] = 0.0;
    }

    for (final split in detail.splits) {
      Map<String, dynamic>? member;
      for (final candidate in _memberState) {
        if (candidate['id'] == split.memberId) {
          member = candidate;
          break;
        }
      }
      if (member == null) continue;

      member['selected'] = true;
      member['amount'] = split.amount;
      member['percent'] = detail.amount > 0
          ? (split.amount / detail.amount) * 100
          : 0.0;
    }

    if (detail.payers.isNotEmpty) {
      _isMultiPayer = true;
      for (final payer in detail.payers) {
        Map<String, dynamic>? member;
        for (final candidate in _memberState) {
          if (candidate['id'] == payer.memberId) {
            member = candidate;
            break;
          }
        }
        if (member != null) {
          member['payerAmount'] = payer.amount;
        }
      }
    } else {
      _isMultiPayer = false;
    }
  }

  Future<void> _saveExpense() async {
    if (_isInitializing) return;

    // Validate
    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรุณากรอกรายละเอียด')));
      return;
    }

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกจำนวนเงินที่ถูกต้อง')),
      );
      return;
    }

    if (widget.tripId == null || widget.tripId!.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรุณาเลือกกลุ่ม')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final expenseService = ref.read(expenseServiceProvider);
      final payers = _memberState
          .where((m) => ((m['payerAmount'] as num?)?.toDouble() ?? 0) > 0)
          .map(
            (m) => {
              'member_id': m['id'],
              'amount': ((m['payerAmount'] as num?)?.toDouble() ?? 0),
            },
          )
          .toList();

      // Get selected members for split
      final selectedMembers = _memberState
          .where((m) => m['selected'] == true)
          .toList();

      if (selectedMembers.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('กรุณาเลือกอย่างน้อยหนึ่งคน')),
        );
        setState(() => _isLoading = false);
        return;
      }

      if (_payerMemberId == null || _payerMemberId!.isEmpty) {
        if (_isMultiPayer && payers.isNotEmpty) {
          _payerMemberId = payers.first['member_id'] as String;
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('กรุณาเลือกคนจ่าย')));
          setState(() => _isLoading = false);
          return;
        }
      }

      if (_isMultiPayer) {
        if (payers.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('กรุณาระบุผู้จ่ายอย่างน้อย 1 คน')),
          );
          setState(() => _isLoading = false);
          return;
        }

        final payerSum = payers.fold<double>(
          0,
          (sum, payer) => sum + ((payer['amount'] as num?)?.toDouble() ?? 0),
        );
        if ((payerSum - amount).abs() > 0.01) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'ยอดรวมผู้จ่าย (${payerSum.toStringAsFixed(2)}) ต้องเท่ากับยอดบิล (${amount.toStringAsFixed(2)})',
              ),
            ),
          );
          setState(() => _isLoading = false);
          return;
        }
      }

      if (!_isMultiPayer &&
          (_payerMemberId == null || _payerMemberId!.isEmpty)) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('กรุณาเลือกคนจ่าย')));
        setState(() => _isLoading = false);
        return;
      }

      if (_selectedSplitType == 'exact') {
        final exactSum = selectedMembers.fold<double>(0, (sum, member) {
          final value = (member['amount'] as num?)?.toDouble() ?? 0;
          return sum + value;
        });
        if ((exactSum - amount).abs() > 0.01) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'ยอดรวมที่แบ่ง (${exactSum.toStringAsFixed(2)}) ต้องเท่ากับยอดบิล (${amount.toStringAsFixed(2)})',
              ),
            ),
          );
          setState(() => _isLoading = false);
          return;
        }
      }

      if (_selectedSplitType == 'percent') {
        final percentSum = selectedMembers.fold<double>(0, (sum, member) {
          final value = (member['percent'] as num?)?.toDouble() ?? 0;
          return sum + value;
        });
        if ((percentSum - 100).abs() > 0.05) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'เปอร์เซ็นต์รวมต้องเป็น 100% (ปัจจุบัน ${percentSum.toStringAsFixed(2)}%)',
              ),
            ),
          );
          setState(() => _isLoading = false);
          return;
        }
      }

      // Prepare API call based on split type
      final splitMemberIds = selectedMembers
          .map((m) => m['id'] as String)
          .toList();
      final splits = selectedMembers.map((m) {
        final exactAmount = (m['amount'] as num?)?.toDouble() ?? 0;
        final percent = (m['percent'] as num?)?.toDouble() ?? 0;
        return {
          'member_id': m['id'],
          'amount': _selectedSplitType == 'exact'
              ? exactAmount
              : percent, // keep legacy compatibility for percent-mode payloads
          if (_selectedSplitType == 'percent') 'percent': percent,
        };
      }).toList();

      if (_isEditMode) {
        await expenseService.updateExpense(
          widget.expenseId!,
          description: _descriptionController.text.trim(),
          amount: amount,
          splitType: _selectedSplitType,
          payerMemberId: _payerMemberId,
          expenseDate: _selectedDate,
          payers: _isMultiPayer ? payers : null,
          splitMemberIds: _selectedSplitType == 'equal' ? splitMemberIds : null,
          splits: _selectedSplitType == 'equal' ? null : splits,
        );
      } else if (_selectedSplitType == 'equal') {
        await expenseService.createExpense(
          tripId: widget.tripId!,
          description: _descriptionController.text.trim(),
          amount: amount,
          splitType: 'equal',
          payerMemberId: _payerMemberId,
          expenseDate: _selectedDate,
          payers: _isMultiPayer ? payers : null,
          splitMemberIds: splitMemberIds,
        );
      } else {
        await expenseService.createExpense(
          tripId: widget.tripId!,
          description: _descriptionController.text.trim(),
          amount: amount,
          splitType: _selectedSplitType,
          payerMemberId: _payerMemberId,
          expenseDate: _selectedDate,
          payers: _isMultiPayer ? payers : null,
          splits: splits,
        );
      }

      // Refresh expenses list
      ref.invalidate(tripExpensesProvider(widget.tripId!));
      ref.invalidate(tripBalancesProvider(widget.tripId!));
      ref.invalidate(tripDebtsProvider(widget.tripId!));
      if (widget.expenseId != null && widget.expenseId!.isNotEmpty) {
        ref.invalidate(expenseDetailProvider(widget.expenseId!));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditMode ? 'อัปเดตบิลสำเร็จ!' : 'เพิ่มบิลสำเร็จ!'),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(AppIcons.close, color: Colors.black),
          onPressed: _isLoading ? null : () => Navigator.pop(context),
        ),
        title: Text(
          _isEditMode ? 'แก้ไขบิล' : 'เพิ่มบิล',
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveExpense,
            child: const Text(
              'บันทึก',
              style: TextStyle(
                color: Color(0xFF81CEF2),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(color: Colors.white),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Divider(),
            if (_isInitializing)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_initializationError != null)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'ไม่สามารถโหลดข้อมูลบิลได้: $_initializationError',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [
                    // Description
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: TextField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'รายละเอียด *',
                          hintText: 'เช่น ค่าอาหารเที่ยง',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(AppIcons.description),
                        ),
                      ),
                    ),

                    // Amount
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: TextField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'ยอดเงิน *',
                          prefixText: '฿ ',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(AppIcons.money),
                        ),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ),

                    // Date & Payer
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickDate,
                            icon: const Icon(AppIcons.calendar, size: 16),
                            label: Text(
                              '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: PopupMenuButton<String>(
                            onSelected: (value) {
                              setState(() => _payerMemberId = value);
                            },
                            itemBuilder: (context) {
                              return _memberState.map((m) {
                                return PopupMenuItem<String>(
                                  value: m['id'],
                                  child: Text(m['name']),
                                );
                              }).toList();
                            },
                            child: OutlinedButton.icon(
                              onPressed: null,
                              icon: const Icon(AppIcons.person, size: 16),
                              label: Text(
                                _payerMemberId != null
                                    ? _memberState.firstWhere(
                                        (m) => m['id'] == _payerMemberId,
                                        orElse: () => {'name': 'เลือกคนจ่าย'},
                                      )['name']
                                    : 'คนจ่าย',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    SwitchListTile(
                      value: _isMultiPayer,
                      title: const Text('หลายคนจ่าย'),
                      subtitle: const Text('เปิดเพื่อระบุยอดที่แต่ละคนออกให้'),
                      onChanged: (value) {
                        setState(() {
                          _isMultiPayer = value;
                          if (!value) {
                            for (final member in _memberState) {
                              member['payerAmount'] = 0.0;
                            }
                          }
                        });
                      },
                      activeThumbColor: const Color(0xFF81CEF2),
                      contentPadding: EdgeInsets.zero,
                    ),

                    if (_isMultiPayer) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'ยอดที่แต่ละคนจ่าย',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ..._memberState.map((member) {
                        final payerAmount =
                            (member['payerAmount'] as num?)?.toDouble() ?? 0;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(member['name']),
                          trailing: SizedBox(
                            width: 120,
                            child: TextFormField(
                              key: ValueKey('payer-${member['id']}'),
                              initialValue: payerAmount > 0
                                  ? payerAmount.toStringAsFixed(2)
                                  : '',
                              decoration: const InputDecoration(
                                prefixText: '฿ ',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 0,
                                ),
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              onChanged: (val) {
                                setState(() {
                                  member['payerAmount'] =
                                      double.tryParse(val) ?? 0;
                                });
                              },
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                    ],

                    // Split Type Tabs
                    const Text(
                      'แบ่งจ่าย',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'equal', label: Text('หารเท่า')),
                        ButtonSegment(value: 'exact', label: Text('ระบุเอง')),
                        ButtonSegment(value: 'percent', label: Text('%')),
                      ],
                      selected: {_selectedSplitType},
                      onSelectionChanged: (newSelection) {
                        setState(() {
                          _selectedSplitType = newSelection.first;
                        });
                      },
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),

                    // Members List
                    const SizedBox(height: 16),
                    if (_memberState.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'ไม่พบสมาชิกในกลุ่ม',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    else
                      ..._memberState.map((member) {
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: const Color(
                              0xFF81CEF2,
                            ).withValues(alpha: 0.2),
                            backgroundImage: member['avatarUrl'] != null
                                ? NetworkImage(member['avatarUrl'])
                                : null,
                            child: member['avatarUrl'] == null
                                ? Text(member['avatar'])
                                : null,
                          ),
                          title: Text(member['name']),
                          trailing: _buildSplitInput(member),
                        );
                      }),

                    // Summary
                    if (_selectedSplitType == 'equal' &&
                        _memberState.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Builder(
                          builder: (context) {
                            final selectedCount = _memberState
                                .where((m) => m['selected'] == true)
                                .length;
                            final amount =
                                double.tryParse(_amountController.text) ?? 0;
                            final perPerson = selectedCount > 0
                                ? amount / selectedCount
                                : 0;
                            return Text(
                              'คนละ: ฿${perPerson.toStringAsFixed(2)} ($selectedCount คน)',
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSplitInput(Map<String, dynamic> member) {
    if (_selectedSplitType == 'equal') {
      return Checkbox(
        value: member['selected'] as bool,
        onChanged: (val) {
          setState(() => member['selected'] = val ?? false);
        },
        activeColor: const Color(0xFF81CEF2),
      );
    } else if (_selectedSplitType == 'exact') {
      final exactAmount = (member['amount'] as num?)?.toDouble() ?? 0;
      return SizedBox(
        width: 100,
        child: TextFormField(
          key: ValueKey('exact-${member['id']}'),
          initialValue: exactAmount > 0 ? exactAmount.toStringAsFixed(2) : '',
          decoration: const InputDecoration(
            prefixText: '฿ ',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
          ),
          keyboardType: TextInputType.number,
          onChanged: (val) {
            setState(() {
              member['amount'] = double.tryParse(val) ?? 0;
              member['selected'] = (member['amount'] as double) > 0;
            });
          },
        ),
      );
    } else {
      final percent = (member['percent'] as num?)?.toDouble() ?? 0;
      return SizedBox(
        width: 80,
        child: TextFormField(
          key: ValueKey('percent-${member['id']}'),
          initialValue: percent > 0 ? percent.toStringAsFixed(2) : '',
          decoration: const InputDecoration(
            suffixText: '%',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
          ),
          keyboardType: TextInputType.number,
          onChanged: (val) {
            setState(() {
              member['percent'] = double.tryParse(val) ?? 0;
              member['selected'] = (member['percent'] as double) > 0;
            });
          },
        ),
      );
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
