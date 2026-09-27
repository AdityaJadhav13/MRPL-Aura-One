# SIH judge journey — Product Build v1

One phone, the dev-flavour release APK, a printed DoseBand target and a
printed or on-screen QR label (Profile → Developer and research tools →
DoseBand QR labels). No H₂S is generated at any point; any exposed specimen
used must come from qualified laboratory work.

Sign in with an ID and the presentation password held by the team, or use
**Presentation accounts** on the sign-in screen (development builds only).

| # | Step | Account | What the judge should see |
|---|---|---|---|
| 1 | Launch | — | White splash, straight to sign-in |
| 2 | Sign in as worker | Aditya Jadhav (CT-45832) | Lands on Home; no role picker |
| 3–4 | Home state A | | Name, ID, company; "No DoseBand assigned"; today's work |
| — | Record today's work | | Site, area, shift pre-filled from the company record; add job, PTW, JSA |
| 5 | Scan new DoseBand | | Camera viewfinder; label scanned (or serial typed) |
| 6 | Pre-use check | | Registry checks pass; photograph the band; READY / REPLACE / CANNOT VERIFY. Optional: scan `DB-2608-0001` (expired lot) or `DB-2609-0001` (worn by Lavitra) to show REPLACE without naming anyone |
| 7–8 | Assign this DoseBand | | Home state C: band, start time, duration |
| 9 | Kill and relaunch the app | | Still monitoring, same start time |
| 10 | Complete monitoring & scan | | Confirm end; scan the assigned band's QR |
| 11–14 | Final photograph | | Live guidance; Capture enabled when ready |
| 15 | Result | | "Optical measurement completed. Quantitative H₂S calibration is not available…" — no number; disposal instruction |
| 16–17 | History | | The record, its state and "awaiting review" |
| 18–19 | Sign out; sign in as supervisor | Aman Singh | Team today: Aditya completed, Lavitra monitoring, Nikhil needs attention (final scan overdue) — counts add up |
| 20 | Sign in as HSE | Samhita Hejmadi | Register → Aditya's record → eight-step traceability; move review; copy CSV |
| 21 | Sign in as management | Yashvi Chotalia | Coverage and states, no names or IDs; exposure statistics withheld |
| 22 | Switch workspace to Administrator | Yashvi Chotalia | Inventory by lot, the band now "read", QR label; people and roles; no exposure records |

Reset between runs: Administrator → More → Presentation data → Reset.

What to say: every screen is working against one set of records on this
phone. The central server, organisation identity and quantitative
calibration are not connected or not validated, and the app says so rather
than showing a number it cannot defend.
