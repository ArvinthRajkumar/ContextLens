import 'package:contextlens/core/utils/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatDurationMs', () {
    test('formats minutes and seconds', () {
      expect(formatDurationMs(0), '0:00');
      expect(formatDurationMs(58000), '0:58');
      expect(formatDurationMs(724000), '12:04');
    });

    test('adds hours past one hour', () {
      expect(formatDurationMs(3729000), '1:02:09');
    });
  });

  group('formatRunDate', () {
    final now = DateTime(2026, 10, 12, 15);

    test('uses Today and Yesterday', () {
      expect(
        formatRunDate(DateTime(2026, 10, 12, 9, 5), now: now),
        'Today, 09:05',
      );
      expect(
        formatRunDate(DateTime(2026, 10, 11, 18, 20), now: now),
        'Yesterday, 18:20',
      );
    });

    test('drops the year within the current year', () {
      expect(formatRunDate(DateTime(2026, 10, 3, 8), now: now), 'Oct 3');
      expect(
        formatRunDate(DateTime(2025, 12, 31, 8), now: now),
        'Dec 31, 2025',
      );
    });
  });

  group('titleFromCaption', () {
    test('uses the first non-empty line', () {
      expect(
        titleFromCaption('\n  My morning routine \n#ad'),
        'My morning routine',
      );
      expect(titleFromCaption('   \n '), isNull);
    });

    test('caps at 60 characters on a word boundary', () {
      final title = titleFromCaption(
        'The three supplements I take every single morning and why I stopped the fourth',
      )!;
      expect(title.length, lessThanOrEqualTo(60));
      expect(
        title,
        'The three supplements I take every single morning and why I…',
      );
    });
  });

  test('formatBytes picks a readable unit', () {
    expect(formatBytes(512), '512 B');
    expect(formatBytes(820 * 1024), '820 KB');
    expect(formatBytes((24.1 * 1024 * 1024).round()), '24.1 MB');
    expect(formatBytes(500 * 1024 * 1024), '500 MB');
    expect(formatBytes((1.2 * 1024 * 1024 * 1024).round()), '1.2 GB');
  });
}
