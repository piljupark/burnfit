import 'package:intl/intl.dart';

/// "방금", "5분 전", "3시간 전", "어제", "3일 전", 그 이상은 날짜.
String formatRelativeTime(DateTime time, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final diff = current.difference(time);

  if (diff.isNegative || diff.inMinutes < 1) return '방금';
  if (diff.inHours < 1) return '${diff.inMinutes}분 전';

  final today = DateTime(current.year, current.month, current.day);
  final day = DateTime(time.year, time.month, time.day);
  final days = today.difference(day).inDays;

  if (days == 0) return '${diff.inHours}시간 전';
  if (days == 1) return '어제';
  if (days < 7) return '$days일 전';
  if (time.year == current.year) return DateFormat('M월 d일').format(time);
  return DateFormat('yyyy.MM.dd').format(time);
}
