# DATA.md — Девор (Devor)
## Ҳифзи PII, маскалкунӣ ва тӯли ҳаёти эфемерии маълумот

> Амалисозӣ: `SecurityAuthService.maskEmail / maskPhone / issueOtp / verifyOtp / logout` дар `devor/lib/services/security_auth_service.dart`.

---

## 1. Рӯйхати PII бо ҳимояи қатӣ

| Данные | Ҳимоя |
|---|---|
| **Gmail / email** | mask `ba****@gmail.com` дар UI ва log; дар DB танҳо server-side; index ҳеҷ гоҳ unencrypted нест |
| **Телефон (+992)** | mask `+992 90 *** ** 12` дар карточкаҳо; рақами пурра танҳо бо клики «Тамос»; дар log ҳеҷ гоҳ |
| **Парол** | obscureText, `enableSuggestions:false`, `autocorrect:false`, `autofillHints:null`; clear() баъди submit |
| **OTP (6-рақамӣ)** | TTL **3 дақиқа**, single-use, баъди тасдиқ **purge-и RAM + DB** |
| **Reset token** | TTL 15 дақиқа, single-use, purge |
| **Тавсифи эълон** | sanitization (XSS/injection — HACK.md §4) |

## 2. Тӯли ҳаёти эфемерӣ («Баъди истифода — БАСТА шавад»)

```dart
// issueOtp: сохтан ба CSPRNG, TTL 3 мин
bool verifyOtp(String input) {
  final ok = !expired && _slowCompare(input, _otpCode!);
  _otpCode = null;            // ← ПОК КУНИН ДАР ҲАР ҲОЛАТ (success ё fail)
  _otpIssuedAt = null;
  _audit(ok ? otpVerified : otpPurged, ...);
  return ok;
}
```

- DB: OTP дар collection-и TTL-index-дор (`expireAt` + Firestore TTL policy) — ҳатто агар клиент purge накунад, сервер мекашад.
- Ҳеҷ гоҳ OTP-и куҳан «принсипи single-use»: рамзи дуюр бо ҳамон token валид нест.

## 3. Маскал дар UI ва логҳо

```
Email  : ba****@gmail.com
Phone  : +992 90 *** ** 12
OTP    : ******  (обсcureText; ягон рақам ҳам дар log)
Token  : eyJh**** (танҳо 6 аломати охирин)
```

- `print/debugPrint` дар release build **manъ** (`kReleaseMode` guard + `flutter_lints` rule).
- Crashlytics/Sentry: `beforeSend` scrubber бо regex `+992\d{9}`, `[\w.]+@[\w.]+`, `[0-9]{6}`.

## 4. Формҳо (RAM hygiene)

1. Ҳар форм-и ҳассос дар `TextField`-ҳо бо `obscureText: true` ва `autofillHints: null` (манъи autocomplete/keyboard cache).
2. Баъди `submit` ё `dispose`: `controller.clear()` — парол/OTP дар RAM-и фрео намемонад.
3. Back-и экран = dispose → clear.

## 5. Database Security Rules (Firestore)

```js
rules_version = '2';
service cloud.firestore {
  match /databases/{db}/documents {
    // Эълонҳо: ҳар кас хонад; танҳо соҳиб тағйир дода метавонад
    match /ads/{adId} {
      allow read: if true;
      allow create: if request.auth != null
                    && request.resource.data.ownerId == request.auth.uid;
      allow update, delete: if request.auth != null
                    && resource.data.ownerId == request.auth.uid;
    }
    // Профил ва PII: ТАНҲО соҳиб
    match /users/{uid} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
      // passwordHash, otp, tokens → ҳеҷ гоҳ дар клиент-роут
    }
    // Чат: танҳо иштирокчиён
    match /chats/{chatId}/msgs/{msgId} {
      allow read, create: if request.auth != null
        && request.auth.uid in resource.data.participants;
    }
  }
}
```

**Қоидаи тиллоӣ:** `request.auth.uid == resource.data.ownerId` — ягон user ҳеҷ гоҳ Gmail-и дигар, hash-и парол ё рамзи OTP-и дигарро **хонда наметавонад** (ҳатто бо SDK-и customer).

## 6. Несткунӣ (Right to be forgotten)

- Delete account → cascade: ads (soft-delete 24h → purge), chats, images (Storage), auth record.
- Backup-ҳо дар 30 рӯз purge мешаванд; PII аз backup anonymized.
