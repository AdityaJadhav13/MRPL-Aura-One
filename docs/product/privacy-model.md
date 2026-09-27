# Privacy and authorisation model — as implemented

**Enforcement level: local policy in the operations services. SERVER
ENFORCEMENT PENDING — there is no server.**

## Data classes

| Class | Contents | Who |
|---|---|---|
| A — identified occupational | identity, ID, assignment, work context, identified records | worker: self · supervisor: explicit team · HSE: granted site |
| B — de-identified exposure | aggregates, distributions, trends | management (organisation) |
| C — system / operational | accounts and roles, lots, bands (no holder), configuration, versions, audit | administrator |

## How it is enforced

* Every view/command constructor checks the actor against the store: the
  person exists, is active, holds the role, and has a scope grant for it. A
  forged role claim gets nothing (`authorization_test.dart`).
* Supervisor scope is the team whose `supervisorId` is the actor *and* which
  the grant names — department alone never authorises (§146).
* HSE scope is the site grant; another site sees nothing.
* `ManagementView` returns types with no identity fields; breakdown cells
  under three are shown as "<3".
* `AdminView` has no method returning a session, assignment or record; the
  band list carries state, never the holder; audit rows withhold the person
  for occupational actions.
* Refusals for "someone else's record" and "no such record" are the same
  message.
* Route gate keeps each role in its own workspace; unknown record IDs in
  URLs render a permission state, never a crash.

## Mobile permissions (release APK 0.3.0+3)

`CAMERA` (runtime, for QR and optical workflows) · `INTERNET` (install-time,
pre-existing in the main manifest for the future backend; the app makes no
network requests today) · AndroidX dynamic-receiver internal permission. No
microphone, storage or location permission.

## Location

No GPS, no location permission, no worker tracking. Location is the recorded
site / department / work area of the work context.

## Credentials

No password in source, in any store, or in any log. Presentation accounts are
checked against salted PBKDF2 verifiers. The session file holds person and
role only. Local files are app-private and **not encrypted**; this is stated,
not hidden.
