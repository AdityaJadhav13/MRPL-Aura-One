# DoseBand — passive H₂S exposure monitoring

**MRPL Aura One** · Smart India Hackathon 2026 · Problem statement 26118 (MRPL)

A worker wears a disposable colorimetric badge (the **DoseBand**) through a shift. Its
chemistry darkens with accumulated hydrogen sulfide. At the end of the shift a phone
photographs the band and the app turns that photograph into a cumulative exposure record —
**or refuses, and says why**.

The refusal is the product. A confident number from a scan that could not support it would
land on a worker's exposure record and be believed. The system is built so that this cannot
happen by accident:

- The scientific core (`measurement-engine/`) has no Flutter dependency, so a dose cannot be
  computed inside a widget.
- `MeasurementResult` is a sealed type. Only the valid states have a dose field.
- A database `CHECK` constraint makes "not valid, but has a dose" unrepresentable.
- Reference patches are split: some fit the colour correction, others are withheld to test it.
- Without a signed, validated calibration model, no dose is produced at all.

> **Status — 0.4.0+4.** The application, the measurement pipeline and the role-based
> workspaces work on-device with presentation data. **No production calibration exists yet**:
> the chemistry and optical validation gates (M0C, S1–S3) are open, so the app reports
> "no reading" rather than a ppm·h value. See [PROJECT_STATE.md](PROJECT_STATE.md).

DoseBand is a cumulative occupational-exposure record. It does **not** replace certified
portable or fixed H₂S detectors, site alarms, PPE, permit-to-work controls or emergency
procedures.

## Repository layout

```
.
├── app/                    Flutter application — every screen, workflow and workspace
│   ├── lib/core/           design system, routing, environment, shared domain
│   ├── lib/features/       auth, home, scan, capture, history, safety, profile,
│   │                       supervisor, hse, management, admin, operations store
│   ├── test/               unit, widget, journey and golden tests
│   └── android/ ios/ …     platform projects (dev / staging / prod flavours)
│
├── measurement-engine/     Scientific core — pure Dart, no Flutter
│   ├── lib/src/imaging/        image decoding, rectification        (image processing)
│   ├── lib/src/geometry/       fiducial detection, homography, badge geometry
│   ├── lib/src/colour/         sRGB → CIELAB, ΔE, reference colour correction
│   ├── lib/src/linalg/         matrix algebra                        (mathematics)
│   ├── lib/src/calibration/    calibration model interface           (calibration)
│   ├── lib/src/features/       region-of-interest sampling and statistics
│   ├── lib/src/quality/        image and acquisition quality gates
│   ├── lib/src/validity/       typed measurement results and refusals
│   ├── geometry/               canonical badge geometry (source of truth)
│   ├── golden-vectors/         independent Python reference + cross-language vectors
│   ├── badge-print/            printable badge target
│   └── test/ tool/             engine tests; geometry / vector / print generators
│
├── backend/
│   └── supabase/           PostgreSQL schema, result invariants, database tests
│
├── research/               validation protocols, open scientific gates, dossier
├── docs/                   architecture, decisions (ADRs), design, product, engineering
└── dist/                   release checksums (APKs are built, not committed)
```

## Build and test

Requires Flutter 3.47.5 (Dart 3.13). From the repository root:

```bash
flutter pub get                                   # resolves the whole workspace

cd app
flutter run --flavor dev -t lib/main_dev.dart     # run the app
flutter test                                      # app tests (1 052)
flutter build apk --release --flavor dev -t lib/main_dev.dart

cd ../measurement-engine
dart test                                         # scientific core (312), headless

cd golden-vectors
python3 check_parity.py                           # Dart ⇄ Python parity (394 comparisons)
```

Three flavours — `dev`, `staging`, `prod` — with separate application IDs. Simulation and
presentation accounts are unavailable in `prod` by construction.

## Start here

| Document | What it covers |
|---|---|
| [PROJECT_STATE.md](PROJECT_STATE.md) | Current state, open gates, next steps |
| [docs/architecture/overview.md](docs/architecture/overview.md) | The whole design |
| [docs/computer-vision/pipeline.md](docs/computer-vision/pipeline.md) | The measurement pipeline, stage by stage |
| [docs/decisions/](docs/decisions/) | Architecture decision records |
| [docs/product/](docs/product/) | Roles, lifecycles, privacy, release notes |
| [research/](research/) | M0C protocol and the S1–S3 scientific gates |

## Honesty rules the code enforces

- No reading is never shown as zero.
- No ppm or ppm·h value is shown without a validated calibration.
- Simulated data is always labelled as simulated.
- Nothing claims an area is "safe", or that DoseBand approves a permit.
- Enterprise integrations (MRPL identity, permit systems, central server) are shown as not
  connected, never faked.
