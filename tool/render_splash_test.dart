import 'dart:io';
import 'dart:ui' as ui;

import 'package:contextlens/core/theme/colors.dart';
import 'package:contextlens/core/widgets/lens_mark.dart';
import 'package:contextlens/features/splash/splash_page.dart';
import 'package:flutter_test/flutter_test.dart';

// Renders the native splash images from the same painter the intro uses, so
// the native splash hands off to the Flutter intro without a jump.
// Run: flutter test tool/render_splash_test.dart
// Then: dart run flutter_native_splash:create

/// flutter_native_splash treats source images as 4x.
const double _scale = 4;

Future<void> _render(String path, {required double canvas}) async {
  const mark = SplashPage.markSize * _scale;
  final recorder = ui.PictureRecorder();
  final c = ui.Canvas(recorder)
    ..translate((canvas - mark) / 2, (canvas - mark) / 2);
  LensMarkPainter(color: AppPalette.dark.primary)
      .paint(c, const ui.Size.square(mark));
  final image = await recorder.endRecording().toImage(
    canvas.toInt(),
    canvas.toInt(),
  );
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  test('render native splash images', () async {
    await _render('assets/splash/lens_mark.png', canvas: 384);
    // Android 12 icons are 1152px with the visible area inside a 768px
    // circle; the mark keeps its 96dp size centered within it.
    await _render('assets/splash/lens_mark_android12.png', canvas: 1152);
  });
}
