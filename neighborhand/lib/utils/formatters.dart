import 'package:flutter/material.dart';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "7:05" style minutes:seconds, never negative.
String formatCountdown(Duration remaining) {
  final seconds = remaining.inSeconds < 0 ? 0 : remaining.inSeconds;
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}

/// "Today, 2:00 PM", "Tomorrow, 9:30 AM", or "Sep 14, 2:00 PM".
String formatWhen(BuildContext context, DateTime when) {
  final time = TimeOfDay.fromDateTime(when).format(context);
  final now = DateTime.now();
  final days = DateTime(when.year, when.month, when.day)
      .difference(DateTime(now.year, now.month, now.day))
      .inDays;
  if (days == 0) return 'Today, $time';
  if (days == 1) return 'Tomorrow, $time';
  return '${_months[when.month - 1]} ${when.day}, $time';
}

/// "30 min", "1 hr", "3 hrs", or "1 hr 30 min".
String formatDuration(int minutes) {
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (hours == 0) return '$rest min';
  if (rest == 0) return hours == 1 ? '1 hr' : '$hours hrs';
  return '$hours hr $rest min';
}
