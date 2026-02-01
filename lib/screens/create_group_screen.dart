import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nubbill/services/trip_service.dart';
import 'package:nubbill/providers/groups_provider.dart';
import 'package:nubbill/widgets/rounded_button.dart';
import 'package:intl/intl.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isLoading = false;

  // New Fields
  String _selectedCategory = 'other';
  DateTime? _startDate;
  DateTime? _endDate;
  final List<String> _selectedMemberIds =
      []; // TODO: Implement member selection with IDs

  final Map<String, dynamic> _categories = {
    'travel': {'label': 'ทริป', 'icon': '✈️'},
    'accommodation': {'label': 'ที่พัก', 'icon': '🏠'},
    'food': {'label': 'อาหาร', 'icon': '🍽️'},
    'romance': {'label': 'หวานใจ', 'icon': '❤️'},
    'other': {'label': 'อื่นๆ', 'icon': '📦'},
  };

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createGroup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final name = _nameController.text.trim();

      // Call backend API to create trip
      await ref
          .read(tripServiceProvider)
          .createTrip(
            name: name,
            category: _selectedCategory,
            startDate: _startDate,
            endDate: _endDate,
            memberIds: _selectedMemberIds.isNotEmpty
                ? _selectedMemberIds
                : null,
          );

      // Refresh groups list
      ref.invalidate(groupsProvider);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('สร้างกลุ่มสำเร็จ!')));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: const Color(0xFF81CEF2),
            colorScheme: const ColorScheme.light(primary: Color(0xFF81CEF2)),
            buttonTheme: const ButtonThemeData(
              textTheme: ButtonTextTheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('สร้างกลุ่มใหม่'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cover Image Placeholder
              GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('TODO: Implement Image Picker'),
                    ),
                  );
                },
                child: Container(
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(
                          Icons.camera_alt_outlined,
                          size: 40,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'อัพโหลดภาพปก (optional)',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'ชื่อกลุ่ม *',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'กรุณากรอกชื่อกลุ่ม';
                  }
                  return null;
                },
                decoration: InputDecoration(
                  hintText: 'เช่น ทริปเชียงใหม่, งานเลี้ยงรุ่น',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'หมวดหมู่',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categories.entries.map((entry) {
                  final isSelected = _selectedCategory == entry.key;
                  return ChoiceChip(
                    label: Text(
                      '${entry.value['icon']} ${entry.value['label']}',
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategory = entry.key;
                      });
                    },
                    selectedColor: const Color(
                      0xFF81CEF2,
                    ).withValues(alpha: 0.2),
                    backgroundColor: Colors.grey[100],
                    labelStyle: TextStyle(
                      color: isSelected
                          ? const Color(0xFF007bb5)
                          : Colors.black,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    side: isSelected
                        ? const BorderSide(color: Color(0xFF81CEF2))
                        : BorderSide.none,
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),

              Row(
                children: [
                  const Text(
                    'วันที่ (optional)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  if (_startDate != null)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _startDate = null;
                          _endDate = null;
                        });
                      },
                      child: const Text(
                        'ล้าง',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _pickDateRange(context),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.date_range, color: Colors.grey),
                      const SizedBox(height: 12),
                      Text(
                        _startDate == null
                            ? 'เลือกช่วงเวลา'
                            : '${DateFormat('d MMM y', 'th').format(_startDate!)} - ${DateFormat('d MMM y', 'th').format(_endDate!)}',
                        style: TextStyle(
                          color: _startDate == null
                              ? Colors.grey
                              : Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'เพิ่มสมาชิก',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              // Setup Member Selection Placeholder
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'ค้นหาเพื่อน...',
                        prefixIcon: Icon(Icons.search),
                        border: InputBorder.none,
                      ),
                      onChanged: (value) {
                        // TODO: Filter friends list
                      },
                    ),
                    const Divider(),
                    // Mock Members List (Selected/Unselected)
                    ListTile(
                      leading: const CircleAvatar(child: Text('C')),
                      title: const Text('Chin (คุณ)'),
                      subtitle: const Text('★ Admin'),
                      trailing: const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                      ),
                    ),
                    ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.orange,
                        child: Text('A'),
                      ),
                      title: const Text('เพื่อน A'),
                      trailing: Checkbox(
                        value: _selectedMemberIds.contains('A'),
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedMemberIds.add('A');
                            } else {
                              _selectedMemberIds.remove('A');
                            }
                          });
                        },
                        activeColor: const Color(0xFF81CEF2),
                      ),
                    ),
                    ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.purple,
                        child: Text('B'),
                      ),
                      title: const Text('เพื่อน B'),
                      trailing: Checkbox(
                        value: _selectedMemberIds.contains('B'),
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedMemberIds.add('B');
                            } else {
                              _selectedMemberIds.remove('B');
                            }
                          });
                        },
                        activeColor: const Color(0xFF81CEF2),
                      ),
                    ),

                    TextButton.icon(
                      onPressed: () {
                        // TODO: Open modal to add ghost member
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('TODO: Add Ghost Member Modal'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.person_add_alt),
                      label: const Text('เพิ่มคนที่ไม่มีแอป (Ghost Member)'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RoundedButton(
                      text: 'สร้างกลุ่ม',
                      backgroundColor: const Color(0xFF81CEF2),
                      textColor: Colors.white,
                      onPressed: _createGroup,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
