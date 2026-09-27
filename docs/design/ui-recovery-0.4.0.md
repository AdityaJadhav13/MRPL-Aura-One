# UI recovery — 0.4.0+4

The corrective directive asked for three approved screens back (splash,
entry, the rich Worker Home) **as recovery, not redesign**, while keeping
the newer navigation, History and Scan. It was done by lifting the
presentation structure out of git history and binding it to the current
state model. There was no rollback: nothing outside the three screens
was reverted.

## Sources

| Screen | Recovered from | Current file |
|---|---|---|
| Worker Home cards | `0908b43` `home_cards.dart`, `home_screen.dart` | `app/lib/features/home/presentation/home_cards.dart`, `app/lib/features/home/home_screen.dart` |
| Splash | `5db5c70` `splash_screen.dart`, `auth_background.dart` | `app/lib/features/auth/presentation/screens/splash_screen.dart` |
| Entry header, footer wave | `5db5c70` `auth_brand_header.dart`, `auth_background.dart`, `role_selection_screen.dart` | `app/lib/features/auth/presentation/widgets/corporate_brand.dart`, `sign_in_screen.dart` |

## What came back

* **Home:**
  * the refinery header with "Safe People / Sustainable Operations";
  * an identity card overlapping it, showing name, type, ID, company and local / not-synced storage;
  * a TODAY'S SHIFT card showing Site, Department, Shift, Work area, Gate pass (masked) and Date;
  * a WORK CONTEXT card showing Job, PTW, JSA, Toolbox, Supervisor;
  * the strong green monitoring card, with the orange ACTIVE marker while a period runs;
  * one state-driven action.
* **Splash:**
  * full-screen refinery at dusk;
  * the MRPL mark and organisation on a plate;
  * the safety message with its orange rule;
  * the DoseBand lockup, with the orange progress bar, on a night-green band.
* **Entry:**
  * the MRPL header with "Refining for a Brighter Tomorrow";
  * a refinery strip with the DoseBand lockup;
  * the skyline footer wave;
  * the five role cards, now for presentation accounts, one card per person and role.

## What deliberately did not come back

| Old behaviour | Why | Now |
|---|---|---|
| DEMO chip on every Home row | Repetition taught people to ignore it | Simulation is marked once, where it applies (the band) |
| Supervisor string from demo data | Invented | Supervisor comes from the directory, or reads "Not recorded" |
| Static Home content | Ignored the workflow | Every value comes from the directory, the recorded context or the session |
| Gradients (splash fade, header, footer sweep) | No-gradient rule (§66; ratchet at 0) | Solid translucent scrims and panels |
| Four-tab dark navigation | Superseded | The five-item floating navigation, unchanged |
| Role picker as the sign-in | Roles come from the directory | ID + password; role cards only in the presentation-accounts sheet (non-production) |

## Rules the recovered screens keep

* Home never shows ppm or ppm·h. A green card means "monitoring", not "safe".
* Work context reads "Recorded by you. Not checked against a permit system; DoseBand does not authorise work."
* The toolbox talk reads "Acknowledged", never "completed".
* A gate pass is masked to its last four characters.
* Presentation accounts are described as sample accounts on this device, and no credentials are shown.

## Responsive behaviour

| Element | Behaviour |
|---|---|
| Home header | Stacks its two lockups below 340 px or above 130 % text; caps its own text scale at 150 % (brand only — content scales in full) |
| Identity card | Moves storage under the details below 340 px; stacks avatar over details above 130 % text |
| Splash | Caps text at 130 % (a transient composition; its message is also in the semantics label). Bounds the mark by height as well as width; plate at most 480 px wide. Scrolls rather than overflows |
| Sign-in | The footer wave follows the form and never covers it |

## Known trade-off

On a 390 × 844 phone, Home's primary action sits below the first screen,
because the directive fixes the order: shift, then work context, then the
monitoring card and the action. The centre Scan button in the navigation is
always visible and opens the contextual Scan for the same state.
