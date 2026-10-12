import 'dart:convert';
import 'dart:io';

import 'package:contextlens/features/report/models.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _fixture(String name) =>
    jsonDecode(File('assets/mock/$name').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  test('unknown enum values fall back instead of throwing', () {
    final job = Job.fromJson({
      'id': 'j1',
      'status': 'archived',
      'stage': 'translate',
      'createdAt': '2026-10-12T09:00:00Z',
      'summary': {
        'total': 1,
        'byCategory': {'music': 1},
      },
      'flags': [
        {
          'id': 'f1',
          'fingerprint': 'x',
          'category': 'music',
          'severity': 'critical',
          'startMs': 0,
          'endMs': 1000,
          'title': 't',
          'evidence': 'e',
          'suggestedFix': 's',
          'factLabel': 'satire',
        },
      ],
    });

    expect(job.status, JobStatus.unknown);
    expect(job.stage, JobStage.unknown);
    expect(job.summary!.counts, {FlagCategory.unknown: 1});
    final flag = job.flags.single;
    expect(flag.category, FlagCategory.unknown);
    expect(flag.severity, Severity.unknown);
    expect(flag.factLabel, FactLabel.unknown);
  });

  test('finance fixture covers every category and fact label', () {
    final job = Job.fromJson(_fixture('report_finance.json'));
    expect(
      job.issues.map((f) => f.category).toSet(),
      FlagCategory.values.toSet()..remove(FlagCategory.unknown),
    );
    expect(
      job.flags.map((f) => f.factLabel).whereType<FactLabel>().toSet(),
      FactLabel.values.toSet()..remove(FactLabel.unknown),
    );
    expect(job.summary!.total, job.issues.length);
  });

  test('supported fact checks are checked claims, not issues', () {
    final job = Job.fromJson(_fixture('report_v1.json'));
    expect(job.issues, hasLength(4));
    expect(job.checkedClaims.single.factLabel, FactLabel.supported);
    expect(job.checkedClaims.single.severity, isNull);
    expect(job.issueCounts.values.fold(0, (a, b) => a + b), 4);
    expect(job.issues.where((f) => f.diff != null), hasLength(1));
  });

  test('v2 counts agree with "3 of 4 resolved"', () {
    final v1 = Job.fromJson(_fixture('report_v1.json'));
    final v2 = Job.fromJson(_fixture('report_v2.json'));
    final c = v2.comparison!;
    expect(c.resolved + c.remaining, v1.issues.length);
    expect(v2.issues, hasLength(c.remaining + c.newCount));
    expect(v2.summary!.total, v2.issues.length);
  });

  test('round-trips through JSON', () {
    final job = Job.fromJson(_fixture('report_v1.json'));
    final again = Job.fromJson(
      jsonDecode(jsonEncode(job.toJson())) as Map<String, dynamic>,
    );
    expect(again, job);
  });
}
