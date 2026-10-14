import 'package:contextlens/features/report/models.dart';
import 'package:contextlens/features/report/skipped_notice.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('names the checks that could not run', () {
    expect(
      SkippedNotice.copy(['factcheck']),
      "Fact check couldn't run this time. Run the check again to include it.",
    );
    expect(
      SkippedNotice.copy(['claims', 'factcheck', 'borrowed']),
      startsWith('Claims, Fact check and Borrowed clips'),
    );
  });

  test('a job lists skipped checkers from the backend', () {
    final job = Job.fromJson({
      'id': 'j',
      'status': 'done',
      'createdAt': '2026-10-14T09:00:00Z',
      'skipped': ['factcheck'],
    });
    expect(job.skipped, ['factcheck']);
  });
}
