// lib/data/network/dio_client.dart

import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../core/constants/api_constants.dart';
import '../storage/session_storage.dart';
import 'api_result.dart';

typedef OnTokenExpiredCallback = Future<void> Function();

class DioClient {
  DioClient._();
  static final DioClient _instance = DioClient._();
  static DioClient get instance => _instance;

  late final Dio _dio;
  OnTokenExpiredCallback? _onTokenExpired;

  void init() {
    _dio = Dio(BaseOptions(
      baseUrl:        ApiConstants.baseUrl,
      connectTimeout: ApiConstants.connectTimeout,
      receiveTimeout: ApiConstants.receiveTimeout,
      sendTimeout:    ApiConstants.sendTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept':       'application/json',
      },
    ));

    _dio.interceptors.addAll([
      _AuthInterceptor(),
      _TokenExpiredInterceptor(this),
      if (kDebugMode) _LogInterceptor(),
    ]);
  }

  void setOnTokenExpired(OnTokenExpiredCallback cb) {
    _onTokenExpired = cb;
  }

  void addInterceptor(Interceptor interceptor) {
    _dio.interceptors.add(interceptor);
  }

  Future<void> _handleTokenExpired() async {
    await _onTokenExpired?.call();
  }

  // ── UPLOAD MULTIPLE FILES (nhiều file cùng 1 field name) ──────────────────
  /// Gửi nhiều file lên cùng 1 field (ví dụ: "files"), kèm extra text fields.
  /// Dùng cho endpoint nhận `@RequestParam("files") List<MultipartFile>`.
  ///
  /// Ví dụ:
  /// ```dart
  /// await DioClient.instance.uploadMultipartFileList(
  ///   '/api/pos/shifts/images/close',
  ///   files:       myFiles,
  ///   fileField:   'files',
  ///   extraFields: {'shiftId': '42'},
  ///   sendTimeout:    const Duration(seconds: 120),
  ///   receiveTimeout: const Duration(seconds: 300),
  ///   fromData: (d) => ShiftOcrResult.fromJson(d as Map<String, dynamic>),
  /// );
  /// ```
  Future<ApiResult<T>> uploadMultipartFileList<T>(
      String path, {
        required List<File> files,
        String fileField = 'files',
        Map<String, String> extraFields = const {},
        bool requireAuth = true,
        T? Function(dynamic)? fromData,
        CancelToken? cancelToken,
        Duration sendTimeout    = const Duration(seconds: 120),
        Duration receiveTimeout = const Duration(seconds: 300),
      }) async {
    try {
      // Mỗi file là 1 entry riêng biệt cùng key — Spring nhận List<MultipartFile>
      final List<MapEntry<String, MultipartFile>> fileEntries = [];
      for (final file in files) {
        fileEntries.add(MapEntry(
          fileField,
          await MultipartFile.fromFile(
            file.path,
            filename: file.path.split('/').last,
          ),
        ));
      }

      // FormData.fromMap không hỗ trợ nhiều entry cùng key,
      // nên dùng constructor files + fields riêng
      final formData = FormData()
        ..files.addAll(fileEntries)
        ..fields.addAll(
            extraFields.entries.map((e) => MapEntry(e.key, e.value)));

      final res = await _dio.post(
        path,
        data: formData,
        options: Options(
          contentType:    'multipart/form-data',
          sendTimeout:    sendTimeout,
          receiveTimeout: receiveTimeout,
          extra: {'requireAuth': requireAuth},
        ),
        cancelToken: cancelToken,
      );
      return _parse(res, fromData);
    } on DioException catch (e) {
      return _handleDioError(e);
    }
  }

  // ── EXISTING METHODS (giữ nguyên) ─────────────────────────────────────────

  Future<ApiResult<T>> postMultipartFiles<T>(
      String path, {
        required Map<String, String> fields,
        List<File> fileList = const [],
        String fileFieldName = 'images',
        bool requireAuth = true,
        T? Function(dynamic)? fromData,
        CancelToken? cancelToken,
      }) async {
    try {
      final map = <String, dynamic>{...fields};
      if (fileList.isNotEmpty) {
        map[fileFieldName] = [
          for (final f in fileList)
            await MultipartFile.fromFile(
              f.path,
              filename: f.path.split('/').last,
            ),
        ];
      }
      final formData = FormData.fromMap(map);
      final res = await _dio.post(
        path,
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          extra: {'requireAuth': requireAuth},
        ),
        cancelToken: cancelToken,
      );
      return _parse(res, fromData);
    } on DioException catch (e) {
      return _handleDioError(e);
    }
  }

  Future<ApiResult<T>> uploadMultipart<T>(
      String path, {
        required String filePath,
        String fieldName = 'file',
        Map<String, String> extraFields = const {},
        T? Function(dynamic)? fromData,
        CancelToken? cancelToken,
        Duration sendTimeout    = const Duration(seconds: 120),
        Duration receiveTimeout = const Duration(seconds: 120),
      }) async {
    try {
      final map = <String, dynamic>{
        fieldName: await MultipartFile.fromFile(
          filePath,
          filename: filePath.split('/').last,
        ),
        ...extraFields,
      };
      final formData = FormData.fromMap(map);
      final res = await _dio.post(
        path,
        data: formData,
        options: Options(
          contentType:    'multipart/form-data',
          sendTimeout:    sendTimeout,
          receiveTimeout: receiveTimeout,
          extra: {'requireAuth': true},
        ),
        cancelToken: cancelToken,
      );
      return _parse(res, fromData);
    } on DioException catch (e) {
      return _handleDioError(e);
    }
  }

  // ── GET ───────────────────────────────────────────────────────────────────
  Future<ApiResult<T>> get<T>(
      String path, {
        Map<String, dynamic>? queryParams,
        bool requireAuth = true,
        T? Function(dynamic)? fromData,
        CancelToken? cancelToken,
      }) async {
    try {
      final res = await _dio.get(
        path,
        queryParameters: queryParams,
        options: Options(extra: {'requireAuth': requireAuth}),
        cancelToken: cancelToken,
      );
      return _parse(res, fromData);
    } on DioException catch (e) {
      return _handleDioError(e);
    }
  }

  // ── POST ──────────────────────────────────────────────────────────────────
  Future<ApiResult<T>> post<T>(
      String path, {
        Map<String, dynamic>? body,
        bool requireAuth = true,
        T? Function(dynamic)? fromData,
        CancelToken? cancelToken,
      }) async {
    try {
      final res = await _dio.post(
        path,
        data: body,
        options: Options(extra: {'requireAuth': requireAuth}),
        cancelToken: cancelToken,
      );
      return _parse(res, fromData);
    } on DioException catch (e) {
      return _handleDioError(e);
    }
  }

  // ── PUT ───────────────────────────────────────────────────────────────────
  Future<ApiResult<T>> put<T>(
      String path, {
        required Map<String, dynamic> body,
        bool requireAuth = true,
        T? Function(dynamic)? fromData,
        CancelToken? cancelToken,
      }) async {
    try {
      final res = await _dio.put(
        path,
        data: body,
        options: Options(extra: {'requireAuth': requireAuth}),
        cancelToken: cancelToken,
      );
      return _parse(res, fromData);
    } on DioException catch (e) {
      return _handleDioError(e);
    }
  }

  // ── PATCH ─────────────────────────────────────────────────────────────────
  Future<ApiResult<T>> patch<T>(
      String path, {
        required Map<String, dynamic> body,
        bool requireAuth = true,
        T? Function(dynamic)? fromData,
        CancelToken? cancelToken,
      }) async {
    try {
      final res = await _dio.patch(
        path,
        data: body,
        options: Options(extra: {'requireAuth': requireAuth}),
        cancelToken: cancelToken,
      );
      return _parse(res, fromData);
    } on DioException catch (e) {
      return _handleDioError(e);
    }
  }

  // ── DELETE ────────────────────────────────────────────────────────────────
  Future<ApiResult<T>> delete<T>(
      String path, {
        bool requireAuth = true,
        T? Function(dynamic)? fromData,
        CancelToken? cancelToken,
      }) async {
    try {
      final res = await _dio.delete(
        path,
        options: Options(extra: {'requireAuth': requireAuth}),
        cancelToken: cancelToken,
      );
      return _parse(res, fromData);
    } on DioException catch (e) {
      return _handleDioError(e);
    }
  }

  // ── UPLOAD (single file multipart) ────────────────────────────────────────
  Future<ApiResult<T>> upload<T>(
      String path, {
        required String filePath,
        String fieldName = 'image',
        T? Function(dynamic)? fromData,
        CancelToken? cancelToken,
      }) async {
    try {
      final formData = FormData.fromMap({
        fieldName: await MultipartFile.fromFile(filePath),
      });
      final res = await _dio.post(
        path,
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          extra: {'requireAuth': true},
        ),
        cancelToken: cancelToken,
      );
      return _parse(res, fromData);
    } on DioException catch (e) {
      return _handleDioError(e);
    }
  }

  // ── POST MULTIPART (JSON + optional file) ─────────────────────────────────
  Future<ApiResult<T>> postMultipart<T>(
      String path, {
        required Map<String, String> fields,
        Map<String, File>? files,
        bool requireAuth = true,
        T? Function(dynamic)? fromData,
        CancelToken? cancelToken,
      }) async {
    try {
      final map = <String, dynamic>{...fields};
      if (files != null) {
        for (final entry in files.entries) {
          map[entry.key] = await MultipartFile.fromFile(
            entry.value.path,
            filename: entry.value.path.split('/').last,
          );
        }
      }
      final formData = FormData.fromMap(map);
      final res = await _dio.post(
        path,
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          extra: {'requireAuth': requireAuth},
        ),
        cancelToken: cancelToken,
      );
      return _parse(res, fromData);
    } on DioException catch (e) {
      return _handleDioError(e);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  ApiResult<T> _parse<T>(Response res, T? Function(dynamic)? fromData) {
    final json = res.data;

    if (json is! Map<String, dynamic>) {
      return ApiResult.localError('Dữ liệu trả về không hợp lệ');
    }

    final result = ApiResult.fromResponse(
      json:       json,
      httpStatus: res.statusCode ?? 0,
      fromData:   fromData,
    );

    if (result.isTokenExpired) {
      _handleTokenExpired();
    }

    return result;
  }

  ApiResult<T> _handleDioError<T>(DioException e) {
    if (e.type == DioExceptionType.cancel) {
      return ApiResult.localError('Yêu cầu đã bị hủy');
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return ApiResult.localError('Kết nối quá thời gian, vui lòng thử lại');
    }
    if (e.error is SocketException) {
      return ApiResult.localError('Không có kết nối mạng');
    }

    final status = e.response?.statusCode;
    final data   = e.response?.data;

    // ── Token hết hạn ───────────────────────────────────────────────
    // Backend trả body {code:923}. Bắt theo bodyCode==923 (mọi status),
    // và giữ 401 làm lưới an toàn. Không bắt 403 trần (permission).
    final bodyCode = (data is Map && data['code'] is int)
        ? data['code'] as int : null;
    if (status == 401 || bodyCode == 923) {
      _handleTokenExpired();
      return ApiResult(
        code:       923,
        message:    'Phiên đăng nhập đã hết hạn',
        httpStatus: status,
        isSuccess:  false,
      );
    }

    if (data is Map<String, dynamic>) {
      final result = ApiResult.fromResponse(
        json:       data,
        httpStatus: status ?? 0,
      );
      if (result.isTokenExpired) _handleTokenExpired();
      return result as ApiResult<T>;
    }

    return ApiResult.localError('Lỗi kết nối: ${e.message}');
  }
}

// ── Interceptor: inject Authorization header ──────────────────────────────
class _AuthInterceptor extends Interceptor {
  @override
  Future<void> onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    final requireAuth = options.extra['requireAuth'] as bool? ?? true;
    if (requireAuth) {
      final token = await SessionStorage.getAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }
}

// ── Interceptor: catch token expired in response ──────────────────────────
class _TokenExpiredInterceptor extends Interceptor {
  final DioClient _client;
  _TokenExpiredInterceptor(this._client);

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final data = response.data;
    if (data is Map<String, dynamic>) {
      final code = data['code'] as int?;
      if (code == 923) {
        _client._handleTokenExpired();
      }
    }
    handler.next(response);
  }
}

// ── Interceptor: debug log ────────────────────────────────────────────────
class _LogInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    handler.next(err);
  }
}