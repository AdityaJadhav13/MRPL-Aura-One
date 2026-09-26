# Admin surface — device capture

Captured on an iPhone 16 Pro simulator (iOS 18.6) from a development build,
phase UI-SURFACE-01-ADMIN. Goldens do not model safe-area inset, so these
exist to catch what the test renderer cannot: hero overflow under a notch,
real font rasterisation, and how a claim reads on a physical-sized screen.

| # | Screen | Route |
|---|---|---|
| 01 | Administration home | `/admin` |
| 02 | Integration status | `/admin/integrations` |
| 03 | Integration detail | `/admin/integrations/ptw` |
| 04 | Users and roles | `/admin/users` |
| 05 | User detail | `/admin/users/CT-45832` |
| 06 | Sites | `/admin/sites` |
| 07 | Departments | `/admin/departments` |
| 08 | Work areas | `/admin/work-areas` |
| 09 | Organisation configuration | `/admin/organisation` |
| 10 | Retention | `/admin/retention` |
| 11 | Devices | `/admin/devices` |
| 12 | Device detail | `/admin/devices/DEV-8841` |
| 13 | Versions | `/admin/versions` |
| 14 | Sync health | `/admin/sync` |
| 15 | Calibration administration | `/admin/calibration` |
| 16 | Badge configuration | `/admin/badges` |
| 17 | Demo data controls | `/admin/demo-data` (dev only) |
| 18 | System information | `/admin/system` |

Every identifier visible in these captures is invented demonstration data. No
MRPL employee record, gate pass, permit number or internal system name appears
in any of them.
