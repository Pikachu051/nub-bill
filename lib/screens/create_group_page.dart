import 'package:flutter/material.dart';
import 'package:nubbill/screens/group_detail_page.dart';
import 'package:nubbill/models/friend.dart';
import 'package:nubbill/models/trip_category.dart';

class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double borderRadius;
  final double dashWidth;
  final double dashSpace;

  DashedBorderPainter({
    required this.color,
    this.strokeWidth = 2,
    this.borderRadius = 16,
    this.dashWidth = 6,
    this.dashSpace = 4,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path();
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(borderRadius),
    );
    path.addRRect(rect);

    // Create dashed path
    final dashedPath = Path();
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final end = distance + dashWidth;
        dashedPath.addPath(
          metric.extractPath(distance, end.clamp(0, metric.length)),
          Offset.zero,
        );
        distance += dashWidth + dashSpace;
      }
    }

    canvas.drawPath(dashedPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CreateGroupPage extends StatefulWidget {
  const CreateGroupPage({super.key});

  @override
  State<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  static const Color primaryColor = Color.fromARGB(255, 129, 206, 242);
  static const Color backgroundColor = Color(0xFFF5F5F5);
  static const Color cardBackground = Colors.white;

  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  String? _selectedCategoryId;
  String _searchQuery = '';

  // Trip categories based on prototype
  final List<TripCategory> _categories = const [
    TripCategory(
      id: 'trip',
      name: 'ออกทริป',
      icon: Icons.airplanemode_on,
      backgroundColor: Color(0xFFF1F8E9), // Light Green
      mainColor: Color(0xFF7CB342), // Green
    ),
    TripCategory(
      id: 'accommodation',
      name: 'ที่พัก',
      icon: Icons.home,
      backgroundColor: Color(0xFFE3F2FD), // Light Blue
      mainColor: Color(0xFF64B5F6), // Blue
    ),
    TripCategory(
      id: 'couple',
      name: 'หวานใจ',
      icon: Icons.favorite_border,
      backgroundColor: Color(0xFFFCE4EC), // Light Pink
      mainColor: Color(0xFFF06292), // Pink
    ),
    TripCategory(
      id: 'food',
      name: 'มื้ออาหาร',
      icon: Icons.restaurant,
      backgroundColor: Color(0xFFFFF3E0), // Light Orange
      mainColor: Color(0xFFFFB74D), // Orange
    ),
  ];

  // Mock friends data
  final List<Friend> _friends = [
    Friend(id: '1', name: 'กระต่าย'),
    Friend(id: '2', name: 'เบ๋เบา'),
    Friend(id: '3', name: 'กระต่าย'),
    Friend(id: '4', name: 'ออร่า'),
    Friend(id: '5', name: 'บุ๋'),
    Friend(id: '6', name: 'อาหยู'),
    Friend(id: '7', name: 'การ์ตูน'),
  ];

  List<Friend> get _selectedFriends =>
      _friends.where((f) => f.isSelected).toList();

  List<Friend> get _filteredFriends {
    if (_searchQuery.isEmpty) return _friends;
    return _friends
        .where((f) => f.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onCategorySelected(String categoryId) {
    setState(() {
      _selectedCategoryId = categoryId;
    });
  }

  void _toggleFriendSelection(Friend friend) {
    setState(() {
      friend.isSelected = !friend.isSelected;
    });
  }

  void _onStartTrip() {
    // Validate group name
    if (_groupNameController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรุณากรอกชื่อกลุ่ม')));
      return;
    }
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรุณาเลือกประเภทกลุ่ม')));
      return;
    }

    // Create group and navigate to group detail page
    // TODO: Implement actual group creation logic with backend
    final groupName = _groupNameController.text;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => GroupDetailPage(
          groupId: 'new_group_id', // TODO: Use actual group ID from backend
          groupName: groupName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cardBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Top padding
            const SizedBox(height: 8),

            // Header
            _buildHeader(),

            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),

                    // Group name input with gradient background
                    _buildGroupNameSection(),

                    const SizedBox(height: 24),

                    // Category selection
                    _buildCategorySection(),

                    const SizedBox(height: 24),

                    // Selected members
                    _buildSelectedMembersSection(),

                    const SizedBox(height: 16),

                    // Search bar
                    _buildSearchBar(),

                    const SizedBox(height: 16),

                    // Friends list
                    _buildFriendsList(),
                  ],
                ),
              ),
            ),
          ],
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
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Text(
              'ยกเลิก',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ),
          const Text(
            'เริ่มกลุ่มหารใหม่',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          GestureDetector(
            onTap: _onStartTrip,
            child: const Text(
              'เริ่มทริป!',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupNameSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Group image placeholder
          Container(
            width: 70, // Increased size
            height: 70,
            decoration: BoxDecoration(
              image: const DecorationImage(
                image: AssetImage('assets/images/cover_placeholder.jpg'),
                fit: BoxFit.cover,
              ),
              color: Colors.grey[200], // Fallback color
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.camera_alt_outlined, // Changed icon
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          // Group name input
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 8), // Align slightly with image top
                Text(
                  'กรอกชื่อกลุ่ม',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.normal,
                  ),
                ),
                TextField(
                  controller: _groupNameController,
                  decoration: InputDecoration(
                    hintText: 'ทริปเชียงใหม่',
                    hintStyle: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 16,
                      fontWeight: FontWeight.normal,
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: primaryColor),
                    ),
                  ),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.normal,
                    color: Colors.black87,
                  ),
                ),
              ],
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
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _categories.map((category) {
              final isSelected = _selectedCategoryId == category.id;
              return _buildCategoryItem(category, isSelected);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryItem(TripCategory category, bool isSelected) {
    return GestureDetector(
      onTap: () => _onCategorySelected(category.id),
      child: Column(
        children: [
          CustomPaint(
            painter: isSelected
                ? DashedBorderPainter(
                    color: category.mainColor,
                    strokeWidth: 2,
                    borderRadius: 20,
                  )
                : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 72,
              height: 72,
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: category.backgroundColor,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                category.icon,
                color: isSelected ? category.mainColor : Colors.grey[400],
                size: 32,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            category.name,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.black : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedMembersSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ชวนใครเข้ากลุ่มบ้าง? (${_selectedFriends.length} คน)',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          if (_selectedFriends.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _selectedFriends.length,
                itemBuilder: (context, index) {
                  final friend = _selectedFriends[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: primaryColor.withValues(
                                alpha: 0.2,
                              ),
                              child: Text(
                                friend.name[0],
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                            ),
                            Positioned(
                              right: 0,
                              top: 0,
                              child: GestureDetector(
                                onTap: () => _toggleFriendSelection(friend),
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: const BoxDecoration(
                                    color: primaryColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(friend.name, style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        decoration: InputDecoration(
          hintText: 'ค้นหาชื่อเพื่อนที่ต้องการเพิ่มเข้ากลุ่ม',
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
          prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
          filled: true,
          fillColor: backgroundColor,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 12,
            horizontal: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: primaryColor, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildFriendsList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'เพื่อน (${_friends.length} คน)',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '(เลือกแล้ว ${_selectedFriends.length}/50)',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _filteredFriends.length,
            itemBuilder: (context, index) {
              final friend = _filteredFriends[index];
              return _buildFriendItem(friend);
            },
          ),
          const SizedBox(height: 24), // Bottom padding
        ],
      ),
    );
  }

  Widget _buildFriendItem(Friend friend) {
    return InkWell(
      onTap: () => _toggleFriendSelection(friend),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: primaryColor.withValues(alpha: 0.2),
              child: Text(
                friend.name[0],
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(friend.name, style: const TextStyle(fontSize: 16)),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: friend.isSelected ? primaryColor : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: friend.isSelected ? primaryColor : Colors.grey[300]!,
                  width: 2,
                ),
              ),
              child: friend.isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 18)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
