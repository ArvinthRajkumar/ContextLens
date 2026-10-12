import 'package:contextlens/core/theme/colors.dart';
import 'package:contextlens/features/report/models.dart';
import 'package:flutter/material.dart';

// The one place enums map to user-facing copy, icons and colors. Color is
// never shown alone: every use pairs it with the icon and label.

extension FlagCategoryPresentation on FlagCategory {
  String get label => switch (this) {
    FlagCategory.disclosure => 'Disclosure',
    FlagCategory.claims => 'Claims',
    FlagCategory.visuals => 'Visuals',
    FlagCategory.borrowed => 'Borrowed clips',
    FlagCategory.factcheck => 'Fact check',
    FlagCategory.unknown => 'Other',
  };

  IconData get icon => switch (this) {
    FlagCategory.disclosure => Icons.campaign_outlined,
    FlagCategory.claims => Icons.record_voice_over_outlined,
    FlagCategory.visuals => Icons.image_outlined,
    FlagCategory.borrowed => Icons.video_library_outlined,
    FlagCategory.factcheck => Icons.fact_check_outlined,
    FlagCategory.unknown => Icons.flag_outlined,
  };

  Color color(AppColors c) => switch (this) {
    FlagCategory.disclosure => c.disclosure,
    FlagCategory.claims => c.claims,
    FlagCategory.visuals => c.visuals,
    FlagCategory.borrowed => c.borrowed,
    FlagCategory.factcheck => c.factcheck,
    FlagCategory.unknown => c.insufficientEvidence,
  };
}

extension FactLabelPresentation on FactLabel {
  String get label => switch (this) {
    FactLabel.supported => 'Supported',
    FactLabel.contradicted => 'Contradicted',
    FactLabel.previouslyFactChecked => 'Previously fact-checked',
    FactLabel.insufficientEvidence => 'Insufficient evidence',
    FactLabel.unknown => 'Unrated',
  };

  IconData get icon => switch (this) {
    FactLabel.supported => Icons.check_circle_outline,
    FactLabel.contradicted => Icons.cancel_outlined,
    FactLabel.previouslyFactChecked => Icons.history,
    FactLabel.insufficientEvidence => Icons.help_outline,
    FactLabel.unknown => Icons.help_outline,
  };

  Color color(AppColors c) => switch (this) {
    FactLabel.supported => c.supported,
    FactLabel.contradicted => c.contradicted,
    FactLabel.previouslyFactChecked => c.previouslyFactChecked,
    FactLabel.insufficientEvidence => c.insufficientEvidence,
    FactLabel.unknown => c.insufficientEvidence,
  };
}

extension SeverityPresentation on Severity {
  String get label => switch (this) {
    Severity.high => 'High severity',
    Severity.medium => 'Medium severity',
    Severity.low => 'Low severity',
    Severity.unknown => 'Severity not set',
  };
}
