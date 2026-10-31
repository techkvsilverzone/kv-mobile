# KV Silver Zone app — design system

The app is a native mobile shopping app with the web's *features*, not the web's layout.
Every screen follows these rules. Shared code lives in `lib/core/theme/` and `lib/core/ui/`.

## Brand
- Colours come from the logo: **ink** `#1F1B1C` (text, dark surfaces) and **royal blue**
  `#2F6CB0` (primary actions, links, selection). Silver neutrals for everything else.
- Light theme only. One fixed brand palette (the web's admin-switchable palettes are not used).
- Logo mark: `assets/brand/logo_mark.png`; full lockup: `assets/brand/logo_full.png`.

## Tokens (`lib/core/theme/tokens.dart` → `Kv`)
| Token | Value | Use |
|---|---|---|
| `Kv.ink` | #1F1B1C | primary text, dark buttons |
| `Kv.blue` | #2F6CB0 | primary buttons, links, selected states |
| `Kv.blueSoft` | #EAF1FA | selected chip / tinted backgrounds |
| `Kv.bg` | #F5F6F8 | scaffold background |
| `Kv.surface` | #FFFFFF | cards, sheets, app bars |
| `Kv.line` | #E7E9EE | 1px borders, dividers |
| `Kv.muted` | #6B7280 | secondary text |
| `Kv.subtle` | #9AA1AC | tertiary text, placeholders |
| `Kv.success` | #15803D / soft #E8F5EC | in stock, paid, delivered |
| `Kv.warning` | #B45309 / soft #FEF3E2 | pending, low stock |
| `Kv.danger` | #DC2626 / soft #FDECEC | errors, cancelled, sale |
| `Kv.gold` | #B08A3E | gold-metal accents only |
- Spacing: 4 · 8 · 12 · 16 · 20 · 24 · 32. Screen side padding **16**. Section gap **24**.
- Radius: cards/sheets **16**, inputs/buttons **12**, chips/pills **999**, images in cards **12**.
- Elevation: flat. Cards = white + 1px `Kv.line` border, no shadow. Only floating elements
  (bottom action bar, FAB, snackbars) get a soft shadow.

## Type (Inter everywhere; Playfair Display only for brand moments)
- `displaySerif` (Playfair 28/600): splash, home greeting, auth titles. Nowhere else.
- Page titles: AppBar title Inter 18/600 ink. Section titles: Inter 17/700.
- Body 15/400 ink; secondary 13/400 muted; captions 12/500 muted; prices Inter 600–700.
- Never colour headings blue. Blue is for actions and selection.

## Layout & navigation
- Bottom `NavigationBar` (Home, Shop, Savings, Cart, Account) via `StatefulShellRoute`;
  each tab keeps its stack. Detail/flow screens (product, checkout, order, passbook, auth)
  open full screen above the bar.
- App bars: white, no elevation, centred-left title, back arrow; large titles only on tab roots.
- Primary action of a screen lives in a sticky `BottomActionBar` (price/total on the left,
  one filled button on the right), not at the end of a long scroll.
- Choices with more than ~4 options open a bottom sheet (`showKvSheet`): filters, sort,
  size/variant, coupon, address picker.

## Components (`lib/core/ui/`)
`KvCard`, `SectionHeader` (title + "See all"), `PriceText`, `StatusPill`, `KvSkeleton`
(shimmer placeholders — use instead of spinners for content), `EmptyState` (icon, title,
message, action), `BottomActionBar`, `showKvSheet`, `QuantityStepper`, `KvListTile` /
`MenuGroup` for settings-style lists, `showKvToast` (floating snackbar).

## Behaviour
- Loading: skeletons for lists/cards; a spinner only inside buttons.
- Errors: inline `EmptyState` with "Try again"; toasts only for action results.
- Every list has pull-to-refresh and a designed empty state.
- Add-to-cart / wishlist give haptic feedback and a toast with a "View" action.
- Forms: labelled outlined fields, inline validation on submit, keyboard-aware scrolling,
  the submit button in a bottom bar when the form is long.
- Successful sign-in returns to where the user came from (`?from=`), else Home.
