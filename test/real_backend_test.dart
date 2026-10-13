import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:contextlens/features/compose/declaration.dart';
import 'package:contextlens/features/report/firestore_job_repository.dart';
import 'package:contextlens/features/report/models.dart';
import 'package:contextlens/features/upload/resumable_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resumable protocol', () {
    test('reads the committed offset from a 308 Range header', () {
      expect(committedFromRange(null), 0);
      expect(committedFromRange(''), 0);
      expect(committedFromRange('bytes=0-8388607'), 8388608);
      expect(committedFromRange('garbage'), 0);
    });

    test('builds Content-Range headers', () {
      expect(chunkRange(0, 8388607, 20000000), 'bytes 0-8388607/20000000');
      expect(statusRange(20000000), 'bytes */20000000');
    });

    test('chunks end on the quantum, the last one on the file end', () {
      const chunk = 8 * 1024 * 1024;
      expect(chunkEnd(0, chunk, 20000000), chunk - 1);
      expect(chunkEnd(2 * chunk, chunk, 20000000), 20000000 - 1);
      expect(chunk % kResumableQuantum, 0);
    });

    test('chunk sizes are snapped to 256 KiB multiples', () {
      expect(validChunkSize(8 * 1024 * 1024), 8 * 1024 * 1024);
      expect(validChunkSize(8 * 1024 * 1024 + 5), 8 * 1024 * 1024);
      expect(validChunkSize(1000), kResumableQuantum);
    });
  });

  group('Firestore mapping', () {
    final created = Timestamp.fromDate(DateTime.utc(2026, 10, 13, 9));

    test('a job document becomes a Job with its id', () {
      final job = jobFromDocument('abc', {
        'ownerUid': 'u1',
        'status': 'done',
        'stage': 'report',
        'createdAt': created,
        'updatedAt': created,
        'version': 1,
        'objectName': 'uploads/u1/abc/source',
        'flags': <Object?>[],
        'summary': {'total': 0, 'byCategory': <String, Object?>{}},
      })!;
      expect(job.id, 'abc');
      expect(job.status, JobStatus.done);
      expect(job.createdAt, DateTime.utc(2026, 10, 13, 9));
    });

    test('an unreadable document is skipped, not thrown', () {
      expect(jobFromDocument('bad', {'status': 'done'}), isNull);
    });

    test('the declaration comes back as a draft', () {
      final draft = declarationFromDocument({
        'declaration': {
          'caption': 'Morning routine',
          'isPaid': true,
          'brandName': 'VitaBoost',
          'category': 'health',
          'borrowedClips': [
            {'label': 'Podcast', 'url': 'https://example.com/212'},
          ],
        },
      })!;
      expect(draft.caption, 'Morning routine');
      expect(draft.brand, 'VitaBoost');
      expect(draft.category, ContentCategory.health);
      expect(draft.clips.single.url, 'https://example.com/212');
      expect(draft.isValid, isTrue);
    });
  });
}
