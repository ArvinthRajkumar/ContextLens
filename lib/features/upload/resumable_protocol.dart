// Pure helpers for the Cloud Storage resumable upload protocol.
// https://cloud.google.com/storage/docs/performing-resumable-uploads

/// GCS requires every chunk but the last to be a multiple of 256 KiB.
const kResumableQuantum = 256 * 1024;

/// "308 Resume Incomplete": more bytes are expected.
const kResumeIncomplete = 308;

/// Bytes the server has, from a 308's `Range: bytes=0-N` header. No header
/// means nothing is committed yet.
int committedFromRange(String? range) {
  if (range == null || range.isEmpty) return 0;
  final match = RegExp(r'bytes=0-(\d+)').firstMatch(range);
  if (match == null) return 0;
  return int.parse(match.group(1)!) + 1;
}

/// `Content-Range` for the chunk [start, end] (inclusive) of [total].
String chunkRange(int start, int end, int total) => 'bytes $start-$end/$total';

/// `Content-Range` for a status query: "how much do you have?".
String statusRange(int total) => 'bytes */$total';

/// The last byte (inclusive) of the chunk starting at [start].
int chunkEnd(int start, int chunkSize, int total) {
  final end = start + chunkSize;
  return (end > total ? total : end) - 1;
}

/// The server's chunk size, rounded down to a valid multiple of 256 KiB.
int validChunkSize(int requested) {
  final size = (requested ~/ kResumableQuantum) * kResumableQuantum;
  return size < kResumableQuantum ? kResumableQuantum : size;
}
