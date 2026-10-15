import 'package:contextlens/core/api_client.dart';
import 'package:contextlens/core/config.dart';
import 'package:contextlens/core/log.dart';
import 'package:contextlens/features/compose/declaration.dart';
import 'package:contextlens/features/samples/sample.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Where Try a sample videos come from.
abstract interface class SampleRepository {
  Future<List<Sample>> list();

  /// The thumbnail's bytes, for the preview card and drafts. Null when it
  /// can't be fetched: the card then shows the placeholder.
  Future<Uint8List?> thumbnail(Sample sample);
}

class HttpSampleRepository implements SampleRepository {
  HttpSampleRepository({required this._api, Dio? dio}) : _dio = dio ?? Dio();

  final ApiClient _api;
  final Dio _dio;

  @override
  Future<List<Sample>> list() async {
    final body = await _api.get('/v1/samples');
    return [
      for (final raw
          in (body['samples'] as List? ?? const [])
              .cast<Map<String, dynamic>>())
        Sample.fromJson(raw),
    ];
  }

  @override
  Future<Uint8List?> thumbnail(Sample sample) async {
    final url = sample.thumbnailUrl;
    if (url == null) return null;
    try {
      final response = await _dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      final data = response.data;
      return data == null ? null : Uint8List.fromList(data);
    } on DioException catch (error) {
      log('Sample thumbnail unavailable: ${error.type.name}');
      return null;
    }
  }
}

/// Mock mode: the same kinds of samples, without media.
class FakeSampleRepository implements SampleRepository {
  const FakeSampleRepository([this.samples = fakeSamples]);

  final List<Sample> samples;

  @override
  Future<List<Sample>> list() async => samples;

  @override
  Future<Uint8List?> thumbnail(Sample sample) async => null;
}

const fakeSamples = [
  Sample(
    id: 'glucoleaf',
    title: 'Gifted supplement with health claims',
    hint: 'Gifted product, code on screen, #ad buried, cure claims',
    language: 'English',
    duration: Duration(milliseconds: 34720),
    sizeBytes: 1192624,
    width: 720,
    height: 1280,
    declaration: SampleDeclaration(
      caption:
          'My morning routine with GlucoLeaf! Use code GLUCO15 '
          '#morning #health #wellness #routine #ad',
      isPaid: true,
      brand: 'GlucoLeaf',
      category: ContentCategory.health,
    ),
  ),
  Sample(
    id: 'vitamind',
    title: "Clip that drops the doctor's warning",
    hint:
        "Reel cut from a 2 minute interview, stops before the doctor's "
        'condition',
    language: 'English',
    duration: Duration(milliseconds: 23110),
    sizeBytes: 499743,
    width: 720,
    height: 1280,
    declaration: SampleDeclaration(
      caption: 'Doctor says everyone needs vitamin D every day #health',
      isPaid: false,
      brand: '',
      category: ContentCategory.health,
    ),
    clip: SampleClip(
      id: 'vitamind_source',
      label: 'Morning Health Chat interview',
    ),
  ),
];

final sampleRepositoryProvider = Provider<SampleRepository>(
  (ref) => switch (AppConfig.backend) {
    BackendMode.mock => const FakeSampleRepository(),
    BackendMode.real => HttpSampleRepository(api: ref.watch(apiClientProvider)),
  },
);

/// The gallery's list. Signed URLs expire, so it refetches each time the
/// sheet opens (the provider is disposed with it).
final samplesProvider = FutureProvider.autoDispose<List<Sample>>(
  (ref) => ref.watch(sampleRepositoryProvider).list(),
);
