# SECURITY.md — Девор (Devor)
## Амнияти шабака, API ва нигоҳдории ниҳонӣ (Network, API & Credential Storage)

> Ҳуҷҷати аркитектурӣ — ҳамаи қоидаҳо дар `devor/lib/services/security_auth_service.dart` ва `devor/lib/main.dart` (TransportGuard) амалӣ шудаанд.

---

## 1. Сирри клиентӣ — ҲЕҶ ГОҲ дар код

**Қоида:** ягон API endpoint, key, secret ё token дар client-side code, Git ё log пайдо нашавад.

| Техника | Иҷро |
|---|---|
| `--dart-define` | `flutter run --dart-define=API_BASE_URL=...` — конфиг ҳангоми build inject мешавад, дар Git нест |
| `.env` (gitignored) | `--dart-define-from-file=env.json`, файл дар `.gitignore` |
| Backend API Gateway | Клиент танҳо бо `/gw/*` кор мекунад; endpoint-ҳои аслӣ (auth, db, storage) аз Интернэт пӯшидаанд (VPC-only) |
| Rate limiting | Gateway: 60 дархост/дақиқа/IP, 10 login/дақиқа/ҳисоб |
| App Check (Play Integrity / App Attest) | Ҳар дархост бо attestation token санҷида мешавад |
| HMAC request signing | `X-Devor-Sign = HMAC-SHA256(body, sessionKey)` — sessionKey дар **SecureStorage** зиндагӣ мекунад |

## 2. TLS 1.3 + Certificate Pinning

```yaml
# Android — android/app/src/main/AndroidManifest.xml (aplication):
android:usesCleartextTraffic="false"
android:networkSecurityConfig="@xml/network_security_config"
```

```xml
<!-- res/xml/network_security_config.xml -->
<network-security-config>
  <domain-config cleartextTrafficPermitted="false">
    <domain includeSubdomains="true">api.devor.tj</domain>
    <pin-set expiration="2027-01-01">
      <pin digest="SHA-256">BASE64_SPKI_PRIMARY</pin>
      <pin digest="SHA-256">BASE64_SPKI_BACKUP</pin>
    </pin-set>
  </domain-config>
</network-security-config>
```

- iOS: `NSAppTransportSecurity → NSAllowsArbitraryLoads = NO` + pin дар `Info.plist`.
- Клиент pin-ҳоро **аз сервер ба таври бехатар гирифта**, дар `SecureStorage` нигоҳ медорад (backup pin ҳатман).
- `TransportGuard.verify()` (`main.dart`) ҳар дархости `http://`-ро блок мекунад.

## 3. Нигоҳдории Hardware-backed

```dart
// FlutterSecureStorage → Android Keystore (StrongBox) / iOS Keychain (Secure Enclave)
final _vault = const FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
  iOptions: IOSOptions(accessibility: KeychainAccessibility.whenUnlocked),
);
```

**Рӯйхати ҳатман дар SecureStorage:** access token, refresh token, session key, HMAC key, pin-ҳои TLS.
**Қатъиян манъ:** парол, OTP, hash, PII дар `SharedPreferences` / localStorage / file.

## 4. Паролҳо (backend)

```
Algorithm : Argon2id (memory=64MB, iterations=3, parallelism=4)
Salt      : 16 bytes, per-user, CSPRNG
Pepper    : дар KMS (HSM), ҳеҷ гоҳ дар DB
Policy    : ≥8 аломат, ҳарф+рақам, ба dictionary-и тӯйкунанда (top-10k leak) санҷида мешавад
Reset     : token 15-дақиқа, single-use, баъди истифода purge
```

## 5. RASP (Runtime Application Self-Protection)

| Ҳимоя | Иҷро |
|---|---|
| Root / Jailbreak | `free_rasp`: frida, magisk, cydia substrate — alert + блоки login |
| Debugger | `Debug.isDebuggerConnected` / `ptrace` deny |
| Screenshot | Screen-ҳои OTP/Chat-и хусусӣ: `FLAG_SECURE` (Android) / `UITextField.isSecureTextEntry` (iOS) |
| Tampering | Сигнатураи APK дар ҳар startup бо hash-и `Play Signing` муқоиса мешавад |
| Emulator | `Build.FINGERPRINT`, sensor-ҳо, telephony — блоки sensitive flows |

## 6. Logging

- ҲЕҶ ГОҲ PII (phone, email, OTP, token) дар log — танҳо маскал (`maskEmail`, `maskPhone`).
- Crashlytics: auto-sanitizer `beforeSend` ҳамаи string-ҳои `+992…` ва `@gmail`-ро буридан мекунад.
