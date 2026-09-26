# Online / offline matrix

**Architecture: server-authoritative, offline-capable.** Not offline-only.

The phone can finish a monitoring period and read the band with no signal.
Anything that needs the whole organisation's view — uniqueness, team state,
registers — needs the server.

**Nothing in the "server" column exists yet (P10).** The app today reports
those capabilities as *not connected*; it does not simulate a connection or a
sync. Canonical states: `ConnectivityState` and `SyncState`
(`app/lib/core/domain/connectivity.dart`). The only sync states this build can
produce are `localOnly` and `notConnected`.

| Capability | Target behaviour | Needs | Today |
|---|---|---|---|
| Cached own profile | readable offline | local cache | Profile shows build/environment only; identity P1 |
| Cached current monitoring | readable and continuable offline | local store | **Works** — `FileWorkflowStore` restores the period at cold start |
| Claim an arbitrary fresh DoseBand | normally requires server authority | server | Not connected: `NotConnectedDoseBandRegistry`; simulated / manual-entry assignment only, labelled |
| Global uniqueness check | server, atomic | server | Not connected — **not faked locally** |
| Pre-use check (identity/lot/expiry parts) | server for registry facts; on-device for image checks | both | Not built (P2) |
| Final camera scan of the assigned DoseBand | offline-capable | device | **Works offline** for a physical band (real camera) |
| Measurement engine | on-device, offline | device | **Works offline** (`packages/measurement`) |
| Persist a completed local measurement | offline | local store | **Works** for the session; history database is P5 |
| Upload / synchronisation | queued until connectivity; `syncPending` → `synced` / `syncFailed` | server + queue | Not connected: records are `localOnly` |
| Supervisor authoritative live team state | server | server | Not built (P6) |
| HSE organisation register | server | server | Demonstration data only |
| Authoritative central reports | server | server | Demonstration data only; export disabled |
| Safety reference content | cached for offline | local cache | Static content bundled; organisation documents not connected |

## Language rules

| Situation | Say | Never |
|---|---|---|
| Offline, record stored | "Saved on this phone." (only after the write succeeded) | "Synced", "Uploaded" |
| Offline, server exists (P10) | "It will be sent when a connection is available." | — |
| No server exists | "No central server is connected. Records stay on this phone." | "Pending: 2" or any count |
| Upload failed | "Sending it failed. The reading is unaffected." | anything suggesting the measurement is invalid |
| Phone offline | "You're offline." | "Server error" |
| Server not answering | "The DoseBand server did not answer." | "You're offline" |

Offline is not a measurement failure, and a sync failure is not an invalid
measurement: they use the `info` and `attention` tones, never the measurement
refusal presentation (tested in `design_tokens_test.dart`,
`domain_foundation_test.dart`).
