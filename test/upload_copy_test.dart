import 'package:contextlens/features/upload/upload_copy.dart';
import 'package:contextlens/features/upload/upload_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('server caps read as their own message', () {
    expect(
      const UploadRejected('daily_limit').message,
      'Daily limit reached, try again tomorrow.',
    );
    expect(
      const UploadRejected('busy').message,
      'ContextLens is busy, try later.',
    );
    expect(
      const UploadRejected('too_many_running').message,
      startsWith('You have 3 checks running.'),
    );
    expect(
      const UploadRejected('video_too_long').message,
      'Videos can be up to 3 minutes long.',
    );
    expect(
      const UploadRejected('something_else').message,
      "The server didn't accept this upload.",
    );
  });
}
