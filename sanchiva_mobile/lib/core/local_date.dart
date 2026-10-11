/// Phone-local calendar helpers.
///
/// All day boundaries (entries, “today” totals, filters) must use the device
/// local calendar — never UTC midnight tricks that flip the day after 12 AM IST.
library;

/// Calendar date for [d] (time stripped) in the device local zone.
DateTime localCalendarDate([DateTime? d]) {
  final n = d ?? DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

/// Today on the phone as `YYYY-MM-DD`.
String localDateYmd([DateTime? d]) {
  final n = d ?? DateTime.now();
  final y = n.year.toString().padLeft(4, '0');
  final m = n.month.toString().padLeft(2, '0');
  final day = n.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

/// Format any [DateTime] as local calendar `YYYY-MM-DD` (uses year/month/day fields).
String toLocalYmd(DateTime d) => localDateYmd(d);

/// Parse `YYYY-MM-DD` (or longer ISO) as a **local** calendar date (no UTC shift).
DateTime parseLocalYmd(String? raw, {DateTime? fallback}) {
  final s = (raw ?? '').trim();
  if (s.length >= 10) {
    final y = int.tryParse(s.substring(0, 4));
    final m = int.tryParse(s.substring(5, 7));
    final d = int.tryParse(s.substring(8, 10));
    if (y != null && m != null && d != null) {
      return DateTime(y, m, d);
    }
  }
  return fallback ?? localCalendarDate();
}

bool isSameLocalDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

bool isLocalToday(DateTime d) => isSameLocalDay(d, DateTime.now());
