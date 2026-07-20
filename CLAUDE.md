# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`kv-silver-mobile` is a **Flutter** (Android + iOS) customer-facing app for KV Silver Zone. It is a
pure client of the existing `kv-api` backend — Phase 1 adds **no** new endpoints. It is the native
replacement for the Capacitor wrapper inside the `kv-silver-zone` web repo, which is retired once
this ships.

Sibling repos under `Source/` (independent git repos, no workspace tying them together):
`kv-api` (Node/Express/MongoDB) and `kv-silver-zone` (React/Vite web). The parent `Source/CLAUDE.md`
predates this repo and only documents those two.

The authoritative design and implementation context lives in:
- [docs/superpowers/specs/2026-07-06-flutter-mobile-app-design.md](docs/superpowers/specs/2026-07-06-flutter-mobile-app-design.md) — Phase 1 scope, screens, data flow, error-handling contract
- [docs/superpowers/plans/2026-07-06-foundation-and-core.md](docs/superpowers/plans/2026-07-06-foundation-and-core.md) — the core-layer plan that produced current `lib/core/`

**Read the spec before adding a feature.** Explicitly out of Phase 1 scope: savings scheme, gift
vouchers, wishlist, reviews, push notifications.

## Commands

```bash
flutter pub get                       # install deps
flutter analyze                       # lint (flutter_lints, see analysis_options.yaml)
flutter test                          # all tests
flutter test test/core/pricing/pricing_test.dart          # single file
flutter test --name "computes metal value"                # single test by name
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000/api/v1
flutter build apk --dart-define=API_BASE_URL=https://<prod>/api/v1
```

Config is **compile-time only** via `--dart-define`, read by `String.fromEnvironment` in
[lib/core/config/env.dart](lib/core/config/env.dart). There is no `.env` file and no runtime config
fetch. The default `10.0.2.2` is the Android emulator's alias for the host's `localhost`; iOS
simulator needs `http://localhost:5000/api/v1` passed explicitly.

Package name is `kv_silver_mobile` (underscores — Dart identifiers can't contain hyphens) while the
repo directory keeps the hyphen. Bundle/application ID: `com.kvsilverzone.kv_silver_mobile`.

## Architecture

Feature-first. `lib/core/` holds cross-cutting concerns with **no** feature UI logic;
`lib/features/<name>/` folders each get `presentation/` (screens/widgets), `application/` (Riverpod
providers), `data/` (repository calling `core/api`), and must consume `core/` only through the
providers and classes below. `features/auth/` is built and is the reference for the layering;
`home`, `shop`, `product`, `cart`, `checkout`, and `orders` are not started.

**Auth/session is the spine of the app.** The chain is:

`SecureStorageClient` (interface) → `SecureTokenStorage` (key namespacing) →
`AuthSessionController` (Riverpod `StateNotifier`) → `go_router` redirect + dio interceptor.

- [lib/core/storage/secure_storage_client.dart](lib/core/storage/secure_storage_client.dart) exists
  purely so tests can swap in `test/support/fake_secure_storage_client.dart`. Never call
  `FlutterSecureStorage` directly from feature code.
- JWTs go in platform secure storage (Keychain / EncryptedSharedPreferences) — **never** a
  plaintext key-value store. The web app had to migrate JWTs out of `localStorage` for XSS reasons;
  don't reintroduce that here.
- [lib/core/api/api_client.dart](lib/core/api/api_client.dart)'s dio interceptor attaches
  `Authorization: Bearer <token>` on every request and, on any 401, calls `clearSession()`. That
  state change fires `_GoRouterRefreshNotifier`, which re-runs the redirect in
  [lib/core/router/app_router.dart](lib/core/router/app_router.dart) and lands the user on `/login`.
  **Logout is a side effect of state, not an imperative navigation call** — don't add manual
  `context.go('/login')` on auth failure.
- A stored token is **not** trusted on its own — cold start validates it with `GET /users/me` before
  the session counts as authenticated, because a 30-day JWT can outlive the account and there is no
  refresh endpoint.
- `AuthSessionState.isRestoring` gates the `/splash` route on cold start. The redirect
  (restoring → `/splash`, unauthenticated → public routes only, else `/home`) is the only place
  routing decisions belong. `_publicRoutes` in `app_router.dart` is the allowlist for signed-out
  access; a new signed-out screen must be added there or it will bounce to `/login`.
- Restore distinguishes **token rejected** (clear it, go to login) from **server unreachable** (keep
  the token, stay on splash, offer a retry). The web logs you out for both, which silently drops a
  valid session on a flaky connection — deliberately not ported.

**Errors are typed, not raw.** `ApiClient` catches every `DioException` and maps it through
[lib/core/api/api_exception.dart](lib/core/api/api_exception.dart) into a `sealed class ApiException`:
`NetworkException`, `AuthException`, `ValidationException`, `ServerException`. Feature code should
`switch` on these exhaustively and must never see a `DioException`.

Caveat: `ValidationException.fieldErrors` is **always empty in practice**. It reads an `errors` key
that `kv-api` never sends — the server has no validation middleware at all and returns a single flat
`{status, statusCode, message}` for every failure. Map errors to specific form fields by matching the
message string (`"city is required"`, `"pincode must be a 6-digit number"`) or just show the message
whole, as the auth screens do.

## API contract — verified against kv-api, not the spec

The Phase 1 spec predates the code and gets some of this wrong. These were confirmed by reading
`kv-api/src` directly; re-verify before trusting either document.

- **No response envelope anywhere.** `/auth/login` and `/auth/signup` return `{user, token}` with the
  JWT as a *sibling* of `user`. `GET /users/me` returns the user bare at the top level. There is no
  `{success, data}` wrapper.
- **Errors are one flat string.** `{status, statusCode, message}` for 400/401/404/500 alike. No
  `errors` map, no field-level structure, and no 422 exists.
- **`id` vs `_id` is inconsistent.** User uses `_id`. Addresses from `/users/me/addresses` use `id`.
  The *same* addresses embedded in `GET /users/me` use `_id`. `Address.fromJson` accepts both.
- **`PUT /users/me` is not symmetric with `GET`.** It returns the raw Mongoose document — it leaks
  `passwordHash` and omits the computed `role`. `AuthRepository.updateMe` discards that body and
  re-reads `GET /users/me`; don't "optimize" that second call away.
- **`POST /auth/forgot-password` is a no-op stub.** It ignores the body, sends no mail, and always
  returns 200. The OTP pair (`/auth/otp/request` + `/auth/otp/verify`) is fully implemented and is
  the only working way for a locked-out user to get back in.
- **Address writes are strict where nothing else is:** `pincode` must match `^\d{6}$` and `phone`
  `^[6-9]\d{9}$` — no `+91`, no spaces. Run user input through `normalizePhone` before sending.
- **The server owns default-address semantics** (first address forced default; setting a default
  unsets others; deleting one promotes another), so a single write can change rows you didn't touch.
  Re-list after any mutation instead of patching local state.
- **Auth is Bearer-only for this app.** The server checks the `Authorization` header *before* the
  cookie despite a comment claiming otherwise. Emit exactly one space after `Bearer` — the parser
  splits on `' '` and a double space yields a 401. No refresh endpoint exists; a 401 means re-login.

**Pricing is a deliberate port, kept in lockstep with two other implementations.**
[lib/core/pricing/pricing.dart](lib/core/pricing/pricing.dart) mirrors
`kv-silver-zone/src/lib/pricing.ts` function-for-function so app and website show identical prices.
If you change pricing math here, the web (and its backend counterpart) must change identically, and
the shared test fixtures must be updated in all of them. Money is `double` rupees, not paise.

This is **display-only**. The server re-prices authoritatively at checkout; the app must never send
a client-computed total as authoritative.

**Theme** ([lib/core/theme/app_theme.dart](lib/core/theme/app_theme.dart)) hardcodes the web's
default "Ocean Teal" palette as a Material 3 seed color. The web lets admins switch palettes at
runtime; Phase 1 ships the default only.

## Conventions

- **No code generation.** No `build_runner`, `json_serializable`, or `riverpod_generator` — the team
  is new to Flutter and the build stays simple. Write `fromJson`/`toJson` by hand and use the classic
  `StateNotifierProvider` API rather than codegen'd notifiers.
- Add a dependency only when the code using it lands (`razorpay_flutter` arrives with the checkout
  plan, not before).
- Riverpod providers are declared as top-level `final` in the file that owns the concern (e.g.
  `apiClientProvider` in `api_client.dart`), not gathered in a central providers file.
- Tests mirror `lib/` path-for-path under `test/`. Shared fakes live in `test/support/`. Widget tests
  drive state through a `ProviderContainer` with `overrides` and `UncontrolledProviderScope` — see
  [test/core/router/app_router_test.dart](test/core/router/app_router_test.dart) for the pattern.
- Testing scope for Phase 1: unit tests for pricing, widget tests for critical flows only (login
  validation, price recompute on variant select, cart totals). No `integration_test`, no e2e runner,
  no CI — features are verified manually on an Android emulator and iOS simulator before being
  considered done.

## OpenWolf

The parent `Source/.claude/rules/openwolf.md` mandates checking `.wolf/` (anatomy, cerebrum,
buglog) each session. **This repo has no `.wolf/` directory** — those rules were written for
`kv-api` and `kv-silver-zone`. Don't conflate learnings across the three repos; a convention found
in one does not apply here.
