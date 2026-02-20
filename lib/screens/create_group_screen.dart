import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nubbill/models/trip_member_model.dart';
import 'package:nubbill/models/trip_model.dart';
import 'package:nubbill/services/auth_repository.dart';
import 'package:nubbill/services/trip_service.dart';
import 'package:nubbill/services/friend_service.dart';
import 'package:nubbill/providers/groups_provider.dart';
import 'package:nubbill/screens/home_page.dart';
import 'package:nubbill/widgets/retry_error_state.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  final Trip? initialTrip;
  final List<TripMember>? initialMembers;

  const CreateGroupScreen({super.key, this.initialTrip, this.initialMembers});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _searchController = TextEditingController();
  bool _isLoading = false;
  File? _coverImage;
  String? _initialCoverUrl;

  String _selectedCategory = 'travel';
  final List<String> _selectedMemberIds = [];

  DateTime? _startDate;
  DateTime? _endDate;

  // Category data matching the reference design exactly
  final List<Map<String, dynamic>> _categories = [
    {
      'key': 'travel',
      'label': 'ออกทริป',
      'icon': Icons.flight,
      'color': const Color(0xFFF1F8E9), // Light green
      'iconColor': const Color(0xFFAED581),
    },
    {
      'key': 'accommodation',
      'label': 'ที่พัก',
      'icon': Icons.home,
      'color': const Color(0xFFE3F2FD), // Light blue
      'iconColor': const Color(0xFF90CAF9),
    },
    {
      'key': 'romance',
      'label': 'หวานใจ',
      'icon': Icons.favorite,
      'color': const Color(0xFFFCE4EC), // Light pink
      'iconColor': const Color(0xFFF48FB1),
    },
    {
      'key': 'food',
      'label': 'มื้ออาหาร',
      'icon': Icons.restaurant,
      'color': const Color(0xFFFFFDE7), // Light yellow
      'iconColor': const Color(0xFFFFCC80),
    },
  ];

  bool get _isEditMode => widget.initialTrip != null;

  @override
  void initState() {
    super.initState();

    final initialTrip = widget.initialTrip;
    if (initialTrip != null) {
      _nameController.text = initialTrip.name;
      _selectedCategory = initialTrip.category.name;
      _startDate = initialTrip.startDate;
      _endDate = initialTrip.endDate;
      _initialCoverUrl = initialTrip.coverUrl;

      final currentUserId = ref.read(authUserIdProvider);
      final selectedIds =
          widget.initialMembers
              ?.where((m) => m.userId != null && m.userId != currentUserId)
              .map((m) => m.userId!)
              .toSet() ??
          <String>{};
      _selectedMemberIds.addAll(selectedIds);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickCoverImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (pickedFile != null) {
      setState(() {
        _coverImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _submitGroup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final name = _nameController.text.trim();
      final tripService = ref.read(tripServiceProvider);

      // Normalize date range if both selected
      DateTime? startDate = _startDate;
      DateTime? endDate = _endDate;
      if (startDate != null && endDate != null && endDate.isBefore(startDate)) {
        final tmp = startDate;
        startDate = endDate;
        endDate = tmp;
      }
      final tripId = widget.initialTrip?.id;

      if (_isEditMode && tripId != null) {
        await tripService.updateTrip(
          tripId,
          name: name,
          category: _selectedCategory,
          startDate: startDate,
          endDate: endDate,
        );

        // Sync member changes when editing.
        final currentUserId = ref.read(authUserIdProvider);
        final existingMemberByUserId = <String, String>{};
        for (final member in widget.initialMembers ?? const <TripMember>[]) {
          if (member.userId != null && member.userId != currentUserId) {
            existingMemberByUserId[member.userId!] = member.id;
          }
        }

        final selectedIds = _selectedMemberIds.toSet();
        final existingIds = existingMemberByUserId.keys.toSet();

        final toAdd = selectedIds.difference(existingIds);
        final toRemove = existingIds.difference(selectedIds);

        if (toAdd.isNotEmpty) {
          await tripService.addMembers(tripId, userIds: toAdd.toList());
        }

        for (final userId in toRemove) {
          final memberId = existingMemberByUserId[userId];
          if (memberId != null) {
            await tripService.removeMember(tripId, memberId);
          }
        }
      } else {
        // Create trip first
        final trip = await tripService.createTrip(
          name: name,
          category: _selectedCategory,
          startDate: startDate,
          endDate: endDate,
          memberIds: _selectedMemberIds.isNotEmpty ? _selectedMemberIds : null,
        );

        // Upload cover image if selected
        if (_coverImage != null) {
          try {
            final bytes = await _coverImage!.readAsBytes();
            await tripService.uploadCover(trip.id, bytes);
          } catch (e) {
            // Cover upload failed but trip was created successfully
            debugPrint('Cover upload failed: $e');
          }
        }
      }

      // Upload new cover image if selected in edit mode
      if (_isEditMode && tripId != null && _coverImage != null) {
        try {
          final bytes = await _coverImage!.readAsBytes();
          await tripService.uploadCover(tripId, bytes);
        } catch (e) {
          debugPrint('Cover upload failed: $e');
        }
      }

      // Refresh home page data so the new group appears immediately
      ref.invalidate(groupsProvider);
      ref.invalidate(userTripsProvider);
      if (tripId != null) {
        ref.invalidate(tripDetailProvider(tripId));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditMode ? 'อัปเดตกลุ่มสำเร็จ!' : 'สร้างกลุ่มสำเร็จ!',
            ),
          ),
        );
        context.pop(true);
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

  @override
  Widget build(BuildContext context) {
    // Fetch friends from the provider
    final friendsAsync = ref.watch(friendsProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Custom Header
              _buildHeader(),

              // Scrollable Content
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Group Name Section with Photo
                      _buildGroupNameSection(),

                      const SizedBox(height: 24),

                      // Date Range Section
                      _buildDateSection(),

                      const SizedBox(height: 24),

                      // Category Section
                      _buildCategorySection(),

                      const SizedBox(height: 24),

                      // Selected Friends Preview
                      _buildSelectedFriendsPreview(friendsAsync),

                      const SizedBox(height: 16),

                      // Search Bar
                      _buildSearchBar(),

                      const SizedBox(height: 16),

                      // Friends List
                      _buildFriendsList(friendsAsync),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Cancel Button
          GestureDetector(
            onTap: () => context.pop(),
            child: const Text(
              'ยกเลิก',
              style: TextStyle(fontSize: 16, color: Color(0xFFBDBDBD)),
            ),
          ),

          // Title
          Text(
            _isEditMode ? 'แก้ไขกลุ่ม' : 'เริ่มกลุ่มหารใหม่',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF4A4A4A)),
          ),

          // Start Trip Button
          GestureDetector(
            onTap: _isLoading ? null : _submitGroup,
            child: Text(
              _isEditMode ? 'บันทึก' : 'เริ่มทริป!',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _isLoading ? Colors.grey : const Color(0xFF81CEF2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupNameSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Photo Picker
          GestureDetector(
            onTap: _pickCoverImage,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300, width: 1),
                image: _coverImage != null
                    ? DecorationImage(
                        image: FileImage(_coverImage!),
                        fit: BoxFit.cover,
                      )
                    : _initialCoverUrl != null
                    ? DecorationImage(
                        image: NetworkImage(_initialCoverUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: _coverImage == null && _initialCoverUrl == null
                  ? const Icon(
                      Icons.camera_alt_outlined,
                      size: 32,
                      color: Colors.grey,
                    )
                  : null,
            ),
          ),

          const SizedBox(width: 16),

          // Name Input
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'กรอกชื่อกลุ่ม',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 0),
                TextFormField(
                  controller: _nameController,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'กรุณากรอกชื่อกลุ่ม';
                    }
                    return null;
                  },
                  decoration: const InputDecoration(
                    hintText: 'ทริปเชียงใหม่',
                    hintStyle: TextStyle(
                      color: Colors.black54,
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                    filled: false,
                    border: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey),
                    ),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey, width: 2),
                    ),
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                  style: const TextStyle(
                    fontSize: 18,
                    color: Color(0xFF4A4A4A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildDateSection() {
    String formatDate(DateTime date) {
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = (date.year + 543).toString(); // Thai Buddhist year
      return '$day/$month/$year';
    }

    final hasBoth = _startDate != null && _endDate != null;
    final hasStartOnly = _startDate != null && _endDate == null;
    final hasEndOnly = _startDate == null && _endDate != null;

    String rangeLabel;
    if (hasBoth) {
      rangeLabel = '${formatDate(_startDate!)} - ${formatDate(_endDate!)}';
    } else if (hasStartOnly) {
      rangeLabel = formatDate(_startDate!);
    } else if (hasEndOnly) {
      rangeLabel = formatDate(_endDate!);
    } else {
      rangeLabel = 'เลือกวันที่เดินทาง';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ช่วงเวลาเดินทาง',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () async {
              final now = DateTime.now();
              final initialStart = _startDate ?? now;
              final initialEnd = _endDate ?? now.add(const Duration(days: 2));

              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(now.year - 1),
                lastDate: DateTime(now.year + 3),
                initialDateRange: DateTimeRange(
                  start: initialStart,
                  end: initialEnd,
                ),
              );

              if (picked != null) {
                setState(() {
                  _startDate = picked.start;
                  _endDate = picked.end;
                });
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                   const Icon(
                    Icons.calendar_today,
                    size: 18,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      rangeLabel,
                      style: TextStyle(
                        fontSize: 14,
                        color: (hasBoth || hasStartOnly || hasEndOnly)
                            ? Colors.black87
                            : Colors.grey,
                        fontWeight: (hasBoth || hasStartOnly || hasEndOnly)
                            ? FontWeight.w500
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ประเภทกลุ่ม',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _categories.map((category) {
              final isSelected = _selectedCategory == category['key'];
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedCategory = category['key'] as String;
                  });
                },
                child: Column(
                  children: [
                    // Rounded square with dashed border when selected
                    CustomPaint(
                      painter: isSelected
                          ? DashedBorderPainter(
                              color: category['iconColor'] as Color,
                              strokeWidth: 3,
                              gap: 4,
                              borderRadius: 16,
                            )
                          : null,
                      child: Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          color: category['color'] as Color,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              category['icon'] as IconData,
                              color: category['iconColor'] as Color,
                              size: 24,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              category['label'] as String,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w400,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedFriendsPreview(AsyncValue<List<Friend>> friendsAsync) {
    // Get selected friends from the actual friends list
    final selectedFriends = friendsAsync.maybeWhen(
      data: (friends) =>
          friends.where((f) => _selectedMemberIds.contains(f.id)).toList(),
      orElse: () => <Friend>[],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ชวนใครเข้ากลุ่มบ้าง? (${selectedFriends.length} คน)',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          if (selectedFriends.isEmpty)
            const Text(
              'ยังไม่ได้เลือกเพื่อน',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            )
          else
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: selectedFriends.length,
                separatorBuilder: (context, index) => const SizedBox(width: 16),
                itemBuilder: (context, index) {
                  final friend = selectedFriends[index];
                  return Column(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.grey[200],
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: ClipOval(
                              child: friend.avatarUrl != null
                                  ? Image.network(
                                      friend.avatarUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) =>
                                          Center(
                                            child: Text(
                                              friend.nickname[0],
                                              style: const TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                    )
                                  : Center(
                                      child: Text(
                                        friend.nickname[0],
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedMemberIds.remove(friend.id);
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF81CEF2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        friend.nickname,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, color: Colors.grey, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'ค้นหาชื่อเพื่อนที่ต้องการเพิ่มเข้ากลุ่ม',
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                style: const TextStyle(fontSize: 14),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendsList(AsyncValue<List<Friend>> friendsAsync) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: friendsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => RetryErrorState(
          error: error,
          onRetry: () => ref.invalidate(friendsProvider),
        ),
        data: (friends) {
          // Filter by search query
          final searchQuery = _searchController.text.toLowerCase();
          final filteredFriends = searchQuery.isEmpty
              ? friends
              : friends
                    .where(
                      (f) => f.nickname.toLowerCase().contains(searchQuery),
                    )
                    .toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'เพื่อน (${filteredFriends.length} คน)',
                    style: const TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                  Text(
                    '(เลือกแล้ว ${_selectedMemberIds.length}/50)',
                    style: const TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (filteredFriends.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'ไม่พบเพื่อน',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              else
                // Friends List
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredFriends.length,
                  itemBuilder: (context, index) {
                    final friend = filteredFriends[index];
                    final isSelected = _selectedMemberIds.contains(friend.id);

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey[200],
                        ),
                        child: ClipOval(
                          child: friend.avatarUrl != null
                              ? Image.network(
                                  friend.avatarUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Center(
                                        child: Text(
                                          friend.nickname[0],
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                )
                              : Center(
                                  child: Text(
                                    friend.nickname[0],
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      title: Text(
                        friend.nickname,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      trailing: GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedMemberIds.remove(friend.id);
                            } else {
                              _selectedMemberIds.add(friend.id);
                            }
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? const Color(0xFF81CEF2)
                                : Colors.transparent,
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF81CEF2)
                                  : Colors.grey.shade300,
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 18,
                                )
                              : null,
                        ),
                      ),
                    );
                  },
                ),

              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }
}

/// Custom painter for dashed border on rounded rectangle
class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;
  final double borderRadius;

  DashedBorderPainter({
    required this.color,
    this.strokeWidth = 2,
    this.gap = 4,
    this.borderRadius = 16,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(borderRadius),
    );

    final path = Path()..addRRect(rrect);
    final pathMetrics = path.computeMetrics();

    for (final metric in pathMetrics) {
      double distance = 0;
      bool draw = true;
      while (distance < metric.length) {
        final length = draw ? gap * 2 : gap;
        final double end = (distance + length).clamp(0.0, metric.length);
        if (draw) {
          final extractPath = metric.extractPath(distance, end);
          canvas.drawPath(extractPath, paint);
        }
        distance = end;
        draw = !draw;
      }
    }
  }

  @override
  bool shouldRepaint(covariant DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.gap != gap ||
        oldDelegate.borderRadius != borderRadius;
  }
}
