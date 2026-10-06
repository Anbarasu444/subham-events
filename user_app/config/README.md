# Flavor configuration

Non-secret, compile-time values passed with `--dart-define-from-file` (ADR-0012).
**Never put secrets here** — everything in these files ends up inside the app.

| File | Use |
|---|---|
| `staging.json` | Hosted staging API (placeholder until hosting is decided — ADR-0010) |
| `prod.json` | Production API (placeholder) |
| `staging.local.json` | Your local backend; git-ignored. Copy from `staging.local.json.example` |

`API_BASE_URL` for the local backend:

- Android emulator: `http://10.0.2.2:3000`
- iOS simulator: `http://localhost:3000`
- Physical phone: `http://<your-Mac-LAN-IP>:3000`

## Run

```sh
# Android (flavors)
flutter run --flavor staging -t lib/main_staging.dart --dart-define-from-file=config/staging.local.json

# iOS simulator (native iOS flavors arrive in M5 with Firebase)
flutter run -t lib/main_staging.dart --dart-define-from-file=config/staging.local.json
```
