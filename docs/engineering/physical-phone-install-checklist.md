# Physical phone — install checklist

For the first physical session. Target: 10 minutes from unboxed phone to first
capture.

## Artefacts

| File | Use |
|---|---|
| `dist/doseband-m0c-ready-0.2.0+2-dev-release.apk` | **Use this.** AOT-compiled; fast enough for dozens of captures. |
| `dist/doseband-m0c-ready-0.2.0+2-dev-debug.apk` | Fallback if the release build misbehaves. Slower. Allows `run-as` data pull. |
| `dist/SHA256SUMS` | Verify before installing: `cd dist && shasum -a 256 -c SHA256SUMS` |

Package `in.doseband.h2s.dev` · version `0.2.0-dev` (code 2) · app label
**DoseBand Dev**. Only one of the two can be installed at a time — they share a
package id.

## 1. Phone

1. Settings → About phone → tap **Build number** seven times.
2. Settings → Developer options → enable **USB debugging**.
3. Connect by USB. **Tap "Allow" on the phone's USB-debugging prompt.**
   Tick "Always allow from this computer".

> On 2026-09-26 the phone `RZCX817DGHM` was attached but showed
> `unauthorized` all session — step 3 had not been done.

## 2. Computer

```
adb devices                 # must say "device", not "unauthorized"
flutter devices             # the phone should be listed
adb install -r dist/doseband-m0c-ready-0.2.0+2-dev-release.apk
```

`adb` lives at `~/Library/Android/sdk/platform-tools/adb` if it is not on PATH.

## 3. First launch

1. Open **DoseBand Dev**. Sign in with the published demo account.
2. Open the worker's identity card (Home) → **Profile**.
3. Check the **Environment** block says `dev`, and **Build** shows
   App `0.2.0+2`, Algorithm `m0a`, Features `fdv-0.2.0-m0b`.
4. Tap **Physical capture test**.
5. Enter a specimen ID, e.g. `P0-X0-01`. Tap **Open camera**.
6. **Grant camera permission** when asked. It is the only permission the app
   asks for — no microphone, no storage.

## 4. Capture and find it again

1. Aim at the target, follow the on-screen instruction, press **Take photo**.
2. The diagnostics screen opens. Read the verdict at the top.
3. **Save capture** (refusals too — they are evidence).
4. The camera returns with live guidance for the next shot.
5. Back on the setup screen, the folder icon opens **Research captures**.

## 5. Getting data off the phone

**Share sheet (either build):** Research captures → share icon on a row (one
capture: `record.json`, `original.jpg`, `rectified.png`), or the top-bar share
icon (the session manifest — every record, no images).

**Bulk pull (debug build only):**

```
adb exec-out run-as in.doseband.h2s.dev tar c -C app_flutter dossier-v0 > captures.tar
```

`run-as` needs a debuggable build, so this does not work with the release APK.

## If something goes wrong

| Symptom | First check |
|---|---|
| `unauthorized` | Unlock the phone and accept the USB-debugging prompt |
| Install fails with signature conflict | `adb uninstall in.doseband.h2s.dev`, then install again |
| "Camera unavailable" | Permission denied — Settings → Apps → DoseBand Dev → Permissions |
| "Capture NOT saved" dialog | Read the message; usually a duplicate capture id within the same millisecond |
| Release build crashes on open | Install the debug APK instead and report it: release runs R8 minification, which could not be tested on a device before the session |

## Rebuilding tomorrow

**Bump the build number in `app/pubspec.yaml` and `lib/core/env/app_version.dart`
before any rebuild** that will photograph a specimen. Two builds carrying the
same version make their captures indistinguishable. A test fails if the two
files disagree.

```
cd app
flutter build apk --release --flavor dev -t lib/main_dev.dart
```

Check free disk first: the release build needs about 1.5 GB of headroom, and a
debug build more.
