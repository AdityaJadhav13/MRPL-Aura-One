# ADR-0009 — The measurement scale is logarithmic, and its ticks cull

**Status:** Accepted · 2026-09-19

## Context
The signature component shows a dose as a point between the quantification limit
and saturation. The provisional validated range is roughly 0.5–40 ppm·h — about
two decades — and the sensitive region (dossier: A1 ≈ 0.5–8 ppm·h) sits in the
bottom fifth of it.

On a linear axis a 1 ppm·h reading lands at 1.3% of the bar, indistinguishable
from the LoQ stop. The region the badge is most sensitive in would be the region
the scale cannot show.

## Decision
Logarithmic axis. Ticks at 1, 2, 5, 10, 20 by default; both limit labels are
drawn first and always win; intermediate ticks are culled where their labels
would collide.

## Why this is acceptable despite the risk
A log axis can mislead about magnitude — 20 does not look twice as far as 10.
Three things contain that:

1. **The number is the hero**, at 60px directly above the scale. The scale's job
   is showing *position relative to the limits*, not supporting arithmetic.
2. **Every tick is labelled.** There is no unlabelled interpolation to misread.
3. **The limits are always present.** The reader can always see the range they
   are reading within.

## Why the ticks cull
Discovered by visual inspection at 200% text scale, not by reasoning: labels
collided into `0.51` and `2040`. Culling is what any real axis does when space
runs out, and dropping a limit label would defeat the component's entire purpose,
so limits are reserved before intermediate ticks are placed.

## Revisit when
The laboratory establishes the actual validated range. If it turns out to span
less than one decade, linear becomes both honest and more readable, and this
should change.
