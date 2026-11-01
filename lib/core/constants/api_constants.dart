// lib/core/constants/api_constants.dart

class ApiConstants {
  ApiConstants._();

  static const String baseUrl = 'https://api.original-taste.vn';
  // static const String baseUrl = 'http://192.168.100.79:9009';
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);
  static const Duration sendTimeout    = Duration(seconds: 60);

  // ── Auth ──────────────────────────────────────────────────────
  static const String login        = '/api/auth/login';
  static const String logout       = '/api/auth/logout';
  static const String register     = '/api/auth/register';
  static const String me           = '/api/validating/me';
  static const String versionCheck = '/api/auth/version-check';
  static const String images       = '/api/auth';

  // ── Upload — đúng theo FileUploadController ───────────────────
  static const String uploadCategory   = '/api/upload/categories/upload-image';
  static const String uploadProduct    = '/api/upload/product-image';
  static const String uploadPosProduct = '/api/upload/pos-product-image';
  static const String uploadVariant    = '/api/upload/variant-image';
  static const String uploadIngredient = '/api/upload/ingredient-image';

  static const String sellerBase     = '/api/seller';
  static const String superAdminBase = '/api/superadmin';
  static const String adminBase = '/api/admin';

  // ── POS ───────────────────────────────────────────────────────
  static const String posBase = '/api/pos';

  // ── Response codes ────────────────────────────────────────────
  static const int codeSuccess    = 900;
  static const int codeExpired    = 923;
  static const int codeUnauth     = 901;
  static const int codeForbidden  = 902;
  static const int codeValidation = 903;
  static const int codeNotFound   = 904;
  static const int codeDuplicate  = 905;
  static const int codeFormat     = 906;
  static const int codeRateLimit  = 907;
  static const int codeServer     = 921;
  static const int codeMaintain   = 922;
  static const int codeDbError    = 923;
  static const int codeWrongPass  = 941;
  static const int codeLocked     = 942;
  static const int codeEmailDup   = 943;
  static const int codePhoneDup   = 944;
  static const int codeBalance    = 945;
  static const int codeTxFailed   = 946;
  static const int codeOutOfStock = 947;
  static const int codeOtpInvalid = 948;
  static const int codeOtpExpired = 949;
  static const int codeLocal      = 999;
}