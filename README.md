# Kantemba

Shop-management app for Zambian SMEs — cash book, point-of-sale, and
inventory tracker in one. Full product spec in `docs/blueprint.md`.

## Getting the app (no computer needed)

Every push to `main` automatically builds an installable APK in GitHub's
cloud — you never need to compile anything yourself.

1. Go to the **Actions** tab of this repo
2. Open the latest **Build APK** run (green checkmark = success)
3. Scroll down to **Artifacts** and tap **kantemba-apk**
4. It downloads as a `.zip` — open it, and inside is `app-release.apk`
5. Open that file on your Android phone and tap **Install**
   (you may need to allow "install unknown apps" for your browser/files app
   the first time — Android will prompt you if so)

## Project structure

- `lib/models/` — data model (Item, Sale, Creditor, etc.)
- `lib/db/database_helper.dart` — local SQLite database + all business logic
- `lib/screens/` — one file per screen
- `lib/widgets/` — shared UI pieces (stat cards, zebra rows, bottom sheets)
- `.github/workflows/build_apk.yml` — the free CI pipeline that builds the APK

## Why there's no `android/` or `ios/` folder in git

They're regenerated automatically on every build (`flutter create` in the
workflow) — pure boilerplate that doesn't need to be tracked. If you ever
work on this locally with Flutter installed, just run:

```
flutter create --platforms=android .
flutter pub get
```

and those folders will appear.
