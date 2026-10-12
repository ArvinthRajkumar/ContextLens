import 'package:contextlens/features/report/models.dart';
import 'package:contextlens/features/report/run_history.dart';
import 'package:flutter_test/flutter_test.dart';

Job _job(String id, int version, int hour, {String? parent}) => Job(
  id: id,
  status: JobStatus.done,
  version: version,
  parentJobId: parent,
  createdAt: DateTime.utc(2026, 10, 12, hour),
);

void main() {
  final a1 = _job('a1', 1, 7);
  final a2 = _job('a2', 2, 9, parent: 'a1');
  final a3 = _job('a3', 3, 11, parent: 'a2');
  final b1 = _job('b1', 1, 10);
  final orphan = _job('c2', 2, 8, parent: 'expired');

  test('keeps the latest run per video, newest first', () {
    expect(latestRunPerVideo([a1, b1, a3, a2, orphan]), [a3, b1, orphan]);
  });

  test('lists every run of a video, latest first', () {
    expect(runsOfVideo([a1, b1, a3, a2], 'a1'), [a3, a2, a1]);
    expect(runsOfVideo([a1, b1], 'b1'), [b1]);
    expect(runsOfVideo([a1], 'missing'), isEmpty);
  });

  test('survives a parent cycle', () {
    final x = _job('x', 1, 1, parent: 'y');
    final y = _job('y', 2, 2, parent: 'x');
    expect(latestRunPerVideo([x, y]), hasLength(1));
  });
}
