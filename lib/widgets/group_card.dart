import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nubbill/models/trip_model.dart';

class GroupCard extends StatelessWidget {
  final Trip group;

  const GroupCard({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    // Determine balance color
    final balanceColor = group.balance > 0
        ? Colors.green
        : (group.balance < 0 ? Colors.red : Colors.grey);

    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: () {
          // Navigate to Group Detail with trip ID
          context.push('/groups/detail', extra: group.id);
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Category icon or cover image
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFF81CEF2).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  image: group.coverUrl != null
                      ? DecorationImage(
                          image: NetworkImage(group.coverUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: group.coverUrl == null
                    ? Icon(group.category.icon, color: const Color(0xFF81CEF2))
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          group.category.emoji,
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            group.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.people, size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          '${group.memberCount} คน',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        if (group.startDate != null) ...[
                          const SizedBox(width: 12),
                          Icon(
                            Icons.calendar_today,
                            size: 12,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${group.startDate!.day}/${group.startDate!.month}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Balance indicator
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (group.balance != 0)
                    Text(
                      group.balance > 0
                          ? '+฿${group.balance.abs().toStringAsFixed(0)}'
                          : '-฿${group.balance.abs().toStringAsFixed(0)}',
                      style: TextStyle(
                        color: balanceColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    )
                  else
                    Text(
                      'เคลียร์',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
