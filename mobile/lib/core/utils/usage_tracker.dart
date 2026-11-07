import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A point-in-time read of today's per-feature usage.
class UsageSnapshot {
  final int analyses;
  final int images;
  final String dateKey;

  const UsageSnapshot({
    required this.analyses,
    required this.images,
    required this.dateKey,
  });
}

/// Local, free, honest usage metering for the free tiers: counts today's
/// room analyses and generated images, resetting at midnight Pacific —
/// when Google's free quotas actually refresh. Purely informational
/// (the providers don't expose remaining-quota endpoints, so we show
/// counts and the reset time, never fake "X remaining" bars).
class UsageTracker {
  static const String _dateKey = 'usage_today_key';
  static const String _analysisCount = 'usage_analysis_count';
  static const String _imageCount = 'usage_image_count';

  /// Midnight Pacific in UTC terms is -8h (PST); DST variance of ±1h on
  /// the boundary is irrelevant for a daily counter.
  String _pacificDate() {
    final now = DateTime.now().toUtc().subtract(const Duration(hours: 8));
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  Future<SharedPreferences> _prefs() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _pacificDate();
    if (prefs.getString(_dateKey) != today) {
      await prefs.setString(_dateKey, today);
      await prefs.setInt(_analysisCount, 0);
      await prefs.setInt(_imageCount, 0);
    }
    return prefs;
  }

  Future<UsageSnapshot> snapshot() async {
    final prefs = await _prefs();
    return UsageSnapshot(
      analyses: prefs.getInt(_analysisCount) ?? 0,
      images: prefs.getInt(_imageCount) ?? 0,
      dateKey: _pacificDate(),
    );
  }

  Future<void> recordAnalysis() async {
    final prefs = await _prefs();
    await prefs.setInt(_analysisCount, (prefs.getInt(_analysisCount) ?? 0) + 1);
  }

  Future<void> recordImage() async {
    final prefs = await _prefs();
    await prefs.setInt(_imageCount, (prefs.getInt(_imageCount) ?? 0) + 1);
  }
}

final usageTrackerProvider = Provider<UsageTracker>((ref) => UsageTracker());

/// Watch this for the Settings gauge; invalidate after every record.
final usageProvider =
    FutureProvider<UsageSnapshot>((ref) => ref.watch(usageTrackerProvider).snapshot());
