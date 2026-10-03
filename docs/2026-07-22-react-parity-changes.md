# Syncing the Flutter app with the React app's dynamic, admin-driven logic

Date: 2026-07-22
Status: analysis + change plan (nothing implemented yet)

## Why this exists

The Flutter app was built as a faithful port of `kv-silver-zone` **as it was read**, but a lot of
that app's behaviour is not in the code — it is driven at runtime by admin-panel settings served
by `kv-api`. We hardcoded several of those settings. This document is the gap analysis (verified
against both the React source and the *live* API) and the concrete changes needed to bring the two
into sync.

Three things were verified end-to-end:
1. The web reads admin config from `kv-api` on startup and honours it live.
2. The live store is **currently** set to `theme: "deep-amethyst"`, `isDark: true` — our app shows
   Ocean Teal light, so it already looks wrong.
3. The React **client** pricing diverges from the `kv-api` **server** pricing in two ways (purity
   and legacy charges). We inherited both divergences by mirroring the client.

## The one-line mental model

- **Categories, rates, pricing config, delivery config, coupons, store theme, marquee, featured** →
  admin-controlled, served by `kv-api`. The app must *fetch and honour* these.
- **Hero, occasion tiles, navbar, footer, store name, currency, savings copy** → hardcoded in the
  web too. Replicate as static constants; nothing to fetch.
- **"Collections"** → do **not** exist as a concept anywhere (no endpoint, model, or config). The
  word is only a navbar label pointing at `/shop`. Grouping = **categories** (`material`) + the
  **`isFeatured`** flag. There is nothing to build here.

---

## Gap analysis

| # | Area | Web / server behaviour | Our app today | Gap | Priority |
|---|------|------------------------|---------------|-----|----------|
| 1 | **Theme** | `GET /store-config` → `{theme, isDark, marqueeMessages}`; 4 palettes; applied live; cached to storage | Hardcoded Ocean Teal, light only | App looks nothing like the live store (now deep-amethyst dark) | **High** |
| 2 | **Pricing: purity** | Server: `metalValue = weight × rate × purityFraction` | `grams × rate` (no purity) | Estimate over-states metal value for purity < 1 (e.g. 925 → ~8% high) | **High** |
| 3 | **Pricing: legacy charges** | Server also honours `makingChargePerGram / makingChargePercent / makingCharges` | Only reads new `makingCharge`/`wastage` | Products on legacy fields show static price in-app but are priced live at checkout | **Medium** |
| 4 | **GST/delivery on cart** | Config-driven, shown at cart/checkout | We read config at checkout only | Cart GST/delivery line is vaguer than web | **Low** |
| 5 | **Marquee / announcements** | `marqueeMessages` from store-config + live rates ticker | Not implemented | Missing announcement surface | **Low** |
| 6 | **Filter config** (hidden cats, metal list, price bands) | Admin-authored but **localStorage-only**, never on server | Hardcoded defaults / slider | Cannot be synced — see "Backend gaps" | Info |
| 7 | **Invoice config** | `GET /invoice-config` for tax invoices | Not implemented | Invoices are out of Phase 1 scope | Info |

Things that look like gaps but are **not** (do not spend effort here):

- **Collections** — no such concept; nothing to build.
- **Stale-rate checkout lock** — `/admin/rate-status` is 403 for customers, and neither
  `POST /orders` nor `/payments/create-order` rejects stale rates server-side. The 10am lock guards
  the *admin panel only*. Our existing "compare local estimate vs server breakdown and flag a
  difference" is already the right and only customer-side behaviour.
- **Coupons** — our `{code, orderAmount}` → `{valid, discount, message}` already matches. (Server
  type is `percentage|fixed`, but the client never sees the type — only the computed discount.)
- **page/limit pagination** — the backend ignores both and returns everything; our
  `ProductListController` already detects the over-sized page and stops. No change.

---

## Detailed changes

### 1. Dynamic theming (High) — `features/store_config/`

The theme is the most visible divergence. Build a small store-config feature and drive the app's
`ThemeData` from it.

**Endpoint:** `GET /store-config` → bare object `{ theme, isDark, marqueeMessages? }` (no
`{status,data}` wrapper on this one — confirmed live).

**The four palettes** (web changes only `--primary`/`--ring`; HSL space-separated triples):

| key | label | H | S | L |
|-----|-------|---|---|---|
| `ocean-teal` (default) | Ocean Teal | 195 | 50% | 45% |
| `rose-gold` | Warm Rose Gold | 350 | 40% | 50% |
| `icy-silver` | Icy Silver | 210 | 25% | 45% |
| `deep-amethyst` | Deep Amethyst | 270 | 40% | 45% |

**Approach:**
- `StoreConfig` model + `StoreConfigRepository` (`GET /store-config`).
- `storeConfigProvider` (FutureProvider) resolved during `/splash`, cached to
  `SharedPreferences` (key e.g. `kv_silver_mobile.store_config`) so a cold start with no network
  keeps the last theme — mirrors the web's `localStorage['kv-theme-config']` fallback.
- Map `theme` key → seed `Color` via `HSLColor.fromAHSL(1, h, s, l).toColor()`, feed
  `ColorScheme.fromSeed(seedColor: seed, brightness: isDark ? dark : light)`.
- `main.dart` watches the config and rebuilds `MaterialApp.router` with the resolved theme +
  `themeMode`.
- Default constant = `{ ocean-teal, isDark: false }` for the offline/first-run case.

**Known imperfection to accept:** the web only overrides `--primary`/`--ring` and leaves every other
token fixed, whereas `ColorScheme.fromSeed` derives a whole scheme from the seed. Colours will be
*close* but not pixel-identical to the web. That is an acceptable trade for a single seed-based
theme; matching the web token-for-token would mean hand-porting its full CSS variable set (a much
larger job). Flag for the user if exactness is required.

`AppTheme` today hardcodes the seed — it becomes a function of the fetched config.

### 2. Pricing: apply the purity fraction (High) — `core/pricing/pricing.dart`

The server charges `metalValue = weight × silverRatePerGram × purityFraction`; we compute
`grams × ratePerGram`. For a 925 product that is ~8% too high on the *estimate* (the checkout total
is still correct, since we show the server breakdown there).

- Add `purityFraction` to `computeProductPricing`: `metalValue = grams * ratePerGram * fraction`,
  where `fraction = parsePurityFraction(purity) ?? (isSilver ? 0.925 : 1.0)` — matching the server's
  default (silver → 0.925, otherwise 1).
- Server uses a **single** silver rate × purity, not a per-purity rate lookup. `matchSilverRate`'s
  purity-matching is therefore moot with the current one-rate-per-metal data; keep it as a harmless
  fallback but the fraction multiply is what makes us agree with the charge.

**Decision required (see Open decisions):** this makes us *more accurate than the web* but no longer
*identical to the web*, which breaks the "shared fixtures across all three implementations"
invariant in CLAUDE.md.

### 3. Pricing: legacy making-charge fields (Medium) — `Product` model + pricing

The server's "can I price this live?" gate is `hasNewCharge || hasLegacyMaking`, where legacy =
`makingChargePerGram`, `makingChargePercent`, or `makingCharges`. We only read the new
`makingCharge`/`wastage`, so a legacy-configured product shows its static listed price in-app while
the server prices it live at checkout — an avoidable estimate mismatch.

- Parse the three legacy fields on `Product`.
- In pricing, resolve making charge with the server's precedence: new `makingCharge` →
  `makingChargePerGram × weight` → `makingChargePercent` of metal value → flat `makingCharges`.
- Wastage has no legacy form; leave as-is.

Verify against the catalogue first: if **no** live product uses legacy fields, downgrade this to
"nice to have" (all current products are `isFixedPrice`/static, so it may not bite today — but it
will the moment an admin configures a dynamic product the legacy way).

### 4. Show config-driven GST/delivery on the cart (Low)

The web shows a GST line and a delivery placeholder on the cart using `pricing-config` and
`delivery-config`. We already fetch both (checkout). Cheap win: surface the GST% note and a delivery
estimate on the cart screen too, reusing `gstPercentProvider` / `deliveryConfigProvider`. Purely
display; the server total remains authoritative.

### 5. Marquee / announcements (Low) — home

`marqueeMessages` (from the store-config we're already adding in #1) plus the live silver/gold rate,
as a scrolling strip. The web falls back to three hardcoded festive lines when the admin sets none.
Small, self-contained; can ride on the store-config work.

---

## Open decisions (need your call)

1. **Purity fix vs "identical to website".** Recommend applying the purity fraction (#2) so our
   estimate matches what the customer is actually charged. Cost: we intentionally diverge from the
   web's (over-stated) estimate and the shared pricing fixtures. Alternative: leave it web-identical
   and rely on the checkout breakdown to correct it. **Recommendation: apply purity** — an accurate
   pre-checkout price matters more than byte-parity with a known web bug. Either way, the web and its
   backend should ideally be reconciled too.

2. **Theme fidelity.** Seed-based (fast, ~faithful) vs full token port (exact, much larger).
   **Recommendation: seed-based**, revisit only if the brand team flags specific colours.

3. **Filter config.** See below — needs a backend decision.

---

## Backend gaps (not fixable in the app alone)

- **Filter config is localStorage-only.** Hidden categories, the admin's custom metal list, and
  custom price bands live in the *web admin's browser* and are never persisted to `kv-api`. A mobile
  app physically cannot read them. Options: (a) `kv-api` grows a `GET /filter-config` public endpoint
  (mirroring how `store-config` already works) and the admin writes there instead of localStorage —
  the clean fix, benefits web too; or (b) we ship the hardcoded `DEFAULT_FILTER_CONFIG`
  (`metals: ['Silver','Gold 22K']`, the four price bands), which matches a fresh install but **not**
  any admin edits. Recommend (a); until then, (b).

- **Gold products aren't dynamically priced.** The server's product engine only ever uses the silver
  rate. A gold product prices live only if it has charges *and* a silver rate exists, otherwise
  static. Not our bug to fix, but worth knowing when validating gold pricing.

---

## Suggested order of work

1. **Store-config + dynamic theming** (#1) — highest visible impact, self-contained, unblocks #5.
2. **Purity fraction** (#2) — one-function change, pending your decision.
3. **Legacy making fields** (#3) — after confirming a live product needs it.
4. **Cart GST/delivery line** (#4) and **marquee** (#5) — small polish, bundle together.
5. Raise the **filter-config endpoint** (backend) with the API team.

None of this is started. Say which items to build and in what order.
