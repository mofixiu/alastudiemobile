# aLaStudie

aLaStudie is a local-first study-room app for iOS and Android. Its former product name was StudyRoom. The app uses a light, warm canvas with marine-blue structure, bright-red actions, oversized typography, and an intentionally asymmetric layout.

## Run locally

1. Clone and follow the [aLaStudie backend README](https://github.com/mofixiu/alastudiebackend/blob/main/README.md) to initialize and start the local PostgreSQL database and API.
2. In this directory, run `flutter pub get` and then `flutter run` on an Android emulator or iOS simulator.
3. Android Emulator uses `http://10.0.2.2:4000`; iOS Simulator uses `http://127.0.0.1:4000`. For a physical phone, pass the development computer's LAN address with `--dart-define=API_BASE_URL=http://<computer-ip>:4000`.
4. Verification and reset codes are stored in the local development mailbox at `http://localhost:4000/dev/mailbox?email=<account-email>`.

You can select **Explore the local preview** from sign-in to browse sample screens without creating an account. Preview changes are temporary and are not sent to the API.

## Build

Run `flutter build apk --release` for Android, or `flutter build ios --release --no-codesign` for an unsigned iOS build. iOS 15 or later is required. Store signing and cloud delivery are not configured in this local MVP.

## Tests

Run `flutter test` for client model, date calculation, and key branded-widget checks. The API integration suite and its disposable test-database setup are documented in [`aLaStudieBackend/README.md`](../aLaStudieBackend/README.md).

## Local-only services

The Flutter client uses REST for durable changes, Socket.IO for live room updates, SQLite for recent cached data and its offline outbox, and secure device storage for the access token. The backend uses a single local PostgreSQL instance and a PostgreSQL-backed development mailbox. No cloud, paid, email-delivery, or push-notification services are configured.
