import 'dart:async';

import 'package:contextlens/core/theme/spacing.dart';
import 'package:contextlens/core/theme/typography.dart';
import 'package:contextlens/core/utils/formatters.dart';
import 'package:contextlens/features/upload/upload_controller.dart';
import 'package:contextlens/features/upload/upload_copy.dart';
import 'package:flutter/material.dart';

/// "12.4 MB of 86.0 MB", speed and time left, and a status line. Ticks
/// once a second while a retry countdown is showing.
class UploadStats extends StatefulWidget {
  const UploadStats({required this.upload, super.key});

  final UploadState upload;

  @override
  State<UploadStats> createState() => _UploadStatsState();
}

class _UploadStatsState extends State<UploadStats> {
  Timer? _countdown;

  @override
  void initState() {
    super.initState();
    _syncCountdown();
  }

  @override
  void didUpdateWidget(UploadStats old) {
    super.didUpdateWidget(old);
    _syncCountdown();
  }

  void _syncCountdown() {
    final retrying = widget.upload.phase == UploadPhase.retrying;
    if (retrying && _countdown == null) {
      _countdown = Timer.periodic(
        const Duration(seconds: 1),
        (_) => setState(() {}),
      );
    } else if (!retrying) {
      _countdown?.cancel();
      _countdown = null;
    }
  }

  @override
  void dispose() {
    _countdown?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final upload = widget.upload;
    final mono = AppTypography.monoOf(theme.textTheme.bodyMedium)
        .copyWith(color: scheme.onSurfaceVariant);
    final speed = upload.bytesPerSecond;
    final left = upload.timeLeft;
    final isProblem =
        upload.phase == UploadPhase.failed ||
        upload.phase == UploadPhase.retrying;

    return Column(
      children: [
        Text(
          '${formatBytes(upload.sentBytes)} of ${formatBytes(upload.totalBytes)}',
          style: mono,
        ),
        const SizedBox(height: Spacing.space1),
        Text(
          [
            if (speed != null && upload.phase == UploadPhase.uploading)
              formatSpeed(speed),
            if (left != null) formatTimeLeft(left),
          ].join('  ·  '),
          style: mono,
        ),
        const SizedBox(height: Spacing.space4),
        Semantics(
          liveRegion: true,
          child: Text(
            upload.status(DateTime.now()),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isProblem ? scheme.error : scheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
