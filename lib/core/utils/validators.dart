/// Upload size limit, checked before any network call.
const kMaxUploadBytes = 200 * 1024 * 1024;
const kMinVideoDuration = Duration(seconds: 3);
const kMaxVideoDuration = Duration(minutes: 3);

const kCaptionMaxLength = 2200;
const kBrandMinLength = 2;
const kBrandMaxLength = 80;
const kClipLabelMaxLength = 60;

/// Bytes [sniffContainer] needs from the start of the file.
const kSniffBytes = 12;

enum VideoContainer {
  mp4('MP4'),
  mov('MOV'),
  webm('WebM');

  const VideoContainer(this.label);

  final String label;

  bool get isIsoMedia => this != webm;
}

const _containersByExtension = {
  'mp4': VideoContainer.mp4,
  'mov': VideoContainer.mov,
  'webm': VideoContainer.webm,
};

const _allowedMimeTypes = {'video/mp4', 'video/quicktime', 'video/webm'};

/// Container from the file's leading bytes, or null if it isn't one we
/// accept. MP4 and MOV share the ISO media layout ("ftyp" at offset 4);
/// WebM starts with the EBML magic number.
VideoContainer? sniffContainer(List<int> header) {
  if (header.length >= 12 &&
      header[4] == 0x66 && // f
      header[5] == 0x74 && // t
      header[6] == 0x79 && // y
      header[7] == 0x70) {
    // A "qt  " major brand marks QuickTime.
    final brand = String.fromCharCodes(header.sublist(8, 12));
    return brand == 'qt  ' ? VideoContainer.mov : VideoContainer.mp4;
  }
  if (header.length >= 4 &&
      header[0] == 0x1A &&
      header[1] == 0x45 &&
      header[2] == 0xDF &&
      header[3] == 0xA3) {
    return VideoContainer.webm;
  }
  return null;
}

String? _extensionOf(String name) {
  final dot = name.lastIndexOf('.');
  if (dot <= 0 || dot == name.length - 1) return null;
  return name.substring(dot + 1).toLowerCase();
}

sealed class VideoProblem {
  const VideoProblem();
}

final class VideoTooLarge extends VideoProblem {
  const VideoTooLarge(this.sizeBytes);

  final int sizeBytes;
}

final class VideoUnsupported extends VideoProblem {
  const VideoUnsupported();
}

final class VideoTooShort extends VideoProblem {
  const VideoTooShort();
}

final class VideoTooLong extends VideoProblem {
  const VideoTooLong();
}

final class VideoUnreadable extends VideoProblem {
  const VideoUnreadable();
}

/// The decoder didn't report metadata in time, even after a retry. The
/// file may be fine; trying again can work.
final class VideoDecodeTimeout extends VideoProblem {
  const VideoDecodeTimeout();
}

/// Checks that need only the file itself, not a decoder. Returns the
/// sniffed container, or the first problem found.
({VideoContainer? container, VideoProblem? problem}) checkVideoFile({
  required String name,
  required int sizeBytes,
  required List<int> header,
  String? mimeType,
}) {
  if (sizeBytes <= 0) {
    return (container: null, problem: const VideoUnreadable());
  }
  if (sizeBytes > kMaxUploadBytes) {
    return (container: null, problem: VideoTooLarge(sizeBytes));
  }

  const unsupported = (container: null, problem: VideoUnsupported());
  final extension = _extensionOf(name);
  if (extension != null && !_containersByExtension.containsKey(extension)) {
    return unsupported;
  }
  if (mimeType != null && !_allowedMimeTypes.contains(mimeType)) {
    return unsupported;
  }

  // The bytes decide; a renamed file must not pass on its extension alone.
  final sniffed = sniffContainer(header);
  if (sniffed == null) return unsupported;
  final named = _containersByExtension[extension];
  if (named != null && named.isIsoMedia != sniffed.isIsoMedia) {
    return unsupported;
  }
  return (container: sniffed, problem: null);
}

VideoProblem? checkVideoDuration(Duration duration) {
  if (duration < kMinVideoDuration) return const VideoTooShort();
  if (duration > kMaxVideoDuration) return const VideoTooLong();
  return null;
}

// Control characters other than tab and newline, which captions keep.
final _controlChars = RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]');

String sanitizeText(String raw) => raw.replaceAll(_controlChars, '').trim();

String? validateCaption(String raw) {
  final value = sanitizeText(raw);
  if (value.isEmpty) return 'Add a caption';
  if (value.length > kCaptionMaxLength) {
    return 'Keep it under $kCaptionMaxLength characters';
  }
  return null;
}

String? validateBrand(String raw, {required bool isPaid}) {
  if (!isPaid) return null;
  final value = sanitizeText(raw);
  if (value.isEmpty) return 'Name the brand or partner';
  if (value.length < kBrandMinLength) return 'That name looks too short';
  if (value.length > kBrandMaxLength) {
    return 'Keep it under $kBrandMaxLength characters';
  }
  return null;
}

String? validateClipLabel(String raw) {
  final value = sanitizeText(raw);
  if (value.isEmpty) return 'Add a short label';
  if (value.length > kClipLabelMaxLength) {
    return 'Keep it under $kClipLabelMaxLength characters';
  }
  return null;
}

/// Empty is allowed (the clip may be attached as a file instead).
String? validateClipUrl(String raw) {
  final value = sanitizeText(raw);
  if (value.isEmpty) return null;
  final uri = Uri.tryParse(value);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
    return 'Use a full https:// link';
  }
  return null;
}
