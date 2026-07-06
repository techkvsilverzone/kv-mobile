# Flutter Mobile App (Customer) — Design Spec

Date: 2026-07-06
Status: Approved by user (sections 1-4), pending spec review before implementation planning.

## Context

`kv-silver-zone` (React/Vite web, also wrapped in Capacitor for Android) and `kv-api`
(Node/Express/MongoDB backend) are existing, independent repos under `Source/`. The user
requested a native customer-facing mobile app for Android + iOS, built in Flutter, in a
new repo under `Source/` (`kv-silver-mobile`, this repo), reusing `kv-api` as-is — no new
backend endpoints are planned for Phase 1.

This app replaces the existing Capacitor/Android wrapper entirely (not run alongside it
long-term) — the Capacitor app is retired once this app ships, as a separate follow-up
action outside this spec's scope.

Scope of this spec: **Phase 1 MVP only** — core shopping flow (browse, product detail with
live variant pricing, cart, checkout via Razorpay or COD, orders, profile/address book).
Explicitly out of scope, deferred to a separate future design: savings scheme, gift
vouchers, wishlist, reviews, push notifications.

Assumed context (confirmed with user): team is new to Flutter → prefer a conventional,
well-documented stack over a novel one; branding should match the existing website; no
constraints stated beyond reusing the existing API and moving off the retiring Capacitor app.

## 1. Repo & Project Structure

- New standalone repo: `Source/kv-silver-mobile`, Flutter targeting Android + iOS.
- State management: **Riverpod**.
- Navigation: **go_router**.
- HTTP client: **dio**.
- Secure token storage: **flutter_secure_storage** (iOS Keychain / Android
  EncryptedSharedPreferences).
- Payments: **razorpay_flutter** (native Razorpay SDK — same payment gateway as web).
- No code generation (no `build_runner`/`json_serializable`) — JSON (de)serialization is
  hand-written on model classes, to keep the build simple for a team new to Flutter.
- Environment configuration via `--dart-define=API_BASE_URL=...` at build time (dev/staging/
  prod point at different `kv-api` deployments the same way `VITE_API_URL` does for web).
- Feature-first folder structure:
  ```
  lib/
    core/
      api/        (dio client, interceptors, typed error mapping)
      pricing/     (ported pricing.dart — mirrors kv-silver-zone/src/lib/pricing.ts)
      storage/     (flutter_secure_storage wrapper)
      router/      (go_router config)
      theme/       (colors/typography matching kv-silver-zone branding)
    features/
      auth/        (login, signup, forgot password, profile, address book)
      home/
      shop/        (product grid/search, filters)
      product/     (product detail, variant selector)
      cart/
      checkout/    (address, coupon, delivery charge preview, payment)
      orders/      (list + detail/tracking)
    main.dart
  ```
  Each feature folder holds its own `presentation/` (widgets/screens), `application/`
  (Riverpod providers/state), and `data/` (repository calling `core/api`) subfolders.

## 2. Auth & API Integration

- Base URL: `kv-api`'s existing `/api/v1` surface, configured via `--dart-define`, same
  contract already consumed by `kv-silver-zone` web.
- Token storage: JWT persisted in `flutter_secure_storage`, **not** any localStorage-like
  plaintext mechanism — the recent web-side fix moved JWTs out of `localStorage` into an
  httpOnly cookie (web) specifically because JS-readable storage is an XSS target; the
  mobile app avoids repeating that mistake by using platform secure storage from day one
  rather than a plaintext key-value store.
- `dio` interceptor attaches `Authorization: Bearer <token>` to every request when a token
  is present, mirroring the existing Bearer-token fallback path `kv-silver-zone`'s Capacitor
  build already uses via `isMobileApp()`/`TOKEN_STORAGE_KEY`.
- 401 responses clear the stored token and redirect to Login via a Riverpod auth-state
  change + `go_router` redirect — the same effect as web's `UNAUTHORIZED_EVENT` +
  `silentLogout`, implemented natively for Flutter's state model instead of a DOM event.
- Reused endpoints (no backend changes needed): `/auth/login`, `/auth/signup`,
  `/auth/forgot-password`, `/users/me` (GET/PUT), address book endpoints, `/products`,
  `/silver-rates/today`, `/gold-rates/today`, `/pricing-config`, `/delivery-config`,
  `/coupons/apply`, `/orders`, Razorpay `create-order`/`verify`, `/admin/rate-status`
  (read-only, for the checkout price-lock check described below).

## 3. Feature Screens & Data Flow (Phase 1 MVP)

**Screens:**
- **Splash/bootstrap** — validate stored token via `GET /users/me`, then route to Home or
  Login.
- **Auth** — Login, Signup, Forgot Password, Profile (view/edit), Address book (list/add/
  edit/delete) — same fields/validation rules as the web forms (Indian phone/PIN regex,
  etc.).
- **Home** — category tiles + featured products, entry point into Shop.
- **Shop/Search** — product grid with infinite scroll (backend already supports `page`/
  `limit`, same as web's infinite-scroll Shop page), filters for category/metal/price range.
- **Product Detail** — image carousel, size/weight variant selector that recomputes the
  live price on selection, price breakdown (metal value + making charge + wastage,
  pre-GST), stock status, add-to-cart.
- **Cart** — line items, quantity/remove, subtotal + estimated GST/delivery preview,
  proceed to checkout.
- **Checkout** — address picker/add-new, coupon code, delivery zone charge preview,
  payment method (Razorpay or COD) → `create-order` → native Razorpay checkout → `verify`
  → confirmation.
- **Orders** — list + detail/tracking screen.

**Pricing data flow:** the web's `src/lib/pricing.ts` (`computeProductPricing`,
`computeOrderSummary`, charge/purity parsing) gets ported to a Dart equivalent in `core/
pricing/`, fed by the same `GET /silver-rates/today` + `GET /gold-rates/today` +
`GET /pricing-config` + `GET /delivery-config` calls, so displayed prices match the website
exactly. As on web, this is **display-only** — the actual charge is always whatever
`create-order`/`verify` return; the app never sends a client-computed total as
authoritative.

**State:** Riverpod providers per concern — `authProvider`, `cartProvider` (local +
server-merge-on-login), paginated `productListProvider`, `checkoutProvider` for the
multi-step checkout flow.

## 4. Error Handling & Testing Approach

**Error handling:**
- **API layer (dio):** a single interceptor normalizes failures into typed errors —
  `NetworkError` (no connectivity), `AuthError` (401 → clear token, route to Login),
  `ValidationError` (400 with field messages, surfaced inline on forms), `ServerError`
  (5xx, generic retry-able message).
- **Stale rate / price-lock parity:** the web blocks checkout before the 10am mandatory
  rate update (`rateFreshness.ts`). The app calls the same `GET /admin/rate-status` and
  simply disables checkout with a "prices updating, try again shortly" message — customers
  never see the admin unlock UI, just a blocked state.
- **Payment failures:** Razorpay SDK failure/cancellation callback returns to Cart (not a
  blank screen); a payment that succeeded on Razorpay's side but failed at `verify` shows
  an explicit "contact support, payment may have gone through" message rather than a
  silent failure.
- **Offline:** no offline-first caching for Phase 1 — screens show a retry state if a
  request fails while offline. No local order queue, no optimistic writes.

**Testing:**
- **Unit tests:** `flutter_test` for the ported pricing logic (`core/pricing/`) — same
  fixture-style cases as `pricing.service.test.ts`/`pricing.test.ts` on the backend/web, so
  all three implementations can be checked against the same inputs/outputs.
- **Widget tests:** critical flows only (Phase 1) — login form validation, product price
  recompute on variant selection, cart total recompute. Not full-coverage widget testing
  across every screen.
- **No integration/e2e test runner** for Phase 1 (no `integration_test` package, no
  device-farm CI) — matches the team's "new to Flutter" status.
- **Manual verification:** no existing Flutter CI in this project, so features are verified
  by running on an Android emulator + iOS simulator locally before being considered done.

## Non-Goals / Phase 2 (separate future design)

- Savings scheme, gift vouchers, wishlist, reviews, push notifications.
- Retiring the Capacitor/Android app (tracked as a follow-up action once this app ships,
  not part of this spec).
- Any new `kv-api` backend endpoints — Phase 1 is a pure client of the existing API surface.
