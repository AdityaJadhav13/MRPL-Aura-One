# Canonical badge geometry

**This directory is the single source of truth for badge geometry.**

Geometry is data, never code: no ROI coordinate may appear in Dart source, so
that changing a badge layout is a data change with its own version rather than
a code change that silently reinterprets every historical measurement.

| File | |
|---|---|
| `badge-v1.geometry.json` | The research badge, printed for dossier V0 |
| `demo-badge-v0.geometry.json` | The artificial demo badge M0A was built against. Frozen — the cross-language golden vectors are generated from it. |

## Do not copy these files

The Flutter app cannot read them from here at runtime: a Flutter asset must
live inside the app package. They are therefore **exported**, not duplicated:

```bash
cd packages/measurement && dart run tool/export_geometry.dart
```

That writes `app/assets/geometry/` and a manifest carrying each file's
SHA-256. CI regenerates the export and fails if it differs from what is
committed, so the packaged asset cannot drift from the canonical definition
without someone noticing.

At runtime the app verifies the checksum before parsing. A geometry that does
not match its manifest is refused rather than used — a measurement made
against the wrong ROI coordinates is worse than no measurement, because
nothing downstream can tell.

## Changing a geometry

1. Edit the file here.
2. Bump `version`. **Never edit a published version in place.** A stored
   `geometryVersion` must always mean exactly one layout.
3. Re-run the export and commit both.
4. Re-run the printable target if the layout moved:
   `dart run tool/generate_printable_target.dart`.
