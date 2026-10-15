# Release signing (Play-ready keystore)

Ordin ships as a Flutter Android app under `apps/flutter`. CI builds an **unsigned or debug-signed** release APK for verification. Store distribution requires a **dedicated upload keystore** that is never committed to git.

## What CI does today

The `Flutter APK Build` workflow runs:

```text
gradle --no-daemon -p android assembleRelease
```

That produces `apps/flutter/build/app/outputs/flutter-apk/app-release.apk` and uploads it as an artifact. It does **not** inject a production keystore.

## One-time keystore creation (maintainer machine)

```bash
keytool -genkey -v \
  -keystore ordin-upload.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias ordin_upload
```

Store `ordin-upload.jks` and its passwords in a password manager. **Do not** add the JKS file to the repository.

## Local release build with signing

1. Create `apps/flutter/android/key.properties` (gitignored):

```properties
storePassword=***
keyPassword=***
keyAlias=ordin_upload
storeFile=/absolute/path/to/ordin-upload.jks
```

2. Ensure `android/app/build.gradle` loads `key.properties` for the `release` signingConfig (standard Flutter template pattern).

3. Build:

```bash
cd apps/flutter
flutter build apk --release
# or
flutter build appbundle --release
```

Prefer **AAB** (`appbundle`) for Play Console uploads.

## CI secrets (optional later)

If automated Play uploads are desired:

- Store the JKS as a base64 GitHub Actions secret (e.g. `ANDROID_KEYSTORE_BASE64`).
- Store passwords as secrets (`ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_PASSWORD`, `ANDROID_KEY_ALIAS`).
- Decode the JKS in the workflow and pass signing properties to Gradle.

Until then, ship from a maintainer machine with the local keystore.

## Play Console notes

- Enroll in **Play App Signing**; Google holds the app signing key; you keep the upload key.
- If the upload key is lost, use Play’s upload-key reset process — do not generate a second keystore under the same package name without following that flow.
- Package name and `applicationId` must stay stable across releases.

## Checklist before first public release

- [ ] Upload keystore created and backed up offline
- [ ] `key.properties` present locally and listed in `.gitignore`
- [ ] `flutter build appbundle --release` succeeds
- [ ] AAB uploaded to an internal testing track
- [ ] Version `version:` / `versionCode` in `pubspec.yaml` bumped for each store push
