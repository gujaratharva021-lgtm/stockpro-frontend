# StockPro Frontend — Phase 1 Audit Report

Repo audited: `gujaratharva021-lgtm/stockpro-frontend` (default branch, shallow clone)
Method: static read-through of the codebase. **No Flutter SDK was available in this
environment, so `flutter analyze`, `flutter test`, and app launch were NOT run.**
Run those yourself (or via Claude Code, which can execute them) before merging.

---

## 1. Architecture found

- Flutter 3.11 / Dart, feature-first structure: `lib/core` (constants, models,
  services, theme, utils) + `lib/features/<feature>/screens` (32 feature folders)
  + `lib/shared/widgets`.
- State management: **Riverpod 3.3** (primary). A stray `provider: ^6.1.5+1`
  dependency also sits in `pubspec.yaml` — confirm it's actually used anywhere;
  if not, drop it to avoid two competing DI/state patterns.
- Routing: `go_router`.
- Networking: `dio`, with a request interceptor already handling auth (see §9).
- Storage: `flutter_secure_storage` for tokens — good, no `SharedPreferences`
  found holding sensitive data.
- Realtime: `web_socket_channel` (`websocket_service.dart`).
- Charts: `fl_chart` + `candlesticks`.
- Payments: `razorpay_flutter`.
- Biometrics: `local_auth` (`biometric_service.dart`).
- Crash reporting: `firebase_crashlytics`.

## 2. Existing screens/features (actual inventory)

The app is considerably **more built-out** than a bare MVP. Feature folders
present: assistant, auth, calculator, commodity, compare, dashboard, etf, fd,
fiidii, fno, heatmap, ipo, markets, mtf, mutualfunds, news, notifications,
onboarding, orders, portfolio, profile, screener, search, smallcase,
stock_detail, tax, wallet, watchlist.

| Area | Status | Notes |
|---|---|---|
| Splash / Login / Signup / OTP (`code_login_screen`) / Forgot password | IMPLEMENTED | Biometric service exists separately — confirm it's actually wired into the login flow, not just present as a service. |
| Home / Dashboard | IMPLEMENTED | Single `dashboard_screen.dart` — worth checking it isn't one giant widget (see §Code Quality). |
| Portfolio | IMPLEMENTED | Plus extra `family_screen.dart` and `performance_screen.dart` not in the original spec. |
| Watchlist | IMPLEMENTED | Single watchlist screen — multi-watchlist support not evident from file structure; needs data-model check. |
| Search | IMPLEMENTED | |
| Stock details | IMPLEMENTED (rich) | Sub-screens for option chain, GTT, technicals, fundamentals, advanced chart, market depth, quote sheet — this is beyond the base spec. |
| Orders (buy/sell/pending/basket) | IMPLEMENTED | `buy_order_screen.dart` present; no obvious `sell_order_screen.dart` — check if buy/sell share one parameterized screen (fine) or sell is missing (gap). |
| Account/Profile | IMPLEMENTED | |
| IPO, F&O, ETF, Mutual Funds, Commodity | IMPLEMENTED as feature folders | Depth/completeness needs a per-screen review beyond this pass. |
| Tax reports, Statements | `tax` folder present | "Statements" specifically not confirmed as a distinct screen — likely folded into profile or tax. |
| KYC, Bank account, Nominee | **NOT FOUND** as dedicated screens | Likely the biggest genuine gap against your spec — no `kyc/`, `bank_account/`, or `nominee/` feature folder exists. |
| Help & Support | **NOT FOUND** as a dedicated screen | Not seen as its own feature folder. |

Given the size of the codebase, treat the "not found" items above as
**flagged for confirmation**, not certainties — they may live inside
`profile/` rather than as separate top-level features. That needs an
in-editor check I couldn't do without deeper file-by-file reading than fit
in this pass.

## 3. Navigation

`MainShell` (`lib/shared/widgets/main_shell.dart`) implements a 4-tab bottom
nav (Home / Portfolio / Trade / Watchlist) + a "More" sheet for
IPO/News/Profile, with a separate responsive web sidebar layout. This is a
reasonable, already-working structure — **recommend keeping it**, not
replacing it with the 5-tab layout your brief sketched, since Trade access
from the bottom bar is arguably better than burying order placement in
"More" the way a plain 5-icon layout would.

## 4. Bugs found and fixed in this pass

1. **Divergent color tokens (real bug).** `AppColors` (used in ~75 files) and
   `AppTheme` (used only to build the global `ThemeData` in `main.dart`) each
   defined their *own* primary/success/danger colors, and they didn't match
   (`AppColors.primary` `0xFF4C8DFF` vs `AppTheme.primary` `0xFF387ED1`;
   success `0xFF00C875` vs `0xFF00A870`). Net effect: default Material
   widgets (ripples, default button colors, `Theme.of(context)` reads) used a
   subtly different brand blue/green/red than every hand-styled widget in the
   app. **Fixed**: `AppTheme` now derives its palette from `AppColors`
   instead of hardcoding a second copy.
2. **Dark-content-on-white-sheet bug.** The "More" bottom sheet in
   `main_shell.dart` hardcoded `backgroundColor: Colors.white` while its
   `ListTile`s use `AppColors.textPrimary`/`textSecondary`, which are
   near-white dark-theme text colors — on a white sheet those tiles would be
   close to unreadable. **Fixed**: sheet now uses `AppColors.cardBackground`.
3. No `print()`/unguarded debug logging found in `lib/` — clean on that front.
4. No hardcoded broker/API secrets found. The only "keys" present are
   Firebase client `apiKey` values in `firebase_options.dart`, which are
   normal to ship client-side (they identify the project, not a secret —
   access is controlled server-side by Firebase security rules), so this is
   not a leak.
5. Token handling uses `flutter_secure_storage` consistently in the auth
   screens checked — no tokens found in plain `SharedPreferences`.
6. `dio` client has connect/receive timeouts (60s) and an auth interceptor
   already in place (`api_service.dart`) — foundation is reasonable; 60s is
   long for a trading app's default timeout and worth tuning down for
   quote/order endpoints specifically in a later phase.

## 5. Design system gap (addressed)

There was **no shared spacing/radius scale and no reusable component
library** — `AppColors` existed, but none of `AppButton`, `AppCard`,
`PriceChange`, `SectionHeader`, `LoadingSkeleton`, `EmptyState`, or
`ErrorState` existed anywhere in the repo, despite being needed (and
re-implemented ad hoc) across many screens. Added in this pass, all under
`lib/shared/widgets/` and `lib/core/theme/`:

- `app_dimens.dart` — `AppSpacing` / `AppRadius` tokens.
- `price_change.dart` — `PriceChange` widget (green/red +/- formatting).
- `app_card.dart` — `AppCard` container.
- `app_button.dart` — `AppButton` with primary/buy/sell/outline variants.
- `section_header.dart` — `SectionHeader` for dashboard blocks.
- `loading_skeleton.dart` — `LoadingSkeleton` + `LoadingSkeletonList` (no
  new dependency added — plain `AnimationController` shimmer, since no
  `shimmer` package is in `pubspec.yaml`).
- `empty_state.dart` — `EmptyState` with optional action button.
- `error_state.dart` — `ErrorState` with Retry, plus an `OfflineBanner`.

These are additive only — nothing existing was deleted, and no screen was
rewired to use them yet (that's a safe, mechanical follow-up: swap each
screen's inline loading/empty/error UI for these, one screen at a time).

## 6. Not done in this pass (needs a deeper session)

- Per-screen UI/API-integration grading for all 32 feature folders (search,
  market data, investment products, account) — I inventoried structure, not
  each screen's implementation quality.
- State-management audit for rebuild/leak/race-condition issues — needs
  reading provider/notifier code per feature, not just file listing.
- Accessibility, responsive-layout, and performance passes.
- Confirming whether KYC / Bank account / Nominee / Help & Support are truly
  missing or just nested inside `profile/`.
- Running `flutter analyze` and the existing test suite (no SDK here).

## 7. Recommended Phase 2

1. Confirm/close the KYC, bank account, nominee, help & support gap.
2. Migrate existing screens' inline loading/empty/error UI onto the new
   shared widgets, feature by feature — mechanical, low-risk, good first
   Phase 2 task.
3. Full Riverpod provider audit for rebuild/leak issues.
4. Tighten `dio` timeouts for quote/order endpoints specifically.
5. Confirm buy/sell order screen coverage and multi-watchlist data model.

## Files changed/added in this pass

- `lib/core/theme/app_theme.dart` — modified (derive colors from `AppColors`)
- `lib/shared/widgets/main_shell.dart` — modified (bottom sheet color bug)
- `lib/core/theme/app_dimens.dart` — new
- `lib/shared/widgets/price_change.dart` — new
- `lib/shared/widgets/app_card.dart` — new
- `lib/shared/widgets/app_button.dart` — new
- `lib/shared/widgets/section_header.dart` — new
- `lib/shared/widgets/loading_skeleton.dart` — new
- `lib/shared/widgets/empty_state.dart` — new
- `lib/shared/widgets/error_state.dart` — new

**Not tested** — no Flutter SDK in this environment. Before merging: run
`flutter pub get && flutter analyze && flutter test`, and manually verify the
app still launches, the More-menu sheet renders correctly, and the global
theme didn't visibly shift anywhere unexpected.
