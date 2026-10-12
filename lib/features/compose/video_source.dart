import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

@immutable
class PickedFile {
  const PickedFile({required this.path, required this.name, this.mimeType});

  final String path;
  final String name;
  final String? mimeType;
}

/// Where a video can come from. Gallery picks go through the system photo
/// picker, so no storage permission is requested.
abstract interface class VideoSource {
  Future<PickedFile?> pickFromGallery();

  Future<PickedFile?> pickFromFiles();
}

class DeviceVideoSource implements VideoSource {
  DeviceVideoSource([ImagePicker? picker]) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<PickedFile?> pickFromGallery() async {
    final file = await _picker.pickVideo(source: ImageSource.gallery);
    if (file == null) return null;
    return PickedFile(
      path: file.path,
      name: file.name,
      mimeType: file.mimeType,
    );
  }

  @override
  Future<PickedFile?> pickFromFiles() async {
    final files = await FilePicker.pickFiles(type: FileType.video);
    final file = files.firstOrNull;
    final path = file?.path;
    if (file == null || path == null) return null;
    return PickedFile(path: path, name: file.name);
  }
}

final videoSourceProvider = Provider<VideoSource>((ref) => DeviceVideoSource());
