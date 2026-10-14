import 'dart:async';
import 'dart:io';

import 'package:contextlens/core/utils/validators.dart';
import 'package:contextlens/features/compose/compose_controller.dart';
import 'package:contextlens/features/compose/video_inspector.dart';
import 'package:contextlens/features/compose/video_source.dart';
import 'package:flutter_test/flutter_test.dart';

const VideoMetadata _ok = (
  duration: Duration(seconds: 7),
  width: 1280,
  height: 720,
);

void main() {
  late Directory dir;
  late String path;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('inspector');
    path = '${dir.path}/clip.mp4';
    File(path).writeAsBytesSync([
      0, 0, 0, 0x20, ...'ftypisom'.codeUnits, ...List.filled(64, 0), //
    ]);
  });

  tearDown(() => dir.deleteSync(recursive: true));

  DeviceVideoInspector inspector(List<Object> outcomes) {
    var call = 0;
    return DeviceVideoInspector(
      thumbnails: false,
      readMetadata: (path, timeout) async {
        final outcome = outcomes[call++];
        if (outcome is VideoMetadata) return outcome;
        throw outcome;
      },
    );
  }

  test('a timeout is retried once and can then succeed', () async {
    final result = await inspector([TimeoutException('slow'), _ok])
        .inspect(path, name: 'clip.mp4');
    expect(result, isA<InspectionPassed>());
  });

  test('two timeouts report a timeout, not a damaged file', () async {
    final result = await inspector([
      TimeoutException('slow'),
      TimeoutException('slow'),
    ]).inspect(path, name: 'clip.mp4');
    expect((result as InspectionFailed).problem, isA<VideoDecodeTimeout>());
  });

  test('a decoder error is reported as unreadable without a retry', () async {
    final result = await inspector([StateError('bad data')])
        .inspect(path, name: 'clip.mp4');
    expect((result as InspectionFailed).problem, isA<VideoUnreadable>());
  });

  test('numeric gallery names get a readable label', () {
    final now = DateTime(2026, 10, 12);
    String label(String name, {required bool fromGallery}) =>
        ComposeController.displayNameFor(
          PickedFile(path: '/c/$name', name: name),
          fromGallery: fromGallery,
          now: now,
        );

    expect(label('36.mp4', fromGallery: true), 'Video from gallery, 12 Oct');
    expect(
      label('1000000033', fromGallery: true),
      'Video from gallery, 12 Oct',
    );
    expect(label('butterfly.mp4', fromGallery: true), 'butterfly.mp4');
    expect(label('36.mp4', fromGallery: false), '36.mp4');
  });
}
