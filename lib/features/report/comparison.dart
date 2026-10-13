import 'package:contextlens/features/report/models.dart';

/// Compares two runs of the same video by flag fingerprint. Only issues
/// count; checked claims are never resolved or new.
RunComparison compareRuns(Job previous, Job current) {
  final before = {for (final flag in previous.issues) flag.fingerprint};
  final after = {for (final flag in current.issues) flag.fingerprint};
  return RunComparison(
    previousJobId: previous.id,
    resolved: before.difference(after).length,
    remaining: before.intersection(after).length,
    newCount: after.difference(before).length,
  );
}

/// Fingerprints of the previous run's issues that this run no longer has.
Set<String> resolvedFingerprints(Job previous, Job current) {
  final after = {for (final flag in current.issues) flag.fingerprint};
  return {
    for (final flag in previous.issues)
      if (!after.contains(flag.fingerprint)) flag.fingerprint,
  };
}
