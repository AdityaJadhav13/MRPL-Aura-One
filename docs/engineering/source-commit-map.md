# Source commit map

Before the repository was published, third-party reference material that had been
committed for design comparison was removed from every commit. Removing a file from
history gives every later commit a new identifier, so release notes and
`dist/SHA256SUMS` written earlier cite commits that no longer exist in the published history.

The file contents that build the app are unchanged; only that reference folder, which was
never part of any build, was removed. The equivalent published commits are:

| Cited in release notes | Published commit | Artifact |
|---|---|---|
| `5b5630f` | `19dab77` | doseband-mi02-0.2.0+2 (dev release) |
| `8aa5355` | `f662ed3` | doseband-productbuild1-0.3.0+3 (dev release) |
| `c5429cf` | `3ef3af6` | doseband-productbuild1-ui-recovery-0.4.0+4 (dev release) |

The APK checksums in `dist/SHA256SUMS` are unaffected: they identify the binaries, not
commits.
