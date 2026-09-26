# DoseBand — functional gaps at UI freeze

**UI COMPLETE is not FUNCTIONAL.** This file exists so the distinction cannot be
lost: the interface for the items below is finished, reviewed and frozen, and
the functionality behind them does not exist.

None of these is a UI defect. Every one is visible in the product as an explicit
statement of absence — that is the design.

## Scientific

| Gate | State | What it blocks |
|---|---|---|
| **M0C** | OPEN | No smartphone has photographed a printed target through this application. No device can be marked validated for measurement. |
| **S1** | OPEN | Passive uptake at a known, reproducible rate is unestablished. |
| **S2** | OPEN | Colour change as a faithful integral of exposure is unestablished. |
| **S3** | OPEN | Selectivity and interference behaviour are unestablished. |

Consequently there is **no production H₂S calibration**, **no production ppm·h
model**, and no validated accuracy, LoD, LoQ, uncertainty interval or validated
range. Every quantitative figure in the product is a `SimulatedExposure` and is
marked as such at the point it is rendered.

## Platform

| Capability | State |
|---|---|
| Backend service | Not implemented. Records live on the device that produced them. |
| Production authentication | Not implemented. One published demo account, verified by nothing. |
| Production RBAC | Not implemented. The role selector is a review convenience; routing by role is not authorisation. |
| Report export | Not implemented. Previews only; nothing is generated, downloaded or submitted. |
| Report signing | Not implemented. No signing keys are held. |
| QR badge recognition | Not implemented. Badge identifiers are entered by hand. |
| Record database | Not implemented. |

## Enterprise integrations

All eleven are **Not connected**, and `IntegrationState` has no `connected`
value to slip into: enterprise identity, gate pass, PTW, JSA, hazard reporting,
occupational health, document repository, backend, ERP, report export,
calibration distribution.

DoseBand makes no network request and holds no endpoint.

## Organisation configuration

| Item | State |
|---|---|
| Retention policies | 0 of 6 record types configured. No default period ships. |
| Emergency information | Not configured. No contact, assembly point or route is invented. |
| Device validation | 0 of 3 devices validated (blocked by M0C). |

## Content

Three site photographs are outstanding. Image slots, aspect ratios, crop
behaviour, overlay readability and fallback state are complete and audited; the
photographs themselves are a post-freeze content task.
