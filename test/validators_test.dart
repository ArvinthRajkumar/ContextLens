import 'package:contextlens/core/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

List<int> _ftyp(String brand) => [
  0,
  0,
  0,
  0x20,
  ...'ftyp'.codeUnits,
  ...brand.codeUnits,
];
const _webm = [0x1A, 0x45, 0xDF, 0xA3, 0, 0, 0, 0, 0, 0, 0, 0];
final _text = 'hello world!'.codeUnits;

void main() {
  group('sniffContainer', () {
    test('recognizes MP4, MOV and WebM by their leading bytes', () {
      expect(sniffContainer(_ftyp('isom')), VideoContainer.mp4);
      expect(sniffContainer(_ftyp('mp42')), VideoContainer.mp4);
      expect(sniffContainer(_ftyp('qt  ')), VideoContainer.mov);
      expect(sniffContainer(_webm), VideoContainer.webm);
    });

    test('rejects anything else, including short headers', () {
      expect(sniffContainer(_text), isNull);
      expect(sniffContainer(const [0, 0]), isNull);
    });
  });

  group('checkVideoFile', () {
    ({VideoContainer? container, VideoProblem? problem}) check(
      String name, {
      int size = 1024,
      List<int>? header,
      String? mime,
    }) => checkVideoFile(
      name: name,
      sizeBytes: size,
      header: header ?? _ftyp('isom'),
      mimeType: mime,
    );

    test('accepts supported files', () {
      expect(check('a.mp4').container, VideoContainer.mp4);
      expect(
        check('a.MOV', header: _ftyp('qt  ')).container,
        VideoContainer.mov,
      );
      expect(check('a.webm', header: _webm).container, VideoContainer.webm);
      expect(check('no-extension').problem, isNull);
    });

    test('rejects over the size limit before looking at the bytes', () {
      final result = check('a.mp4', size: kMaxUploadBytes + 1, header: _text);
      expect(result.problem, isA<VideoTooLarge>());
    });

    test('rejects disallowed extensions and mime types', () {
      expect(check('a.mkv', header: _webm).problem, isA<VideoUnsupported>());
      expect(check('a.avi').problem, isA<VideoUnsupported>());
      expect(
        check('a.mp4', mime: 'video/x-msvideo').problem,
        isA<VideoUnsupported>(),
      );
    });

    test('a renamed file fails on its bytes', () {
      expect(
        check('notes.mp4', header: _text).problem,
        isA<VideoUnsupported>(),
      );
      expect(check('clip.mp4', header: _webm).problem, isA<VideoUnsupported>());
    });

    test('an empty file is unreadable', () {
      expect(check('a.mp4', size: 0).problem, isA<VideoUnreadable>());
    });
  });

  test('checkVideoDuration enforces 3 s to 3 min', () {
    expect(
      checkVideoDuration(const Duration(seconds: 2)),
      isA<VideoTooShort>(),
    );
    expect(checkVideoDuration(const Duration(seconds: 3)), isNull);
    expect(checkVideoDuration(const Duration(minutes: 3)), isNull);
    expect(
      checkVideoDuration(const Duration(minutes: 3, seconds: 1)),
      isA<VideoTooLong>(),
    );
  });

  group('declaration fields', () {
    test('sanitizeText trims and strips control characters', () {
      expect(sanitizeText('  hi\u0000 there\u0007\n'), 'hi there');
      expect(sanitizeText('line one\nline two'), 'line one\nline two');
    });

    test('caption is required and capped', () {
      expect(validateCaption('  \u0000 '), isNotNull);
      expect(validateCaption('Morning routine'), isNull);
      expect(validateCaption('a' * (kCaptionMaxLength + 1)), isNotNull);
    });

    test('brand is required only for paid content', () {
      expect(validateBrand('', isPaid: false), isNull);
      expect(validateBrand('', isPaid: true), isNotNull);
      expect(validateBrand('V', isPaid: true), isNotNull);
      expect(validateBrand('VitaBoost', isPaid: true), isNull);
      expect(
        validateBrand('x' * (kBrandMaxLength + 1), isPaid: true),
        isNotNull,
      );
    });

    test('clip links must be https', () {
      expect(validateClipUrl(''), isNull);
      expect(validateClipUrl('https://example.com/ep/212'), isNull);
      expect(validateClipUrl('http://example.com'), isNotNull);
      expect(validateClipUrl('example.com'), isNotNull);
      expect(validateClipUrl('https://'), isNotNull);
    });
  });
}
