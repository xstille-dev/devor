# CHECKLIST.md — Девор (Devor)
## Чек-листи амният, QA ва омодагӣ барои Google Play / App Store

---

## A. API & Network Hardening (SECURITY.md)

- [ ] Ҳеҷ endpoint/key/secret дар код, Git ё APK намоён нест (`jadx` scan pass)
- [ ] Конфигҳо танҳо тавассои `--dart-define` / `env.json` (gitignored) inject мешаванд
- [ ] `usesCleartextTraffic="false"` + `network_security_config.xml` бо pin-set (primary + backup)
- [ ] iOS ATS: `NSAllowsArbitraryLoads = NO`
- [ ] TLS 1.3 санҷиш — `testssl.sh api.devor.tj` → grade A+
- [ ] Certificate pinning санҷиш бо mitmproxy → ҳамаи дархостҳо fail мекунанд
- [ ] HMAC signing дар ҳамаи дархостҳои authenticated + nonce replay-check дар Redis
- [ ] App Check / Play Integrity дар gateway фаъол; дархости бе token → 403
- [ ] Rate limiting: 60 rpm/IP, 10 login/min — бо load-test тасдиқ
- [ ] Ҳеҷ токен/парол/OTP дар SharedPreferences / localStorage нест (grep test)
- [ ] FlutterSecureStorage бо Keystore/Keychain конфиг карда шудааст
- [ ] Backend: Argon2id (64MB, i=3) + per-user salt + pepper дар KMS
- [ ] Logs: PII-scrubber фаъол — надar `+992…`, `@gmail`, OTP дар log-ҳо (grep prod logs)

## B. Auth, Brute-Force Lockout & Session Invalidation (AUTHENTICATION.md)

- [ ] Ҳар login/logout дар `auth_events` (timestamp, device, IP, status) сабт мешавад
- [ ] 3 кӯшиши нодуруст → «Қулф шуд» 15 мин; countdown дар UI кор мекунад (дест-тест)
- [ ] Кӯшиши 4-ум → 30 мин, 5-ум → 60 мин (экспоненсиалӣ тасдиқ шудааст)
- [ ] Lock дар сервер нигоҳ дошта мешавад (client clear-lock зиддӣ мумкин нест)
- [ ] CAPTCHA/App Check баъди қулфи дуюм триггер мешавад
- [ ] Logout → refresh revoke + access denylist + SecureStorage wipe + RAM clear — тасдиқ бо bounce-back-и back button
- [ ] Access JWT TTL = 15 мин; refresh rotating single-use; reuse → оилаи сессия revoke
- [ ] Device binding: `dev` claim; login аз device-и нав → email/SM alert
- [ ] Back-и апп баъди logout сессияро барқарор НАМЕКУНАД (manual QA дар Android+iOS)

## C. Gmail/Password/OTP Masking & Auto-Wipe (DATA.md)

- [ ] Email дар UI: `ba****@gmail.com`; phone: `+992 90 *** ** 12`
- [ ] OTP: TTL 3 мин, single-use, purge аз RAM + DB (Firestore TTL index фаъол)
- [ ] Парол/OTP: `obscureText`, `autofillHints:null`, `enableSuggestions:false`
- [ ] `controller.clear()` баъди submit ва дар `dispose()` (бо memory-dump test тасдиқ)
- [ ] Screenshot блок дар screen-ҳои OTP/чати хусусӣ (FLAG_SECURE / secure entry)
- [ ] Firestore rules (request.auth.uid == resource.data.ownerId) — **integration test бо 2 user**
- [ ] IDOR-тест: user-и B update/delete/read эълони user-и A → 403
- [ ] Right-to-delete: cascade purge дар 30 рӯз (backend job)

## D. Anti-Hack, Obfuscation & Pen-Test (HACK.md)

- [ ] `flutter build apk --release --obfuscate --split-debug-info=…` (iOS: symbols upload)
- [ ] R8/ProGuard: repackage + dictionary; jadx scan → ягон string-и ҷолиб нест
- [ ] Root/Jailbreak detection (free_rasp) → блоки login дар rooted device (QA-тtest)
- [ ] Frida-detector: hook-test бо frida-server → alert/blocks
- [ ] Signature verification: repack-и APK → runtime kill
- [ ] Upload: magic-bytes + MIME + size + EXIF/GPS strip + re-encode (upload-и webshell-файл fail мекунад)
- [ ] Injection: `<script>` дар title/phone → neutralized (render-test)
- [ ] Scam-детект: card-number/wallet regex + report pipeline (3 report → auto-hide) QA
- [ ] Duplicate-ad simhash limit (5/рӯз) тасдиқ
- [ ] Pen-test беруна (OWASP MASVS L2) — баҳои ≥ 90% pass
- [ ] Bug bounty / feedback-и ҳавоӣ фаъол

## E. Tajik Localization, UI/UX & Release Readiness

- [ ] Ҳамаи string-ҳо тоҷикӣ (Кириллӣ) — scan-и `grep -r "TODO\|lorem"` → 0
- [ ] `TextDirection.ltr` тасдиқ дар ҳамаи экранҳо
- [ ] Ҳ, Қ, Ӯ, Ҷ, Ғ, Ӣ дар Noto Sans рендер мешаванд (QA дар Android 5, iOS 13+)
- [ ] Dark mode: #121212 bg, #1E1E1E surface, #D94141 accent — баррасии визуалӣ
- [ ] 5-tab navigation: Эълонҳо / Бандҳо / Сабти эълон / Чат / Девори ман — кор мекунанд
- [ ] 16 категория бо drill-down 3-сатҳӣ + brand-ҳо (Toyota…Xiaomi) — counters дуруст
- [ ] 30+ эълон тавлидшуда, 0 broken image (offline-пippet: airplane mode test)
- [ ] Карточкаи эълон 136×136 thumbnail, 2-мин title clamp, meta-тихай — pixel-perfect vs Divar
- [ ] Харитаи интерактив бо price-pins + instant preview
- [ ] Чат: quick-reply chips + simulated seller reply
- [ ] Post-wizard 3 қадам: category → details → contact; нарх/ройгон/мубодила toggles
- [ ] «Ҳушдорҳои пеш аз харид» дар саҳифаи эълон; «Тамос» бо copy-и +992
- [ ] **100% Ройгон: ягон paywall/VIP/ТОР нест** (grep: "vip", "top", "paid" → 0)
- [ ] «Созанда: Хайдарзода (Haydarzoda) • 100% Ройгон» дар footer
- [ ] App icons + splash (Adaptive icons Android, asset catalog iOS)
- [ ] Crashlytics/Sentry фаъол бо PII-scrubber
- [ ] Privacy Policy + Terms (тоҷикӣ) дар Play Store listing
- [ ] Play Data Safety form: PII ҷамъоварӣ, encryption-in-transit, delete-export flow
- [ ] Store listing: screenshot-ҳо (phone + tablet), description-и тоҷикӣ
- [ ] Phased rollout 10% → 100% + crash-free ≥ 99.5% дар 48 соати аввал

---

**Созанда: Хайдарзода (Haydarzoda) • Девор • 100% Ройгон**
