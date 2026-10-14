import 'package:contextlens/features/report/models.dart';
import 'package:contextlens/features/run/processing_progress.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('each stage is a fifth, easing toward 90% of its share', () {
    double at(int stage, int seconds) => StageProgress.target(
      stage: stage,
      inStage: Duration(seconds: seconds),
      done: false,
    );

    expect(at(0, 0), 0);
    expect(at(1, 0), closeTo(0.2, 1e-9));
    expect(at(0, 600), closeTo(0.18, 1e-3));
    expect(at(2, 5), greaterThan(at(2, 1)));
    expect(at(2, 5), lessThan(0.6));
  });

  test('never reaches 100% before the job is done', () {
    final last = StageProgress.target(
      stage: 4,
      inStage: const Duration(hours: 1),
      done: false,
    );
    expect(last, lessThan(1));
    expect(
      StageProgress.target(stage: 4, inStage: Duration.zero, done: true),
      1,
    );
  });

  test('the shown progress never goes backwards', () {
    final progress = MonotonicProgress();
    expect(progress.update(0.42), 0.42);
    expect(progress.update(0.2), 0.42);
    expect(progress.update(0.6), 0.6);
  });

  test('stage index for every backend stage', () {
    expect(stageIndexOf(null), 0);
    expect(stageIndexOf(JobStage.extract), 0);
    expect(stageIndexOf(JobStage.evidence), 3);
    expect(stageIndexOf(JobStage.unknown), 0);
  });

  test('a new tip every 6 seconds, looping', () {
    expect(tipIndexAt(Duration.zero), 0);
    expect(tipIndexAt(const Duration(seconds: 5)), 0);
    expect(tipIndexAt(const Duration(seconds: 6)), 1);
    expect(tipIndexAt(const Duration(seconds: 6 * 8)), 0);
  });

  test('tips are short and use no long dashes', () {
    for (final tip in processingTips) {
      expect(tip.length, lessThan(110), reason: tip);
      expect(tip.contains(String.fromCharCode(0x2014)), isFalse);
      expect(tip.contains(String.fromCharCode(0x2013)), isFalse);
    }
    expect(processingTips, hasLength(8));
  });
}
