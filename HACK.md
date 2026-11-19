# HACK.md — Девор (Devor)
## Threat Modeling: ҳамаи векторҳои ҳамла ва ҳимояи сахтгиркоридашуда

> Ҳар вектор → ҳимояи конкретӣ бо амалисозӣ дар лоиҳа.

---

## 1. API Scraping, Sniffing & MITM

**Ҳамла:** топологӣ дар WiFi-и кофехона, mitmproxy, Charles — хонда гирифтани токенҳо ва dump-и API.

**Ҳимоя:**
- TLS 1.3-танҳо (min TLS 1.2, cipher suites-и сахт).
- **SSL Pinning** (SPKI pin-set бо backup pin — `network_security_config.xml`, `TransportGuard`).
- `usesCleartextTraffic="false"` — http://-и ягон дархост fail мекунад.
- **HMAC signing**: `X-Devor-Ts + X-Devor-Nonce + HMAC-SHA256(body)` — replay блок (nonce TTL 60s дар Redis).
- Gateway non-public: API-и аслӣ VPC-only; scraping бо rate limit 60 rpm/IP + оҳиста**g**_CAPTCHA баъди 100 rpm.

## 2. Brute-Force & Credential Stuffing

**Ҳамла:** 10k тӯйкундашуда email:pass аз leak-ҳо ба `/auth/login`.

**Ҳимоя:**
- **Progressive lockout** (AUTHENTICATION.md §2): 3 нодуруст → 15 мин, экспоненсиалӣ.
- Rate limit: 10 login/мин/ҳисоб, 5 login/мин/IP.
- **App Check / Play Integrity**: дархости бе attestation token рад мешавад.
- Credential stuffing → password-denylist (top-10k leaked) + email alert ҳангоми даромадани IP-и нав.

## 3. IDOR & Broken Access Control

**Ҳамла:** `GET /ads/{id}/edit`, `GET /chats/{chatId}` бо ID-и дигар кас (UUID-и ҳадсдодашаванда).

**Ҳимоя:**
- ҲАММАИ объектҳо бо `ownerId`; сервер ҳар `update/delete/read-private` бо:
  `if (resource.ownerId != auth.uid) → 403` (Firestore rules — DATA.md §5).
- Chat: `participants contains auth.uid`.
- UUID-и v4 (ҳадсдодашаванда нест) + танҳо idорукунӣ тавассои gateway.

## 4. XSS, SQL/NoSQL Injection & Malicious Uploads

**Ҳамла:** дар Title: `<script>...`, дар phone: `'; DROP TABLE ads;--`, дар тасвир: PHP-webshell дар EXIF.

**Ҳимоя:**
- Клиент: `TextInputFormatter`-и allowlist (title: на чизи `<>"'`; phone: танҳо `\d+`).
- Server: параметрлашуда queries (Firestore низоми document-авӣ — SQL injection аслан имконнопазир); ҳар string дар render-и web → escape.
- Upload: **magic bytes** (не extension) — танҳо JPEG/PNG/WEBP ≤ 10MB; **EXIF strip** (GPS, Make, Model) бо `sharp` дар Cloud Function; MIME + size + dimension check.
- Snowflake-и санҷиш: clamAV + image re-encode (ҳар payload-и embedded нест мешавад).

## 5. APK Reverse Engineering & Frida/Root Hooking

**Ҳамла:** `apktool d devor.apk`, jadx — хонда гирифтани endpoints, ё Frida hook ба `getAccessToken`.

**Ҳимоя:**
- Build: `flutter build apk --release --obfuscate --split-debug-info=build/symbols`
- R8/ProGuard: `-obfuscationdictionary`, `-repackageclasses 'x'`; `resourcemappings` нест.
- **Root/Jailbreak detection** (free_rasp): Magisk, Cydia, substrate → блоки sensitive flows.
- **Frida/Xposed detection**: санҷиши map-ҳои frida (27042 port, `frida-agent`), hook-детект бо canary.
- **Signature verification**: hash-и signing cert ҳар startup муқоиса мешавад; repack → kill.
- Secrets ҳеҷ гоҳ дар APK НЕМОНАНД — ҳамаат backend-дор (ннж. Key дар KMS).

## 6. Session Hijacking & Token Replay

**Ҳамла:** session cookie/JWT дуздидан аз device-и гирифташуда.

**Ҳимоя:**
- JWT TTL **15 мин**; refresh **rotating single-use** — дукар истифодаи refresh → тамоми оилаи сессия revoke (RFC 6819 §5.2.2.3).
- Device binding: `dev` claim = deviceId; mismatch → 401 + alert.
- Logout → denylist то анҷоми TTL access (AUTHENTICATION.md §3).

## 7. Spam, Phishing & Scam Ads

**Ҳамла:** «Интиқом-пардохт», дуздидани mobile-money, fake-и «насиха», 100 эълон дар дақиқа.

**Ҳимоя:**
- Phone number verification (OTP) — иҷозатдодашаванда пеш аз нашр.
- Rate limit: 5 эълон/рӯз/ҳисоб, 1 эълон/10 мин.
- Авто-детект: regex-и `card number`, `MTS/wallet transfer`, тугмаи «Гузориш» дар ҳар эълон → 3 report → auto-hide + human review.
- URL-ҳо дар description: танҳо whitelist-домен; кӯтоҳкунак (bit.ly ва ғайра) манъ.
- Duplicate-content hash (simhash) — копипаста-и 50 эълон блок.

## Матрицаи хатар (сummary)

| Вектор | Бурҷи ҳимоя | Автоматӣ |
|---|---|---|
| MITM/Sniff | Pinning + HMAC | ✅ |
| Brute-Force | Lockout + App Check | ✅ |
| IDOR | Firestore rules + server check | ✅ |
| Injection/Upload | Sanitize + magic bytes + EXIF strip | ✅ |
| RE/Frida | R8 + free_rasp + sig check | ✅ |
| Session theft | Short JWT + rotating refresh + device bind | ✅ |
| Scam/Spam | OTP verify + rate limit + reports | ✅ (part human) |
