# DoseBand — product screenshot review set

Captured on an iPhone 16 Pro simulator (iOS 18.6) from a development build
during **UI-SURFACE-01-FINAL-AUDIT**. One or more representative screens per
module, chosen so that a reviewer can walk the whole product without running it.

Goldens do not model safe-area inset or real font rasterisation, which is why
this set exists alongside them.

| # | Module | Screen | Route |
|---|---|---|---|
| 01 | Auth | Splash | `/splash` |
| 02 | Auth | Sign in | `/sign-in` |
| 03 | Auth | Site selection | `/select-site` |
| 04 | Auth | Role selection | `/select-role` |
| 05 | Worker | Home | `/home` |
| 06 | Worker | Work context | `/work-context` |
| 07 | Worker | Active monitoring | `/active` |
| 08 | Worker | Guided scan | `/read` |
| 09 | Safety | Safety hub | `/safety` |
| 10 | Safety | Emergency | `/safety/emergency` |
| 11 | HSE | Dashboard | `/hse` |
| 12 | HSE | Exposure register | `/hse/exposures` |
| 13 | Reporting | Reporting centre | `/reporting` |
| 14 | Reporting | Occupational exposure register | `/reporting/register` |
| 15 | Reporting | Report builder | `/reporting/builder` |
| 16 | Admin | Overview | `/admin` |
| 17 | Admin | Integration status | `/admin/integrations` |
| 18 | Admin | Calibration administration | `/admin/calibration` |

The Admin module has its own fuller set in `../admin/`.

Every identifier visible in these captures is invented demonstration data. No
MRPL employee record, gate pass, permit number or internal system name appears
in any of them.
