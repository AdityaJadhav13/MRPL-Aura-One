# Foundation — APP-PRODUCT-01 Phase 0

**Rendered by the Flutter test renderer, not captured on a device.** These are
copies of the reviewed foundation goldens
(`app/test/golden/goldens/foundation-*.png`, produced by
`app/test/golden/foundation_golden_test.dart`) at the sizes shown. The brand
photograph is decoded before capture. The renderer models system insets only
where the test sets them (390/430 shells carry a 34-point gesture inset), and
its font rasterisation is not a phone's.

Physical-device captures for this phase are listed in the Phase 0 completion
report; if none are listed, physical validation was blocked.

| # | What | Size (logical) | Text |
|---|---|---|---|
| 01 | Worker shell — Home | 360×640 | 100% |
| 02 | Worker shell — Home | 390×844, gesture inset | 100% |
| 03 | Worker shell — Home | 430×932, gesture inset | 100% |
| 04 | Worker shell — Home | 320×568 | **200%** |
| 05 | Worker shell — History (empty) | 360×640 | **200%** |
| 06 | Worker shell — Safety | 600×960 (small tablet, bottom bar) | 100% |
| 07 | Worker shell — Home, **navigation rail** | 1280×800 | 100% |
| 08 | Worker shell — Home, landscape (rail) | 844×390 | 100% |
| 09 | Worker shell — Scan | 390×844 | 100% |
| 10 | Worker shell — Profile | 390×844 | 100% |
| 11 | Catalog — palette | 390 wide | 100% |
| 12 | Catalog — typography | 390 wide | 100% |
| 13 | Catalog — buttons (all variants, loading, disabled) | 390 wide | 100% |
| 14 | Catalog — inputs (helper, error, loading, disabled, read-only) | 390 wide | 100% |
| 15 | Catalog — cards and status banners | 390 wide | 100% |
| 16 | Catalog — status, provenance and sync chips | 390 wide | 100% |
| 17 | Catalog — identity (initials; no invented photo) | 390 wide | 100% |
| 18 | Catalog — records as cards (phone) | 390 wide | 100% |
| 19 | Catalog — records as a table (wide) | 900 wide | 100% |
| 20 | State — empty | 360×640 | 100% |
| 21 | State — offline, inside the worker shell | 360×640 | 100% |
| 22 | State — error with a retry | 360×640 | 100% |
| 23 | State — not connected | 360×640 | 100% |

Legacy Home (01–04, 07, 08) still carries P3 debt visible here: the green
monitoring card, the "Safe People" slogan, and mid-word wrapping in the hero at
320/200%. See `docs/engineering/ui-foundation-debt.md`.
