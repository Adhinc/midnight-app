# Midnight App - Development Notes & Session Log

## Session Date: 2026-03-07

---

## 1. Project Setup

- Cloned repo from `https://github.com/Adhinc/midnight-app.git`
- Location: `~/Desktop/Workspace/projects/adhin-cureocity/startup/midnight-app`
- Stack: Flutter, Firebase (Auth, Firestore), Agora (Voice), Razorpay (Payments)

---

## 2. Full Codebase Review - Areas Needing Improvement

### CRITICAL
1. **Hardcoded API keys** in `lib/core/constants.dart` — Agora App ID & Razorpay key exposed in public repo
2. **Weak Firestore rules** — `firestore.rules:30` allows any authenticated user to read/write all requests

### HIGH
3. **Resource leaks** — TextEditingControllers never disposed in login, signup, edit profile screens
4. **No real tests** — Only placeholder test in `test/widget_test.dart`
5. **No input validation** — No email format or password strength checks

### MEDIUM
6. **Debug print statements** — 62 print/debugPrint across 12 files (FIXED)
7. **Network images not cached** — Large images re-downloaded every time
8. **Agora uses empty token** — Production must use a token server
9. **`device_preview` in main dependencies** — Should be dev-only

---

## 3. Changes Made

### Commit 1: Remove debug logging
**Files changed:** 12 files
**Summary:** Removed 62 `print()` and `debugPrint()` statements across the entire project. Kept `onLog` callbacks in Agora service as they feed the in-app debug UI, not the console. Also removed unused `import 'package:flutter/foundation.dart'` from `moderation_service.dart`.

**Files:**
- `lib/features/call/screens/call_screen.dart` — 4 prints removed
- `lib/features/call/services/agora_service.dart` — 13 prints removed
- `lib/features/call/services/request_service.dart` — 6 prints removed
- `lib/features/call/screens/match_radar_screen.dart` — 11 prints removed
- `lib/features/wallet/services/wallet_service.dart` — 9 debugPrints removed
- `lib/features/wallet/screens/payment_settings_screen.dart` — 1 debugPrint removed
- `lib/features/auth/services/user_service.dart` — 3 prints removed
- `lib/features/profile/services/moderation_service.dart` — 4 debugPrints + unused import removed
- `lib/features/profile/services/session_service.dart` — 1 print removed
- `lib/features/listener/screens/listener_active_call_screen.dart` — 3 prints removed
- `lib/features/listener/screens/listener_dashboard_screen.dart` — 3 prints/debugPrints removed
- `lib/features/listener/screens/listener_incoming_call_screen.dart` — 4 prints removed

---

### Commit 2: Fix 8 critical bugs
**Files changed:** 7 files

#### Bug #1: Broken Signup Recovery
**File:** `lib/features/auth/screens/signup_screen.dart`
**Problem:** If Firebase Auth succeeds but Firestore profile creation fails, user is authenticated with no profile. Every screen expecting user data would crash.
**Fix:** Wrapped Firestore creation in try-catch. If it fails, delete the Firebase Auth user (`user.delete()`) and rethrow.

#### Bug #2: Double Payment on Rapid Tap
**File:** `lib/features/call/screens/call_screen.dart`
**Problem:** If seeker taps confirm twice quickly in tipping dialog, `makePayment()` runs twice — double deduction.
**Fix:** Added `_paymentProcessed` boolean guard flag. Set to true before first payment, prevents re-entry.

#### Bug #3: Seeker Stuck on Radar Forever
**File:** `lib/features/call/screens/match_radar_screen.dart`
**Problem:** If no listener accepts, seeker stays on scanning screen indefinitely with no timeout.
**Fix:** Added 2-minute `Timer` that auto-cancels the request and navigates back to home with a SnackBar message.

#### Bug #4: State Machine Violation
**File:** `lib/features/call/services/request_service.dart`
**Problem:** `completeCall()` allowed `connected → completed` directly, skipping the `ending` state. Listener could still be in active Agora call when request is marked completed.
**Fix:** Removed `|| data['status'] == 'connected'` — only allow completion from `ending` state.

#### Bug #5: Memory Leak in Wallet Service
**File:** `lib/features/wallet/services/wallet_service.dart`
**Problem:** Firestore snapshot listeners created in `_listenToWallet()` but never stored or cancelled. On logout/re-login, old listeners stack up.
**Fix:** Added `StreamSubscription` fields (`_authSub`, `_balanceSub`, `_transactionsSub`). Cancel previous listeners on auth change. Cancel all in `dispose()`. Added `import 'dart:async'`.

#### Bug #6: Silent Payment Failure
**File:** `lib/features/wallet/services/wallet_service.dart`
**Problem:** `makePayment()` returned `void`. If balance insufficient, silently did nothing. Caller had no way to know payment failed.
**Fix:** Changed return type to `Future<bool>`. Returns `true` on success, `false` on insufficient balance or error. Updated `call_screen.dart` to handle the return value with appropriate SnackBar messages.

#### Bug #7: Listener Never Paid (FALSE ALARM)
**Status:** Not a real bug. `addEarnings()` IS called in `lib/features/listener/screens/listener_earnings_screen.dart:53`. The explore agent missed it.

#### Bug #8: Topics Not Synced When Going Online
**File:** `lib/features/listener/screens/listener_dashboard_screen.dart`
**Problem:** When listener toggles online, `_listenToOpenRequests()` is not called. They go online with potentially stale topic subscriptions.
**Fix:** Added `if (value) { _listenToOpenRequests(); }` inside `_toggleStatus()`.

#### Bug #9: Rejoin Navigation Wrong
**File:** `lib/features/home/screens/home_screen.dart`
**Problem:** If request status is `accepted`, rejoin button sends seeker to `CallScreen` instead of `MatchRadarScreen`. Causes broken/stuck call screen.
**Fix:** Added `|| activeRequest.status == 'accepted'` to the condition that routes to `MatchRadarScreen`.

---

## 4. Request Status State Machine

```
open → pending → accepted → connected → ending → completed
                                                → cancelled (from any state)
```

- `open`: Seeker created request, waiting for listener
- `pending`: Listener claimed the request
- `accepted`: Listener clicked "Accept & Earn"
- `connected`: Seeker clicked "Connect", both in call
- `ending`: Either user ended the call
- `completed`: Seeker submitted rating/tip/payment
- `cancelled`: Request was cancelled

---

## 5. Rejoin Call Feature — REMOVED (Session 2)

Rejoin call banners were removed from both `home_screen.dart` and `listener_dashboard_screen.dart`. The `streamActiveRequests()` method was also removed from `request_service.dart` as it was no longer needed.

---

## 6. Still TODO for Production

### CRITICAL (Do Before Launch)
- [ ] Move API keys to `.env` file, add `.env` to `.gitignore`
- [ ] Rotate Agora & Razorpay keys (already exposed in public repo)
- [x] ~~Tighten Firestore security rules (restrict by user ID)~~ — Done (Session 2)
- [ ] Set up Agora token server (currently using empty token)
- [ ] Switch Razorpay to live key (`rzp_live_...`)

### HIGH
- [ ] Add input validation (email format, password strength)
- [x] ~~Dispose TextEditingControllers~~ — Fixed in edit_profile_screen (Session 2)
- [ ] Add Firebase Crashlytics for crash reporting
- [ ] Write tests for critical flows (auth, wallet, call lifecycle)
- [ ] Add stale call cleanup (Cloud Function to auto-end after 30 min inactivity)
- [ ] Document webhook secret setup (`firebase functions:config:set razorpay.webhook_secret`)

### MEDIUM
- [ ] Use `cached_network_image` package for network images
- [ ] Move `device_preview` to dev_dependencies
- [ ] Add "other user left" notification
- [ ] Extract SharedPreferences initialization to singleton service
- [ ] Add proper logging framework (replace removed prints with `logger` package)

---

## 7. Project Structure

```
lib/
  core/
    constants.dart          — API keys, session costs
    theme.dart              — MidnightTheme colors and styles
  features/
    auth/
      models/user_model.dart
      repositories/          — (empty, auth_repository is in services)
      screens/login_screen.dart, signup_screen.dart
      services/auth_repository.dart, user_service.dart
    call/
      models/help_request.dart, listener_model.dart
      screens/call_screen.dart, match_radar_screen.dart
      services/agora_service.dart, request_service.dart
    home/
      screens/home_screen.dart
    listener/
      screens/
        listener_active_call_screen.dart
        listener_dashboard_screen.dart
        listener_earnings_screen.dart
        listener_incoming_call_screen.dart
        listener_waiting_payment_screen.dart
        rating_history_screen.dart
        session_history_screen.dart
    profile/
      screens/profile_screen.dart, edit_profile_screen.dart
      services/moderation_service.dart, session_service.dart
    wallet/
      models/transaction_model.dart
      screens/wallet_screen.dart, payment_settings_screen.dart
      services/wallet_service.dart
```

---

## 8. Key Architecture Decisions

- **State Management:** Singleton + ChangeNotifier (WalletService), direct Firestore streams elsewhere
- **Auth:** Firebase Auth with email/password
- **Voice Calls:** Agora RTC Engine (audio only, no video)
- **Payments:** Razorpay for top-ups, Firestore transactions for in-app payments
- **Moderation:** Reports stored in `reports` collection, blocks in `blocks` collection + user's `blockedUsers` array

---

## 9. Git Push Method

Using Personal Access Token (PAT) since the machine's Git account (`admin-cureo`) doesn't have push access to `Adhinc/midnight-app`.

**Steps:**
1. Generate token: GitHub → Settings → Developer Settings → Personal Access Tokens → Tokens (classic)
2. Push: `git push https://<TOKEN>@github.com/Adhinc/midnight-app.git main`
3. Delete token from GitHub immediately after push

**Important:** Always delete the token after use. Tokens grant access to ALL repos under the account, not just one.

---

## Session 2: 2026-03-09

### Commit 1: End-call confirmation + remove rejoin banners
**Files changed:** 6 files

- Added "End Call?" confirmation dialog on both seeker (`call_screen.dart`) and listener (`listener_active_call_screen.dart`) sides
- Removed rejoin call banners from `home_screen.dart` and `listener_dashboard_screen.dart`
- Removed unused `streamActiveRequests()` from `request_service.dart`
- Added TODO comment for `cleanupStaleCalls` in `functions/index.js`

### Commit 2: Fix 18 bugs across security, payments, and stability
**Files changed:** 12 files (+259, -116 lines)

#### Security (4 fixes)
1. **Firestore rules hardened** — Restrict request read/write to seeker/listener only; listeners can read open requests for matching; block client-side `isPaid` changes
2. **Negative balance prevention** — Added `walletBalance >= 0` rule in Firestore
3. **Transaction records secured** — Clients can create but not update/delete transaction records
4. **Tip/rating validation** — Tip clamped to 0-1000, rating to 0-5 on both client and service level

#### Payments (4 fixes)
5. **Tip payment lost** — Combined base + tip into single `addEarnings()` call to avoid `isPaid` flag blocking the tip
6. **Payment + completion atomic** — New `makePaymentAndCompleteCall()` method wraps wallet deduction + request completion in single Firestore transaction
7. **Live balance check** — Fetch balance from Firestore before creating request, not just cached value
8. **Cancel all active requests** — `createRequest()` now cancels `open`, `pending`, and `accepted` requests (was only `open`)

#### Stability (10 fixes)
9. **Stream subscription leaks** — Store and cancel auth + request subscriptions in `listener_dashboard_screen.dart` dispose
10. **Agora callback leaks** — Clear all Agora callbacks (`onLog`, `onJoinChannelSuccess`, `onError`, `onUserJoined`) in dispose on both call screens
11. **Bogus stream cancel removed** — Removed line that created a new stream just to cancel it in `call_screen.dart`
12. **PopScope on call screens** — Back button now triggers end-call confirmation instead of bypassing it
13. **Listener payment timeout** — 2-minute timeout on `listener_waiting_payment_screen.dart`; auto-navigates to earnings if seeker doesn't pay
14. **Duplicate earnings guard** — Added `_hasAddedEarnings` flag in `listener_earnings_screen.dart`
15. **Mounted check after image picker** — Prevents setState crash in `edit_profile_screen.dart`
16. **Error feedback on failed earnings** — `addEarnings()` returns bool; shows red snackbar on failure
17. **Block operation atomic** — Used Firestore batch write in `moderation_service.dart`
18. **Account deletion order** — Delete auth first, then Firestore data (prevents orphaned data)
19. **Dead code removed** — Unused `_RatingBar` widget and `_currentRating` field

### Commit 3: Payment gateway fixes
**Files changed:** 3 files

20. **Payment error feedback** — Added `onPaymentError` callback to `WalletService`; wallet screen shows red snackbar on Razorpay payment failure
21. **Webhook 400 on missing userId** — Changed from 200 to 400 response when userId is missing in payment notes

### Firestore Index (Manual)
- Created composite index in Firebase Console: `requests` collection — `listenerId` (Asc), `status` (Asc), `timestamp` (Desc)
