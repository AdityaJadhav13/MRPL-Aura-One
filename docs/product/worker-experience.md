# Worker experience — 0.5.0+5

How a worker gets into DoseBand and what they find there. The Sign In,
Select Site and Select Your Role screens are rebuilt from the approved design
(baseline `7bed0e4`). History, Scan and the five-item navigation are
unchanged: their goldens are byte-identical to 0.4.0+4.

## Getting in

```
Splash ─► Sign In ─┬─ existing account ──────────────────────► its workspace
                   │                                          (several roles:
                   │                                           Select Your Role,
                   │                                           own roles only)
                   └─ New user ─► Select Site ─► Select Your Role ─► Sign In
                                                                  (setup mode)
```

A returning person with a remembered session goes from Splash straight to
their workspace.

### Identity, then authorization

| Step | Checked against | Failure | Message |
|---|---|---|---|
| Credentials | Salted PBKDF2 verifier | `invalidCredentials` | "Unable to sign in with those credentials. Check your User ID and password and try again." |
| Employee / Contractor | The directory's worker type | `invalidCredentials` (reveals nothing) | as above |
| Requested role (setup) | The directory's granted roles | `roleNotAuthorised` | "This account is not authorized for the selected role. Select your assigned role and try again." |
| Selected site (setup) | The account's assigned site | `siteNotAuthorised` | "This account is not assigned to the selected site. Select your assigned site and try again." |

Authorization is evaluated only after the credentials are accepted, so a
refusal never discloses what roles an ID holds. Selecting a role or a site
grants nothing. A multi-role account that signs in without a request is held
on Select Your Role by the route gate, and may confirm only its own roles.

Enforced in the session layer (`AuthController`, `RouteGate`) on this device.
**Server authorization enforcement is pending:** there is no server yet.

### Sign In details

| Control | Behaviour |
|---|---|
| Prefilled account | Presentation builds open with CT-45832 and its password filled in. The password comes from a git-ignored build-time define (`app/config/`), not source, and is verified like a typed one. |
| Remember me | On: the session is stored and restored. Off: nothing is written to disk. |
| Forgot password? | States that account recovery is unavailable in this environment and is handled by the account administrator. Sends nothing. |
| Presentation accounts | Development builds only. Fills the form with another sample account; the user still signs in. |
| Google sign-in | Not shown: nothing is configured. |
| Removed | DEMO badge, published-credentials card, Gate Pass and QR sign-in, Skip. |

## Inside: Home · History · Scan · Safety · Profile

**Home** answers only: *do I have a DoseBand, and what do I do next?*

| State | Card | Action |
|---|---|---|
| No band | NO DOSEBAND ASSIGNED, plus three start steps | Scan new DoseBand |
| Assigned (simulation only) | DOSEBAND ASSIGNED | Pre-work check |
| Monitoring | MONITORING ACTIVE — duration, start, band | Complete monitoring & scan |
| Ready for final read | READY FOR FINAL SCAN | Scan assigned DoseBand |
| Completed | TODAY’S MONITORING COMPLETE, disposal | View today’s record; Scan new DoseBand |
| Exception (e.g. the clock moved) | White card, orange edge, the actual problem | End monitoring and scan |

No ppm, no "safe", no profile details, no server notice.

**Profile** is the worker's own record:
- **Identity:** an approved photograph when supplied, initials until then.
- **Work assignment:** site, department, shift, work area, worker type,
  contractor, designation, team, supervisor, and the masked gate pass.
- **Work context:** as recorded by the worker; referenced, never approved.
- **Settings:** account and session; privacy; About (version and build from
  package metadata, environment, measurement engine, connection, licences);
  Sign out, which keeps every record.

**Developer and research tools** are not part of the worker experience. They
are reached from the Administrator's More screen, in development builds only.

## Safety

| Section | Status |
|---|---|
| Not-a-gas-alarm limitation (hub) | LOCAL_REAL — names detectors, fixed detection, alarms, PPE, PTW and emergency procedures |
| Hydrogen sulphide information | LOCAL_REAL — general and product statements; no limits or medical claims |
| Emergency | NOT_CONNECTED — generic guidance; empty slots, no numbers, maps or assembly points |
| Near miss / hazard | NOT_CONNECTED — handoff; submit disabled, nothing is sent |
| Occupational health | NOT_CONNECTED — the worker's own records; no clinical claim |
| Permit to Work / JSA | LOCAL_REAL — what DoseBand does not do; the recorded reference |
| PPE | NOT_CONNECTED — general categories; requirements not configured |
| Toolbox resources | NOT_CONNECTED — no library; points at site material |
| Safety data sheets | NOT_CONNECTED — no repository; points at the site SDS register |
| Offline documents | NOT_CONNECTED — nothing downloaded |

## Known debt

- On a 320 × 568 phone at 200 % text, Home's action is one scroll below the
  status card. Pinning it inside the worker shell broke the layout, so it
  stays in the list; the centre Scan button is always visible.
- No physical-device run: none was available.
- No server, so no cross-device authorization, sync or password recovery.
