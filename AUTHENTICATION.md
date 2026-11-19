# AUTHENTICATION.md — Девор (Devor)
## Воридшавӣ, аудит, Brute-Force Lockout ва Терминатсияи сессия

> Амалисозии пурра: `devor/lib/services/security_auth_service.dart` + экранҳои `_AuthScreen` / `_ProfileScreen` дар `main.dart`.

---

## 1. Аудит — ҲАР воридшавӣ ва баромадан сабт мешавад

```dart
auditLog.add(AuthEvent(type, detail, deviceFingerprint, ipRegion)); // timestamp auto
```

| Майдон | Намуна |
|---|---|
| `type` | `loginSuccess / loginFailed / loginLocked / logout / otpIssued / otpVerified / sessionRevoked` |
| `timestamp` | ISO-8601 (UTC) |
| `device fingerprint` | `dev-tj-device-<bootId>-<hash>` |
| `IP / минтақа` | Gateway header `CF-IPCountry` + ASN |
| `status` | муваффақ / нодуруст / қулф |

**Server-side:** ҳар `POST /auth/login` дар `auth_events` (append-only, WORM retention 90 рӯз) менависад. Alert ҳангоми: ≥3 loginFailed/10 дақиқа, login аз IP-и нав, невозможное путешествие.

## 2. Brute-Force Lockout (амалӣ дар UI — санҷидашаванда!)

```
Кӯшиши 1, 2      → паём «Кӯшиши N/3»
Кӯшиши 3         → ҚУЛФ 15 дақиқа  («Қулф шуд»)
Кӯшиши 4 (баъд қулф) → 30 дақиқа
Кӯшиши 5         → 60 дақиқа  … экспоненсиалӣ: 15 × 2^(n-3)
```

- Ҳолати lock дар **сервер** нигоҳ дошта мешавад (не client — client-ро хаккӯшӣ disable кардан мумкин буд).
- Дар Flutter-экран: баннери сурх бо **countdown** (`_AuthScreen`, `SecurityAuthService.remainingLock()`), тугмаи «Ворид шавед» disabled.
- CAPTCHA/App Check баъди қулфи дуюм ҳатман мешавад.
- Email/SM-и хушдорӣ: «Ҳисоби шумо қулф шуд аз IP x.x.x.x, вақт …».

## 3. Терминатсияи қатии сессия (Logout)

Амалисозӣ дар `_ProfileScreen` → `SecurityAuthService.logout()`:

```
1. Revoke дар сервер   : POST /auth/revoke {refreshToken} → refresh-и WhiteList нест мешавад,
                          access JWT (TTL 15 д) дар denylist то анҷоми TTL.
2. Поккунии SecureStorage: session_token, session_user, otp_last, hmac_key → delete().
3. Поккунии RAM        : session = null, OTP = null, контроллерҳои парол clear().
4. Поккунии кеши ҳассос: chat cache, draft-ҳо, last screen.
5. Navigation reset    : popUntil(isFirst) + pushReplacement(Login) — back button
                          сессияро БАРҚАРОР НАМЕКУНАД.
```

## 4. Сессияҳо ва токенҳо

| Ашё | TTL | Баста |
|---|---|---|
| Access JWT | 15 дақиқа | claim-ҳо: `uid, dev, scope` |
| Refresh token | 30 рӯз | **single-use, чархзананда** (rotating), bound to `deviceId`; истифодаи дуюр = қулфи тамоми оилаи сессия |
| Device binding | — | fingerprint + Play Integrity валид ҳар 24 соат |

## 5. Ҳисоби нав (Register)

- Парол танҳо аз **HTTPS + HMAC** мегузарад; клиент онро hash **намекунад** ва нигоҳ **намедорад**.
- Server: `Argon2id(password, salt)` → `pw_hash`.
- Тасдиқи email: OTP 6-рақамӣ, TTL 3 дақиқа, баъди истифода purge (нигаред DATA.md).
