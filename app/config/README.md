# Build-time configuration

`presentation.local.json` (git-ignored) holds the password of the
presentation accounts. A development / presentation build reads it so that
Sign In opens with the presentation account filled in:

```bash
cp config/presentation.example.json config/presentation.local.json   # then edit
flutter build apk --release --flavor dev -t lib/main_dev.dart \
  --dart-define-from-file=config/presentation.local.json
```

The password is never committed. Without the file the app builds and runs
normally; the sign-in fields are simply empty. Production builds ignore it:
they offer no presentation accounts at all.

The value is checked against the salted PBKDF2 verifier in
`lib/features/auth/domain/identity.dart`, exactly like a typed password.
