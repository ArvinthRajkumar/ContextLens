import 'package:contextlens/core/app_check.dart';
import 'package:contextlens/core/config.dart';
import 'package:contextlens/features/auth/auth_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A failed API call, decoded from the `{"error": {...}}` shape.
class ApiException implements Exception {
  const ApiException({
    required this.code,
    required this.message,
    required this.retryable,
    this.status,
  });

  /// Network failures before any response.
  factory ApiException.network() => const ApiException(
    code: 'network',
    message: 'No connection.',
    retryable: true,
  );

  factory ApiException.from(DioException error) {
    final response = error.response;
    if (response == null) return ApiException.network();
    final body = response.data;
    final detail = body is Map && body['error'] is Map
        ? body['error'] as Map
        : const {};
    final status = response.statusCode ?? 0;
    return ApiException(
      code: detail['code'] as String? ?? 'http_$status',
      message: detail['message'] as String? ?? 'Something went wrong.',
      retryable:
          detail['retryable'] as bool? ??
          (status >= 500 || status == 408 || status == 429),
      status: status,
    );
  }

  final String code;
  final String message;
  final bool retryable;
  final int? status;

  @override
  String toString() => 'ApiException($code, $status)';
}

/// The ContextLens API. Every request carries a Firebase ID token, and an
/// App Check token when [appCheckToken] gives one. Nothing here logs URLs,
/// headers or bodies.
class ApiClient {
  ApiClient({required this._auth, this._appCheckToken, Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: AppConfig.apiBaseUrl,
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 30),
              contentType: Headers.jsonContentType,
              responseType: ResponseType.json,
            ),
          ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          try {
            options.headers['Authorization'] =
                'Bearer ${await _auth.idToken()}';
            final appCheck = await _appCheckToken?.call();
            if (appCheck != null) {
              options.headers['X-Firebase-AppCheck'] = appCheck;
            }
            handler.next(options);
          } on Object catch (error) {
            handler.reject(DioException(requestOptions: options, error: error));
          }
        },
      ),
    );
  }

  final AuthRepository _auth;
  final Future<String?> Function()? _appCheckToken;
  final Dio _dio;

  Future<Map<String, dynamic>> post(String path, Object? body) =>
      _send(() => _dio.post<Map<String, dynamic>>(path, data: body));

  Future<Map<String, dynamic>> get(String path) =>
      _send(() => _dio.get<Map<String, dynamic>>(path));

  Future<void> delete(String path) => _send(() => _dio.delete<void>(path));

  Future<Map<String, dynamic>> _send<T>(
    Future<Response<T>> Function() call,
  ) async {
    try {
      final response = await call();
      final data = response.data;
      return data is Map<String, dynamic> ? data : const {};
    } on DioException catch (error) {
      throw ApiException.from(error);
    }
  }
}

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(
    auth: ref.watch(authRepositoryProvider),
    appCheckToken: AppConfig.isMock ? null : appCheckToken,
  ),
);
