const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _two(int n) => n.toString().padLeft(2, '0');

/// "0:58", "12:04", "1:02:09".
String formatDurationMs(int ms) {
  final total = Duration(milliseconds: ms).inSeconds;
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  return h > 0 ? '$h:${_two(m)}:${_two(s)}' : '$m:${_two(s)}';
}

/// "Today, 09:41", "Yesterday, 18:20", "Oct 3", or "Oct 3, 2025" for
/// other years. Times are local and 24-hour.
String formatRunDate(DateTime when, {DateTime? now}) {
  final local = when.toLocal();
  final today = now?.toLocal() ?? DateTime.now();
  final day = DateTime(local.year, local.month, local.day);
  final todayStart = DateTime(today.year, today.month, today.day);
  final time = '${_two(local.hour)}:${_two(local.minute)}';
  final daysAgo = todayStart.difference(day).inDays;

  if (daysAgo == 0) return 'Today, $time';
  if (daysAgo == 1) return 'Yesterday, $time';
  final date = '${_months[local.month - 1]} ${local.day}';
  return local.year == today.year ? date : '$date, ${local.year}';
}

/// Run title from the caption: its first non-empty line, at most [maxLength]
/// characters, cut at a word boundary when possible.
String? titleFromCaption(String caption, {int maxLength = 60}) {
  final line = caption
      .split('\n')
      .map((l) => l.trim())
      .firstWhere((l) => l.isNotEmpty, orElse: () => '');
  if (line.isEmpty) return null;
  if (line.length <= maxLength) return line;
  final cut = line.substring(0, maxLength - 1);
  // Keep the cut as is when it already ends on a whole word.
  final endsOnWord = line[cut.length] == ' ';
  final space = cut.lastIndexOf(' ');
  final head = endsOnWord || space <= maxLength ~/ 2
      ? cut
      : cut.substring(0, space);
  return '${head.trimRight()}…';
}
