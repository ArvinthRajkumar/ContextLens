import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:contextlens/core/api_client.dart';
import 'package:contextlens/core/log.dart';
import 'package:contextlens/features/auth/auth_repository.dart';
import 'package:contextlens/features/compose/declaration.dart';
import 'package:contextlens/features/report/job_repository.dart';
import 'package:contextlens/features/report/models.dart';
import 'package:contextlens/features/report/playback.dart';

/// Converts Firestore values to the JSON the models expect: Timestamps
/// become ISO strings, everything else passes through.
Object? normalizeFirestore(Object? value) => switch (value) {
  Timestamp() => value.toDate().toUtc().toIso8601String(),
  Map() => {
    for (final MapEntry(:key, :value) in value.entries)
      key as String: normalizeFirestore(value),
  },
  List() => [for (final item in value) normalizeFirestore(item)],
  _ => value,
};

/// A job document as a [Job], or null when it can't be parsed (a newer
/// schema we don't understand yet must not crash the list).
Job? jobFromDocument(String id, Map<String, dynamic> data) {
  try {
    final json = normalizeFirestore(data)! as Map<String, dynamic>;
    return Job.fromJson({...json, 'id': id});
  } on Object catch (error) {
    log('Skipping unreadable job: ${error.runtimeType}');
    return null;
  }
}

/// The declaration a job ran with, as the compose form's draft.
DeclarationDraft? declarationFromDocument(Map<String, dynamic>? data) {
  final raw = data?['declaration'];
  if (raw is! Map) return null;
  final clips = raw['borrowedClips'];
  return DeclarationDraft(
    caption: raw['caption'] as String? ?? '',
    isPaid: raw['isPaid'] as bool? ?? false,
    brand: raw['brandName'] as String? ?? '',
    category: ContentCategory.values.firstWhere(
      (c) => c.name == raw['category'],
      orElse: () => ContentCategory.general,
    ),
    clips: [
      if (clips is List)
        for (final (i, clip) in clips.indexed)
          if (clip is Map)
            ClipDraft(
              id: i,
              label: clip['label'] as String? ?? '',
              url: clip['url'] as String? ?? '',
            ),
    ],
  );
}

/// Jobs straight from Firestore `jobs/{jobId}` (read only, owner only, per
/// the security rules); playback goes through the API's signed URL.
class FirestoreJobRepository implements JobRepository {
  FirestoreJobRepository({
    required this._auth,
    required this._api,
    FirebaseFirestore? firestore,
  }) : _db = firestore ?? FirebaseFirestore.instance;

  final AuthRepository _auth;
  final ApiClient _api;
  final FirebaseFirestore _db;

  static const _recentLimit = 50;

  CollectionReference<Map<String, dynamic>> get _jobs => _db.collection('jobs');

  @override
  Stream<List<Job>> watchRecentJobs() async* {
    final uid = await _auth.ensureSignedIn();
    // Filtered by owner only, sorted here: an orderBy on another field would
    // need a composite index for a list this short.
    yield* _jobs
        .where('ownerUid', isEqualTo: uid)
        .limit(_recentLimit)
        .snapshots()
        .map((snapshot) {
          final jobs = [
            for (final doc in snapshot.docs)
              // An upload that was never submitted isn't a check yet.
              if (doc.data()['status'] != 'uploading')
                ?jobFromDocument(doc.id, doc.data()),
          ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return jobs;
        });
  }

  @override
  Future<Job?> getJob(String jobId) async {
    await _auth.ensureSignedIn();
    try {
      final doc = await _jobs.doc(jobId).get();
      final data = doc.data();
      return data == null ? null : jobFromDocument(doc.id, data);
    } on FirebaseException catch (e) {
      // Someone else's job, or one already deleted: both read as missing.
      if (e.code == 'permission-denied' || e.code == 'not-found') return null;
      rethrow;
    }
  }

  @override
  Stream<Job> watchJob(String jobId) async* {
    await _auth.ensureSignedIn();
    yield* _jobs
        .doc(jobId)
        .snapshots()
        .where((doc) => doc.exists)
        .map((doc) => jobFromDocument(doc.id, doc.data()!))
        .where((job) => job != null)
        .cast<Job>();
  }

  @override
  Future<PlaybackSource> playback(String jobId) async {
    final body = await _api.get('/v1/jobs/$jobId/video-url');
    return NetworkPlayback(Uri.parse(body['url'] as String));
  }

  @override
  Future<DeclarationDraft?> declaration(String jobId) async {
    await _auth.ensureSignedIn();
    final doc = await _jobs.doc(jobId).get();
    return declarationFromDocument(doc.data());
  }
}
