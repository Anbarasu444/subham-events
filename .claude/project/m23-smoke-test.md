# M23 — Android smoke test (run by the user)

Tick each line on your phone. Write ✗ and a short note (or a screenshot) for anything that looks wrong.

## Before you start
1. Mac and phone on the **same Wi-Fi**.
2. Start the backend on the Mac (`cd backend && npm run start:dev`), with migrations run (`npm run migration:run`).
3. Optional sample data: `npm run seed:dev-samples` and `npm run seed:dev-quotes`.
4. Phone plugged in by USB. Run `~/Library/Android/sdk/platform-tools/adb reverse tcp:3000 tcp:3000`, then from `user_app/`: `flutter run --flavor staging -t lib/main_staging.dart --dart-define=API_BASE_URL=http://localhost:3000 --dart-define=SUPPORT_EMAIL=test@gmail.com --dart-define=SUPPORT_PHONE=1234554321 --dart-define=PROFILE_PHOTO_ENABLED=true` (USB avoids the unreliable Wi-Fi path).
5. Timing: from tapping the app icon to seeing Home, note the seconds (cold start).

## Flows
- [x] Sign in with Google · [x] sign in with phone (OTP) — verified 2026-10-10
- [ ] Home: countdown, quick menu, charts, budget card look right
- [ ] Create an event · edit it · add a cover photo
- [ ] Checklist: add tasks with dates · month tabs · tick done/undo · reorder · "Remind me"
- [ ] Budget: set total · plan a category · add an expense · open a category's details
- [ ] Explore: search · filters · open a vendor · save (heart) · add to event
- [ ] Send an enquiry · (sample quote) accept it · Payments: add a payment · mark booking completed
- [ ] Rate the vendor
- [ ] Reminder: set one 2–3 minutes ahead · **push arrives** (app closed) · tapping it opens the event
- [ ] Invitation: create · publish · share link · open the link on **another phone on the same Wi-Fi** · reply · reply shows in the app
- [ ] Notifications centre · mark all read · Settings → Notifications
- [ ] My profile: change name · add a photo · My reviews · Help (email/call open)
- [ ] Offline: turn on **airplane mode** and open Home, Events, Checklist, Budget, Explore → each shows a message or saved data with "Try again", never a blank screen; turn it off → Try again works
- [ ] Stop the backend on the Mac → the app explains it can't reach the server
- [ ] Large text: phone Settings → font size largest → Home, Checklist, Budget, Menu readable, nothing cut off
- [ ] Delete account (type DELETE) → signed out → sign in again → account restored
- [ ] Sign out

## Report back
Cold-start seconds: ____ · Anything wrong: ____
