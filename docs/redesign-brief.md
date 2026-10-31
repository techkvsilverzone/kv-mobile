# Redesign brief (for every screen)

The owner's verdict on the previous version: "I asked you to recreate the features from the web,
not the web in Flutter. The UX is not good at all." The app must feel like a modern, professional
native shopping app (think Tanishq / CaratLane / Myntra / Apple Store app quality), while keeping
every feature and every API behaviour that exists today.

Read first: docs/design-system.md (rules + tokens), lib/core/ui/components.dart and
lib/core/ui/skeleton.dart (the component kit), and the finished reference screens:
lib/features/home/presentation/home_screen.dart, lib/features/account/account_screen.dart,
lib/features/auth/presentation/login_screen.dart, lib/features/catalog/presentation/widgets/product_card.dart.

## What "web in Flutter" looked like (remove all of it)
- Centred eyebrow + huge serif headline + rule headers on every page; serif headings in blue.
- Marketing sections stacked down long pages (benefits, how-it-works, FAQ walls) on task screens.
- Primary actions buried at the end of long scrolls; tables; tiny pill badges everywhere;
  desktop spacing; copy-pasted web wording like "Track Order", "Order Summary" cards in every view.
- Dialogs for multi-field forms; spinners for whole pages; plain grey "nothing here" text.

## What to do instead
- Task-first layouts: the one thing the user came to do is obvious and reachable with the thumb.
- Sticky `BottomActionBar` for the primary action (+ total/price) on flow screens.
- Bottom sheets (`showKvSheet`) for pickers/filters/forms with ≤5 fields; full screens for longer.
- Content in `KvCard`s with 16px padding, `SectionHeader`s, generous but tight vertical rhythm.
- Skeletons while loading (`ListSkeleton`, `ProductGridSkeleton`, `KvShimmer`+`KvSkeleton`),
  `EmptyState` for empty/error with a clear action, pull-to-refresh on every list.
- `showKvToast` for action feedback (not the old `showToast` from installment_payer.dart).
- `StatusPill` with semantic tones for statuses. `PriceText` for money. `QuantityStepper`.
- Short, plain, friendly copy. Sentence case. No marketing filler on task screens.
- Long informational content (FAQ/legal/benefits) goes behind expandable tiles or its own page.

## Constraints
- Keep all data/application layers and behaviour (repositories, providers, controllers, API
  payloads, validation, payment flows). Redesign presentation only, unless a change is needed
  for the UX (then keep the API contract identical).
- Do NOT edit: lib/core/router/app_router.dart, lib/main.dart, lib/app/*, lib/core/theme/*,
  lib/core/ui/* (shared kit — if you need a new shared component, put it in your feature folder
  and mention it in your report), pubspec.yaml, product_card.dart/product_grid.dart, home_screen.dart,
  account_screen.dart, login_screen.dart. For a sub-page that needs no deep link, push it with
  `Navigator.of(context).push(MaterialPageRoute(...))`. If you need a new router path, say so.
- Light theme only; colours only via `Kv.*` tokens or `Theme.of(context).colorScheme`.
- Screens are inside a bottom-tab shell (Home, Shop, Savings, Cart, Account) or pushed full screen
  above it. Tab-root screens don't show a back arrow.
- Check your work visually with the screenshot harness: write `test_screens/<area>_test.dart`
  (see test_screens/home_test.dart; shared sample data in test_screens/fixtures.dart — put any
  extra fixtures in your own `test_screens/<area>_fixtures.dart`), run
  `flutter test test_screens/<area>_test.dart --update-goldens`, then LOOK at the PNGs in
  test_screens/out/ with the Read tool and iterate until each screen looks like a polished app.
  Capture each screen's main states (loaded, empty, loading where meaningful) and scrolled views.
- Keep `flutter analyze` clean and `flutter test` (the test/ folder) passing; update widget tests
  whose expected text you changed, keep their behavioural intent, add tests for new behaviour.
