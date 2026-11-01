// lib/data/network/error_handler.dart

class ErrorHandler {
  ErrorHandler._();

  static String message(int code, String serverMessage) => switch (code) {
    901 => 'Phiên đăng nhập hết hạn, vui lòng đăng nhập lại',
    902 => 'Bạn không có quyền thực hiện thao tác này',
    903 => 'Dữ liệu không hợp lệ, vui lòng kiểm tra lại',
    904 => 'Không tìm thấy dữ liệu yêu cầu',
    905 => 'Dữ liệu đã tồn tại trong hệ thống',
    906 => 'Dữ liệu nhập vào không đúng định dạng',
    907 => 'Quá nhiều yêu cầu, vui lòng thử lại sau',
    921 => 'Lỗi máy chủ, vui lòng thử lại sau',
    922 => 'Hệ thống đang bảo trì, vui lòng thử lại sau',
    923 => 'Phiên đăng nhập hết hạn, vui lòng đăng nhập lại',
    941 => 'Sai mật khẩu, vui lòng kiểm tra lại',
    942 => 'Tài khoản của bạn đã bị khóa',
    943 => 'Email này đã được đăng ký',
    944 => 'Số điện thoại này đã được đăng ký',
    945 => 'Số dư tài khoản không đủ',
    946 => 'Giao dịch thất bại',
    947 => 'Sản phẩm đã hết hàng',
    948 => 'Mã OTP không hợp lệ',
    949 => 'Mã OTP đã hết hạn',
    999 => serverMessage.isNotEmpty ? serverMessage : 'Lỗi kết nối',
    _   => serverMessage.isNotEmpty
        ? serverMessage
        : 'Đã có lỗi xảy ra, vui lòng thử lại',
  };
}
