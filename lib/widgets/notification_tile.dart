import 'package:flutter/material.dart';

import 'package:nubbill/models/notification_model.dart';

class NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;

  const NotificationTile({
    required this.notification,
    this.onTap,
    this.onDismiss,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.isRead;
    final visualStyle = _visualStyleFor(notification);
    final tripLabel = _tripLabel(notification);
    final amountOrStatus = _amountOrStatus(notification);
    final rowBackground = isUnread ? const Color(0xFFF0F9FF) : Colors.white;

    return Dismissible(
      key: ValueKey(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => onDismiss?.call(),
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          color: rowBackground,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _Avatar(notification: notification, style: visualStyle),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RichText(
                      text: _buildStyledHeadlineSpan(notification),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textScaler: TextScaler.noScaling,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _subtitleText(notification),
                      style: const TextStyle(
                        fontFamily: 'LINESeedSansTH',
                        color: Color(0x66141416),
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    if (tripLabel != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x3381CEF2),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Text(
                          tripLabel,
                          style: const TextStyle(
                            fontFamily: 'LINESeedSansTH',
                            color: Color(0xFF81CEF2),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _TrailingMeta(
                notification: notification,
                isUnread: isUnread,
                amountOrStatus: amountOrStatus,
                amountColor: visualStyle.amountColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _headlineText(AppNotification notification) {
    final expenseLabel = _expenseLabel(notification);
    final tripName = _tripLabel(notification);

    return switch (notification.type) {
      NotificationType.expenseCreated => 'เพิ่มบิล "$expenseLabel"',
      NotificationType.expenseUpdated => 'แก้ไขบิล "$expenseLabel"',
      NotificationType.expenseDeleted => 'ลบบิล "$expenseLabel"',
      NotificationType.tripInvited || NotificationType.tripJoined =>
        tripName != null ? 'เข้าร่วมกลุ่ม "$tripName"' : notification.title,
      NotificationType.manualDebtorReminder =>
        expenseLabel.isNotEmpty ? 'สะกิดเตือนยอด "$expenseLabel"' : 'สะกิดเตือนยอด',
      _ => notification.title,
    };
  }

  TextSpan _buildStyledHeadlineSpan(AppNotification notification) {
    final headline = _headlineText(notification);

    final baseStyle = const TextStyle(
      fontFamily: 'LINESeedSansTH',
      fontWeight: FontWeight.w400,
      fontSize: 14,
      color: Color(0xB2141416),
    );

    final emphasisStyle = baseStyle.copyWith(fontWeight: FontWeight.w700);
    final shouldEmphasize = List<bool>.filled(headline.length, false);

    // 1) Bill names in quotes ("...") or Thai quote style ("…").
    final quotedPattern = RegExp(r'"[^"]+"|“[^”]+”');
    for (final match in quotedPattern.allMatches(headline)) {
      for (var index = match.start; index < match.end; index++) {
        shouldEmphasize[index] = true;
      }
    }

    // 2) Friend name token (actor nickname when present in headline).
    final actorName = notification.actorNickname;
    if (actorName != null && actorName.isNotEmpty) {
      _markToken(headline, actorName, shouldEmphasize);
    }

    // 3) The word "คุณ".
    _markToken(headline, 'คุณ', shouldEmphasize);

    if (headline.isEmpty) {
      return TextSpan(text: '', style: baseStyle);
    }

    final spans = <InlineSpan>[];
    var runStart = 0;

    while (runStart < headline.length) {
      final runStyle = shouldEmphasize[runStart] ? emphasisStyle : baseStyle;
      var runEnd = runStart + 1;
      while (runEnd < headline.length &&
          shouldEmphasize[runEnd] == shouldEmphasize[runStart]) {
        runEnd++;
      }
      spans.add(TextSpan(text: headline.substring(runStart, runEnd), style: runStyle));
      runStart = runEnd;
    }

    return TextSpan(children: spans, style: baseStyle);
  }

  void _markToken(String text, String token, List<bool> shouldEmphasize) {
    if (token.isEmpty || text.isEmpty) return;

    var start = 0;
    while (true) {
      final index = text.indexOf(token, start);
      if (index == -1) break;
      for (var i = index; i < index + token.length && i < text.length; i++) {
        shouldEmphasize[i] = true;
      }
      start = index + token.length;
    }
  }

  String _subtitleText(AppNotification notification) {
    final actor = notification.actorNickname;
    if (actor != null && actor.isNotEmpty) {
      return 'โดย$actor';
    }
    return notification.body;
  }

  String _expenseLabel(AppNotification notification) {
    final metadataDescription = notification.metadata?['description'];
    if (metadataDescription is String && metadataDescription.isNotEmpty) {
      return metadataDescription;
    }

    final body = notification.body;
    final separatorIndex = body.indexOf('·');
    if (separatorIndex > 0) {
      final leftPart = body.substring(0, separatorIndex).trim();
      if (leftPart.isNotEmpty) return leftPart;
    }

    return body.trim();
  }

  String? _tripLabel(AppNotification notification) {
    final metadata = notification.metadata;
    if (metadata == null) return null;
    final tripName = metadata['trip_name'];
    if (tripName is String && tripName.isNotEmpty) return tripName;
    final dateLabel = metadata['date_label'];
    if (dateLabel is String && dateLabel.isNotEmpty) return dateLabel;
    return null;
  }

  String? _amountOrStatus(AppNotification notification) {
    final amountValue = _extractAmount(notification);

    if (notification.type == NotificationType.expenseDeleted) {
      return 'ลบแล้ว';
    }

    if (amountValue == null) return null;
    final formatted = amountValue.toStringAsFixed(2);

    return switch (notification.type) {
      NotificationType.settlementVerified => '+$formatted฿',
      NotificationType.manualDebtorReminder => '-$formatted฿',
      _ => '$formatted฿',
    };
  }

  double? _extractAmount(AppNotification notification) {
    final metadataAmount = notification.metadata?['amount'];
    if (metadataAmount is num) return metadataAmount.toDouble();

    final amountPattern = RegExp(r'([0-9]+(?:\.[0-9]+)?)');
    final bodyMatch = amountPattern.firstMatch(notification.body);
    if (bodyMatch == null) return null;
    return double.tryParse(bodyMatch.group(1)!);
  }

  _NotificationVisualStyle _visualStyleFor(AppNotification notification) {
    return switch (notification.type) {
      NotificationType.expenseCreated => const _NotificationVisualStyle(
          badgeColor: Color(0xFF81CEF2),
          amountColor: Color(0xFF81CEF2),
        ),
      NotificationType.expenseUpdated => const _NotificationVisualStyle(
          badgeColor: Color(0xFFF2DA88),
          amountColor: Color(0xFFF2DA88),
        ),
      NotificationType.expenseDeleted => const _NotificationVisualStyle(
          badgeColor: Color(0xFFFC5154),
          amountColor: Color(0xFFFC5154),
        ),
      NotificationType.settlementVerified => const _NotificationVisualStyle(
          badgeColor: Color(0xFF3DCB57),
          amountColor: Color(0xFF3DCB57),
        ),
      NotificationType.settlementRejected => const _NotificationVisualStyle(
          badgeColor: Color(0xFFFC5154),
          amountColor: Color(0xFFFC5154),
        ),
      NotificationType.settlementPending || NotificationType.settlementNeedReview =>
        const _NotificationVisualStyle(
          badgeColor: Color(0xFF81CEF2),
          amountColor: Color(0xFF81CEF2),
        ),
      NotificationType.manualDebtorReminder => const _NotificationVisualStyle(
          badgeColor: Color(0xFFFC5154),
          amountColor: Color(0xFFFC5154),
        ),
      NotificationType.friendRequest ||
      NotificationType.friendAccepted ||
      NotificationType.tripInvited ||
      NotificationType.tripJoined ||
      NotificationType.unknown =>
        _NotificationVisualStyle(
          badgeColor: notification.type.iconColor,
          amountColor: const Color(0x66141416),
        ),
    };
  }

}

class _Avatar extends StatelessWidget {
  final AppNotification notification;
  final _NotificationVisualStyle style;

  const _Avatar({required this.notification, required this.style});

  @override
  Widget build(BuildContext context) {
    final avatarUrl = notification.actorAvatarUrl;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: Colors.grey[100],
          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
          child: avatarUrl == null
              ? Icon(Icons.person, color: Colors.grey[400], size: 22)
              : null,
        ),
        Positioned(
          right: -4,
          bottom: -4,
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: style.badgeColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: Icon(
              notification.type.icon,
              size: 10,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class _TrailingMeta extends StatelessWidget {
  final AppNotification notification;
  final bool isUnread;
  final String? amountOrStatus;
  final Color amountColor;

  const _TrailingMeta({
    required this.notification,
    required this.isUnread,
    required this.amountOrStatus,
    required this.amountColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _formatDateTime(notification.createdAt),
              style: const TextStyle(
                fontFamily: 'LINESeedSansTH',
                color: Color(0x66141416),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (isUnread) ...[
              const SizedBox(width: 4),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFFFC5154),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        if (amountOrStatus != null)
          Text(
            amountOrStatus!,
            style: TextStyle(
              fontFamily: 'LINESeedSansTH',
              color: amountColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }

  String _formatDateTime(DateTime dt) {
    const thaiMonths = <String>[
      'ม.ค.',
      'ก.พ.',
      'มี.ค.',
      'เม.ย.',
      'พ.ค.',
      'มิ.ย.',
      'ก.ค.',
      'ส.ค.',
      'ก.ย.',
      'ต.ค.',
      'พ.ย.',
      'ธ.ค.',
    ];

    final monthLabel = thaiMonths[dt.month - 1];
    final buddhistYearTwoDigits = (dt.year + 543) % 100;
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');

    return '${dt.day} $monthLabel ${buddhistYearTwoDigits.toString().padLeft(2, '0')} $hour:$minute';
  }
}

class _NotificationVisualStyle {
  final Color badgeColor;
  final Color amountColor;

  const _NotificationVisualStyle({
    required this.badgeColor,
    required this.amountColor,
  });
}
