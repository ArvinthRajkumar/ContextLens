import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// An open upload, persisted so it can resume after the app restarts.
@immutable
class StoredUpload {
  const StoredUpload({
    required this.jobId,
    required this.sessionUri,
    required this.filePath,
    required this.totalBytes,
    required this.chunkSize,
    required this.createdAt,
  });

  factory StoredUpload.fromJson(Map<String, dynamic> json) => StoredUpload(
    jobId: json['jobId'] as String,
    sessionUri: json['sessionUri'] as String,
    filePath: json['filePath'] as String,
    totalBytes: json['totalBytes'] as int,
    chunkSize: json['chunkSize'] as int,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );

  final String jobId;

  /// Works like a bearer credential for the upload: kept in secure storage,
  /// never logged.
  final String sessionUri;
  final String filePath;
  final int totalBytes;
  final int chunkSize;
  final DateTime createdAt;

  /// Sessions live a week on GCS; we give up after a day.
  bool get isExpired =>
      DateTime.now().difference(createdAt) > const Duration(hours: 24);

  Map<String, dynamic> toJson() => {
    'jobId': jobId,
    'sessionUri': sessionUri,
    'filePath': filePath,
    'totalBytes': totalBytes,
    'chunkSize': chunkSize,
    'createdAt': createdAt.toIso8601String(),
  };
}

class UploadSessionStore {
  UploadSessionStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'upload.pending';

  final FlutterSecureStorage _storage;

  Future<void> save(StoredUpload upload) =>
      _storage.write(key: _key, value: jsonEncode(upload.toJson()));

  Future<StoredUpload?> load() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return null;
    try {
      return StoredUpload.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on Object {
      await clear();
      return null;
    }
  }

  Future<void> clear() => _storage.delete(key: _key);
}

final uploadSessionStoreProvider = Provider<UploadSessionStore>(
  (ref) => UploadSessionStore(),
);
