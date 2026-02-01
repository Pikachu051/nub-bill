import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nubbill/services/expense_service.dart';
import 'package:nubbill/services/trip_service.dart';
import 'package:nubbill/models/trip_member_model.dart';

class AddExpenseScreen extends ConsumerStatefulWidget {
  final String? tripId;
  final String? tripName;
  final List<TripMember>? members;

  const AddExpenseScreen({super.key, this.tripId, this.tripName, this.members});

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  String _selectedSplitType = 'equal'; // equal, exact, percent
  final _amountController = TextEditingController(text: '');
  final _descriptionController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  String? _payerMemberId;

  // Member selection state
  late List<Map<String, dynamic>> _memberState;

  @override
  void initState() {
    super.initState();
    _initializeMembers();
  }

  void _initializeMembers() {
    if (widget.members != null && widget.members!.isNotEmpty) {
      _memberState = widget.members!
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
            },
          )
          .toList();

      // Set first member as default payer
      _payerMemberId = widget.members!.first.id;
    } else {
      // Empty state - will show message to select trip
      _memberState = [];
    }
  }

  Future<void> _saveExpense() async {
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

    if (widget.tripId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรุณาเลือกกลุ่ม')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final expenseService = ref.read(expenseServiceProvider);

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

      // Prepare API call based on split type
      if (_selectedSplitType == 'equal') {
        await expenseService.createExpense(
          tripId: widget.tripId!,
          description: _descriptionController.text.trim(),
          amount: amount,
          splitType: 'equal',
          payerMemberId: _payerMemberId,
          expenseDate: _selectedDate,
          splitMemberIds: selectedMembers
              .map((m) => m['id'] as String)
              .toList(),
        );
      } else {
        // Exact or percent - build splits array
        final splits = selectedMembers.map((m) {
          return {
            'member_id': m['id'],
            'amount': _selectedSplitType == 'exact'
                ? m['amount'] as double
                : (amount * (m['percent'] as double) / 100),
          };
        }).toList();

        await expenseService.createExpense(
          tripId: widget.tripId!,
          description: _descriptionController.text.trim(),
          amount: amount,
          splitType: _selectedSplitType,
          payerMemberId: _payerMemberId,
          expenseDate: _selectedDate,
          splits: splits,
        );
      }

      // Refresh expenses list
      ref.invalidate(tripExpensesProvider(widget.tripId!));
      ref.invalidate(tripBalancesProvider(widget.tripId!));

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('เพิ่มบิลสำเร็จ!')));
        Navigator.pop(context);
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
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: _isLoading ? null : () => Navigator.pop(context),
                child: const Text(
                  'ยกเลิก',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              Text(
                widget.tripName != null
                    ? 'เพิ่มบิล - ${widget.tripName}'
                    : 'เพิ่มบิล',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: _isLoading ? null : _saveExpense,
                child: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'บันทึก',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
          const Divider(),
          Expanded(
            child: ListView(
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
                      prefixIcon: Icon(Icons.description),
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
                      prefixIcon: Icon(Icons.attach_money),
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
                        icon: const Icon(Icons.calendar_today, size: 16),
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
                          icon: const Icon(Icons.person, size: 16),
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
                if (_selectedSplitType == 'equal' && _memberState.isNotEmpty)
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
      return SizedBox(
        width: 100,
        child: TextField(
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
      return SizedBox(
        width: 80,
        child: TextField(
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
