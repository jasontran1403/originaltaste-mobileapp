// lib/data/network/api_result.dart

/// Wrapper cho mọi response từ server
class ApiResult<T> {
  final int code;
  final T? data;
  final String message;
  final int? httpStatus;
  final bool isSuccess;

  const ApiResult({
    required this.code,
    this.data,
    required this.message,
    this.httpStatus,
    required this.isSuccess,
  });

  /// Tạo từ JSON response body + httpStatus
  factory ApiResult.fromResponse({
    required Map<String, dynamic> json,
    required int httpStatus,
    T? Function(dynamic)? fromData,
  }) {
    final code    = json['code'] as int? ?? httpStatus;
    final message = json['message'] as String? ?? '';
    final raw     = json['data'];
    final success = httpStatus == 200 || httpStatus == 201;

    return ApiResult(
      code:       code,
      data:       (fromData != null && raw != null) ? fromData(raw) : null,
      message:    message,
      httpStatus: httpStatus,
      isSuccess:  success,
    );
  }

  /// Lỗi local (network, parse, timeout...)
  factory ApiResult.localError(String message) => ApiResult(
    code:      999,
    message:   message,
    httpStatus: null,
    isSuccess: false,
  );

  /// Token hết hạn / không hợp lệ.
  /// Backend đã chuẩn hoá: mọi API trả body {code:923} khi JWT hết hạn.
  /// Vẫn giữ httpStatus==401 làm lưới an toàn cho trường hợp filter chỉ trả
  /// 401 trần. KHÔNG bắt 403 để tránh nhầm lỗi "không đủ quyền" thành hết phiên
  /// (lỗi 403 do hết hạn — nếu có — vẫn kèm code 923 nên vẫn bắt được).
  bool get isTokenExpired => code == 923 || httpStatus == 401;
}