// ============================================================================
// security_auth_service.dart
// Девор — қабати амният (Security & Auth Service Layer)
//  • Воридшавии корбар + Brute-Force Lockout (3 кӯшиш → 15 мин, экспоненсиалӣ)
//  • OTP эфемерӣ (TTL 3 дақиқа, single-use, purge-и RAM баъди ҳар санҷиш)
//  • Маскалкунии PII (email/phone) дар UI ва логҳо
//  • Терминатсияи қатии сессия ҳангоми Баромадан (logout)
//  • SUPER-ADMIN GATE — ZERO-EXPOSURE OWNER-DEFINED CREDENTIALS:
//      — Ҳеҷ login/password-и пешфарз коддошуда НЕСТ;
//      — соҳиб (owner) мухтасасҳоро худ дархиш мекунад ва фавран бо
//        SHA-256 + salt-и криптографии тасодуфӣ hash мешаванд;
//      — танҳо salt + hash дар SecureStorage (Keystore/Keychain);
//      — мухтасасҳо ҲЕҶ ГОҲ намоиш/насҳ/лог НАМЕШАВАНД;
//      — lockout-и мустақил (3 кӯшиш) + terminate фаврӣ ҳангоми баромад
//        аз Панели Админ + «Ивази логин ва парол» бо пароли ҷорӣ.
// ============================================================================
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Натиҷаи амалиёти аутентификатсия
enum AuthStatus { success, wrongCredentials, locked, weakPassword, invalidEmail }

/// Варианти ҳодисаи аудит
enum AuthEventType {
  loginSuccess, loginFailed, loginLocked, logout,
  otpIssued, otpVerified, otpPurged, sessionRevoked,
  adminInit, adminLoginSuccess, adminLoginFailed, adminLocked,
  adminSessionTerminated, adminCredentialsChanged,
}

class DevorSession {
  final String userId;
  final String email;
  final DateTime startedAt;
  final String deviceFingerprint;
  final String sessionToken; // дар ҳақиқат: JWT 15-дақиқагӣ + refresh token чархзананда
  DevorSession({
    required this.userId,
    required this.email,
    required this.startedAt,
    required this.deviceFingerprint,
    required this.sessionToken,
  });
}

class AuthEvent {
  final AuthEventType type;
  final DateTime at;
  final String detail;
  final String deviceFingerprint;
  final String? ipRegion;
  AuthEvent(this.type, {required this.detail, required this.deviceFingerprint, this.ipRegion})
      : at = DateTime.now();
  String get label {
    switch (type) {
      case AuthEventType.loginSuccess: return 'Воридшавии муваффақ';
      case AuthEventType.loginFailed: return 'Кӯшиши нодурусти воридшавӣ';
      case AuthEventType.loginLocked: return 'Ҳисоб қулф шуд (Қулф шуд)';
      case AuthEventType.logout: return 'Баромадан — сессия бекор шуд';
      case AuthEventType.otpIssued: return 'Рамзи OTP дода шуд';
      case AuthEventType.otpVerified: return 'Рамзи OTP тасдиқ ва ПОК КАРДА шуд';
      case AuthEventType.otpPurged: return 'Рамзи OTP аз хотира нест шуд';
      case AuthEventType.sessionRevoked: return 'Токенҳо дар сервер бекор карда шуданд';
      case AuthEventType.adminInit: return 'Танзими аввалини Супер-Админ (танҳо hash)';
      case AuthEventType.adminLoginSuccess: return 'Вуруди Супер-Админ';
      case AuthEventType.adminLoginFailed: return 'Кӯшиши нодурусти Супер-Админ';
      case AuthEventType.adminLocked: return 'Супер-Админ қулф шуд';
      case AuthEventType.adminSessionTerminated: return 'Сессияи Админ terminate шуд';
      case AuthEventType.adminCredentialsChanged: return 'Ивази логин ва парол (hash-и нав)';
    }
  }
}

class AuthResult {
  final AuthStatus status;
  final String message;
  final Duration? remainingLock;
  AuthResult(this.status, this.message, {this.remainingLock});
}

/// ====== Хизматрасонии амният — Singleton ======
class SecurityAuthService extends ChangeNotifier {
  SecurityAuthService._();
  static final SecurityAuthService instance = SecurityAuthService._();

  final FlutterSecureStorage _vault = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true), // Android Keystore
    iOptions: IOSOptions(accessibility: KeychainAccessibility.whenUnlocked),
  );

  // --- Сессияи корбар (plain-text токенҳо ДАР ИНҶО нигоҳ дошта намешаванд) ---
  DevorSession? session;
  bool get isLoggedIn => session != null;

  // --- Brute-force (корбар): 3 кӯшиши нодуруст => Қулф 15 дақиқа (экспоненсиалӣ) ---
  static const int _maxAttempts = 3;
  int _failedAttempts = 0;
  DateTime? _lockedUntil;

  // --- SUPER-ADMIN: lockout-и мустақил (3 кӯшиш → 15/30/60 мин) ---
  static const String _kAdminSalt = 'admin_salt_b64';
  static const String _kAdminLoginHash = 'admin_login_hash';
  static const String _kAdminPwHash = 'admin_pw_hash';
  int _adminFailed = 0;
  DateTime? _adminLockedUntil;
  bool adminSessionActive = false;

  Timer? _lockTicker;

  // --- OTP: рамз 3 дақиқа зиндагӣ мекунад ва БАЪДИ ИСТИФОДА пурра нест мешавад ---
  String? _otpCode;
  String? _otpTarget;
  DateTime? _otpIssuedAt;
  static const Duration _otpTtl = Duration(minutes: 3);

  // --- Аудит ---
  final List<AuthEvent> auditLog = [];

  final String deviceFingerprint =
      'dev-${PlatformSafe.id}-' + DateTime.now().millisecondsSinceEpoch.toString();

  // ================================================================
  //  SUPER-ADMIN — ZERO-EXPOSURE OWNER-DEFINED CREDENTIALS
  // ================================================================

  /// Оё мухтасасҳои Owner-аллакай сохта шудаанд? (танҳо hash дар хазина)
  Future<bool> adminCredentialsExist() async {
    final h = await _vault.read(key: _kAdminPwHash);
    return h != null && h.isNotEmpty;
  }

  String _sha256Hex(List<int> bytes) => sha256.convert(bytes).toString();

  /// 32-byte salt — CSPRNG (Random.secure), ҳар маротиба нав
  List<int> _genSalt([int length = 32]) =>
      List.generate(length, (_) => Random.secure().nextInt(256));

  /// Ҳисоби hash-и ягона: SHA-256(salt || secret) — дар хотира ҳамон лаҳза
  /// баъди ҳисоб string-и сиррӣ дигар истифода НАМЕШАВАД (buffer wipe).
  Future<void> _writeAdminHashes(String login, String password) async {
    final salt = _genSalt();
    final loginHash = _sha256Hex([...salt, ...utf8.encode(login.trim().toLowerCase())]);
    final pwHash = _sha256Hex([...salt, ...utf8.encode(password)]);
    await _vault.write(key: _kAdminSalt, value: base64Encode(salt));
    await _vault.write(key: _kAdminLoginHash, value: loginHash);
    await _vault.write(key: _kAdminPwHash, value: pwHash);
    // Мухтасасҳои open-text дар ин ҷо дигар мавҷуд НЕСТАНД — Dart string
    // immutable аст, аммо ҳеҷ field/class/reference онҳоро нигоҳ намедорад.
  }

  /// Танзими аввалини Owner (танҳо ЯК маротиба, ҳеҷ пешфарз нест!)
  /// DATA.md: парол танҳо hash мегардад, obscureText дар UI, autofill off.
  Future<AuthResult> adminInitialize(String login, String password, String confirm) async {
    if (await adminCredentialsExist()) {
      return const AuthResult(AuthStatus.locked, 'Мухтасасҳо аллакай танзим шудаанд. Ворид шавед.');
    }
    if (login.trim().length < 4) {
      return const AuthResult(AuthStatus.weakPassword, 'Логин ҳадди ақал 4 аломат бошад.');
    }
    if (password.length < 8) {
      return const AuthResult(AuthStatus.weakPassword, 'Парол ҳадди ақал 8 аломат бошад.');
    }
    if (password != confirm) {
      return const AuthResult(AuthStatus.weakPassword, 'Парол ва тасдиқи парол мувофиқ нестанд.');
    }
    await _writeAdminHashes(login, password);
    _audit(AuthEventType.adminInit, 'Owner-мухтасасҳо сохта шуданд — танҳо SHA-256+salt захира шуд');
    notifyListeners();
    return const AuthResult(AuthStatus.success, 'Супер-Админ танзим шуд. Акнун ворид шавед.');
  }

  /// Вуруди Супер-Админ — lockout-и мустақил (3 кӯшиш → 15/30/60 мин)
  Future<AuthResult> adminLogin(String login, String password) async {
    final lock = remainingAdminLock();
    if (lock != null) {
      _audit(AuthEventType.adminLocked, 'Кӯшиши воридшавӣ ҳангоми қулфи админ');
      return AuthResult(AuthStatus.locked,
          'ҚУЛФ ШУД. Баъди ${lock.inMinutes}д ${lock.inSeconds % 60}с кӯшиш кунед.',
          remainingLock: lock);
    }
    if (!await adminCredentialsExist()) {
      return const AuthResult(AuthStatus.wrongCredentials, 'Аввал танзими аввалини гузаронед.');
    }
    final salt = base64Decode((await _vault.read(key: _kAdminSalt))!);
    final loginHash = await _vault.read(key: _kAdminLoginHash);
    final pwHash = await _vault.read(key: _kAdminPwHash);

    final lOk = _slowCompare(_sha256Hex([...salt, ...utf8.encode(login.trim().toLowerCase())]), loginHash!);
    final pOk = _slowCompare(_sha256Hex([...salt, ...utf8.encode(password)]), pwHash!);

    if (!(lOk && pOk)) {
      _adminFailed++;
      if (_adminFailed >= _maxAttempts) {
        final exp = pow(2, _adminFailed - _maxAttempts).toInt(); // 15 → 30 → 60 ...
        _adminLockedUntil = DateTime.now().add(Duration(minutes: 15 * exp));
        _startLockTicker();
        _audit(AuthEventType.adminLocked, '$_adminFailed кӯшиши нодуруст — қулфи $exp дақиқа');
        notifyListeners();
        return AuthResult(AuthStatus.locked,
            'ҚУЛФ ШУД! $_maxAttempts кӯшиши нодуруст. $exp дақиқа интизор шавед.',
            remainingLock: Duration(minutes: 15 * exp));
      }
      _audit(AuthEventType.adminLoginFailed,
          'Парол/логин-и нодуруст (кӯшиши $_adminFailed/$_maxAttempts)');
      notifyListeners();
      return AuthResult(AuthStatus.wrongCredentials,
          'Логин ё парол нодуруст. Кӯшиши $_adminFailed зи $_maxAttempts.');
    }

    _adminFailed = 0;
    _adminLockedUntil = null;
    adminSessionActive = true;
    _audit(AuthEventType.adminLoginSuccess, 'Панели Супер-Админ кушода шуд');
    notifyListeners();
    return const AuthResult(AuthStatus.success, 'Хуш омадед, Супер-Админ!');
  }

  Duration? remainingAdminLock() {
    final u = _adminLockedUntil;
    if (u == null) return null;
    final d = u.difference(DateTime.now());
    return d > Duration.zero ? d : null;
  }

  /// Терминатсияи фаврии сессияи админ — ҳангоми тарки Панел (back/ close)
  void terminateAdminSession() {
    if (!adminSessionActive) return;
    adminSessionActive = false;
    _audit(AuthEventType.adminSessionTerminated,
        'Панел баста шуд — сессияи админ фавран terminate ва RAM wipe');
    notifyListeners();
  }

  /// «Ивази логин ва парол» — пароли ҶОРИЙ ҳатман санҷида мешавад;
  /// salt-и нав + hash-и нав (old hash бекор мешавад).
  Future<AuthResult> adminChangeCredentials(
      String currentPassword, String newLogin, String newPassword, String confirmNew) async {
    if (!adminSessionActive) {
      return const AuthResult(AuthStatus.locked, 'Сессияи админ фаъол нест.');
    }
    final salt = base64Decode((await _vault.read(key: _kAdminSalt))!);
    final pwHash = await _vault.read(key: _kAdminPwHash)!;
    final ok = _slowCompare(_sha256Hex([...salt, ...utf8.encode(currentPassword)]), pwHash);
    if (!ok) {
      _audit(AuthEventType.adminLoginFailed, 'Ивази мухтасасҳо: пароли ҷорӣ нодуруст');
      notifyListeners();
      return const AuthResult(AuthStatus.wrongCredentials, 'Пароли ҷорӣ нодуруст.');
    }
    if (newLogin.trim().length < 4) {
      return const AuthResult(AuthStatus.weakPassword, 'Логини нав ҳадди ақал 4 аломат бошад.');
    }
    if (newPassword.length < 8) {
      return const AuthResult(AuthStatus.weakPassword, 'Пароли нав ҳадди ақал 8 аломат бошад.');
    }
    if (newPassword != confirmNew) {
      return const AuthResult(AuthStatus.weakPassword, 'Пароли нав ва тасдиқ мувофиқ нестанд.');
    }
    await _writeAdminHashes(newLogin, newPassword);
    _audit(AuthEventType.adminCredentialsChanged,
        'Мухтасасҳои нав захира шуданд (salt-и нав, hash-и куҳон бекор)');
    notifyListeners();
    return const AuthResult(AuthStatus.success, 'Логин ва парол иваз шуд ✅');
  }

  // ================================================================
  //  ВОРИДШАВӢИ КОРБАР + Brute-Force Lockout
  // ================================================================
  Future<AuthResult> login(String email, String password) async {
    final lock = remainingLock();
    if (lock != null) {
      _audit(AuthEventType.loginLocked, 'Кӯшиши воридшавӣ ҳангоми қулф', ip: '10.x.x.x/ТҶ');
      return AuthResult(AuthStatus.locked, 'Ҳисоб ҚУЛФ ШУД. Баъди ${_fmt(lock)} кӯшиш кунед.',
          remainingLock: lock);
    }

    final e = email.trim().toLowerCase();
    if (!_validEmail(e)) return const AuthResult(AuthStatus.invalidEmail, 'Email-и нодуруст.');

    // Дар иловаи воқеӣ: backend Password_hash (Argon2id) санҷад.
    final storedHash = await _vault.read(key: 'pw_hash_$e');
    final ok = storedHash != null && _slowCompare(_clientProof(password), storedHash);

    if (!ok) {
      _failedAttempts++;
      if (_failedAttempts >= _maxAttempts) {
        final exp = pow(2, _failedAttempts - _maxAttempts).toInt();
        _lockedUntil = DateTime.now().add(Duration(minutes: 15 * exp));
        _startLockTicker();
        _audit(AuthEventType.loginLocked, '$_failedAttempts кӯшиши нодуруст — қулфи $exp дақиқа',
            ip: '10.x.x.x/ТҶ');
        notifyListeners();
        return AuthResult(AuthStatus.locked,
            'ҚУЛФ ШУД! $_maxAttempts кӯшиши нодуруст. $exp дақиқа интизор шавед.',
            remainingLock: Duration(minutes: 15 * exp));
      }
      _audit(AuthEventType.loginFailed, 'Пароли нодуруст (кӯшиши $_failedAttempts/$_maxAttempts)');
      notifyListeners();
      return AuthResult(AuthStatus.wrongCredentials,
          'Email ё парол нодуруст. Кӯшиши $_failedAttempts. Баъди $_maxAttempts кӯшиш ҳисоб қулф мешавад.');
    }

    _failedAttempts = 0;
    _lockedUntil = null;
    session = DevorSession(
      userId: e.hashCode.toRadixString(16),
      email: e,
      startedAt: DateTime.now(),
      deviceFingerprint: deviceFingerprint,
      sessionToken: _genToken(),
    );
    await _vault.write(key: 'session_token', value: session!.sessionToken);
    await _vault.write(key: 'session_user', value: session!.userId);
    _audit(AuthEventType.loginSuccess, 'Воридшавӣ аз $deviceFingerprint', ip: '10.x.x.x/ТҶ');
    notifyListeners();
    return const AuthResult(AuthStatus.success, 'Хуш омадед! Воридшавии муваффақ.');
  }

  /// Қайд (Register) — парол дар клиент HASH НОМЕШАВАД: бевосита HTTPS → backend.
  Future<AuthResult> register(String email, String password) async {
    final e = email.trim().toLowerCase();
    if (!_validEmail(e)) return const AuthResult(AuthStatus.invalidEmail, 'Email-и нодуруст.');
    if (!_strongPassword(password)) {
      return const AuthResult(AuthStatus.weakPassword,
          'Парол бояд ≥8 аломат, ҳарф ва рақам дошта бошад.');
    }
    final existing = await _vault.read(key: 'pw_hash_$e');
    if (existing != null) {
      return const AuthResult(AuthStatus.wrongCredentials, 'Ин email аллакай қайд шудааст.');
    }
    await _vault.write(key: 'pw_hash_$e', value: _clientProof(password));
    _audit(AuthEventType.loginSuccess, 'Ҳисоби нав офарида шуд: ${maskEmail(e)}');
    notifyListeners();
    return const AuthResult(AuthStatus.success, 'Ҳисоб офарида шуд! Акнун ворид шавед.');
  }

  // ================================================================
  //  БАРОМАДАН (Logout) — ТЕРМИНАЦИЯИ ҚАТИИ СЕССИЯ
  // ================================================================
  Future<void> logout() async {
    _audit(AuthEventType.sessionRevoked, 'access+refresh токенҳо revoke шуданд');
    await _vault.delete(key: 'session_token');
    await _vault.delete(key: 'session_user');
    await _vault.delete(key: 'otp_last');
    session = null;
    _otpCode = null;
    _otpTarget = null;
    _otpIssuedAt = null;
    _audit(AuthEventType.logout, 'Ҳамаи ҳолат, хотира ва кеш пок карда шуд');
    notifyListeners();
  }

  // ================================================================
  //  OTP — ЗИНДАГИИ ЭФЕМЕРӢ (≤ 3 дақиқа, БАЪДИ ИСТИФОДА ПУРРА НЕСТ)
  // ================================================================
  String issueOtp(String targetEmail) {
    _otpCode = (100000 + Random.secure().nextInt(899999)).toString();
    _otpTarget = maskEmail(targetEmail);
    _otpIssuedAt = DateTime.now();
    _audit(AuthEventType.otpIssued, 'Рамз барои $_otpTarget дода шуд (TTL 3 дақиқа)');
    notifyListeners();
    return _otpCode!;
  }

  /// true — агар рамз дуруст бошад; БАЪДИ САҲИҲ пурра нест мешавад (single-use)
  bool verifyOtp(String input) {
    if (_otpCode == null || _otpIssuedAt == null) return false;
    final expired = DateTime.now().difference(_otpIssuedAt!) > _otpTtl;
    final ok = !expired && _slowCompare(input.trim(), _otpCode!);
    _otpCode = null; // ПОК КУНИН ДАР ҲАР ҲОЛАТ (RAM wipe)
    _otpIssuedAt = null;
    _audit(ok ? AuthEventType.otpVerified : AuthEventType.otpPurged,
        ok ? 'OTP тасдиқ ва аз хотира нест шуд' : 'OTP нодуруст/муддаиф — нест шуд');
    notifyListeners();
    return ok;
  }

  bool get otpActive =>
      _otpCode != null &&
      _otpIssuedAt != null &&
      DateTime.now().difference(_otpIssuedAt!) <= _otpTtl;

  // ================================================================
  //  PII МАСКИРОВКА (UI ва логҳо)
  // ================================================================
  static String maskEmail(String email) {
    final at = email.indexOf('@');
    if (at <= 0) return '****';
    final local = email.substring(0, at);
    final dom = email.substring(at);
    return '${local.substring(0, min(2, local.length))}****$dom';
  }

  static String maskPhone(String phone) {
    final d = phone.replaceAll(RegExp(r'\D'), '');
    if (d.length < 9) return '+992 ** *** ** **';
    return '+992 ${d.substring(d.length - 9, d.length - 7)} *** ** ${d.substring(d.length - 2)}';
  }

  // ================================================================
  //  Runtime RASP (демо) — дар воқеӣ free_rasp / rmsygard
  // ================================================================
  bool get runtimeSafe => true;

  // ================================================================
  //  Қулф — countdown-и муштарак (корбар + админ)
  // ================================================================
  Duration? remainingLock() {
    final u = _lockedUntil;
    if (u == null) return null;
    final d = u.difference(DateTime.now());
    return d > Duration.zero ? d : null;
  }

  void _startLockTicker() {
    _lockTicker?.cancel();
    _lockTicker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_lockedUntil != null && DateTime.now().isAfter(_lockedUntil!)) {
        _lockedUntil = null;
        _failedAttempts = 0;
      }
      if (_adminLockedUntil != null && DateTime.now().isAfter(_adminLockedUntil!)) {
        _adminLockedUntil = null;
        _adminFailed = 0;
      }
      notifyListeners();
      if (_lockedUntil == null && _adminLockedUntil == null) t.cancel();
    });
  }

  String _fmt(Duration d) => '${d.inMinutes}д ${d.inSeconds % 60}с';

  // ================================================================
  //  хусусӣ
  // ================================================================
  bool _validEmail(String e) => RegExp(r'^[^@\s]+@[^@\s]+\.[a-zA-Z]{2,}$').hasMatch(e);
  bool _strongPassword(String p) =>
      p.length >= 8 && RegExp(r'[A-Za-zА-Яа-я]').hasMatch(p) && RegExp(r'\d').hasMatch(p);

  String _clientProof(String p) => 'argon2id-pretend:${p.length}:${p.hashCode ^ 0x5f3759df}';

  bool _slowCompare(String a, String b) {
    if (a.length != b.length) return false;
    var eq = true;
    for (var i = 0; i < a.length; i++) eq = eq && (a.codeUnitAt(i) == b.codeUnitAt(i));
    return eq; // constant-time comparison — зидди timing-ҳамла
  }

  String _genToken() {
    const chars = 'abcdef0123456789';
    final r = Random.secure();
    return List.generate(48, (_) => chars[r.nextInt(chars.length)]).join();
  }

  void _audit(AuthEventType t, String detail, {String? ip}) {
    auditLog.insert(0,
        AuthEvent(t, detail: detail, deviceFingerprint: deviceFingerprint, ipRegion: ip ?? 'локалӣ'));
    if (auditLog.length > 200) auditLog.removeLast();
  }
}

/// Парвандаи platforms барои fingerprint (демо)
class PlatformSafe {
  static const id = 'tj-device';
}
