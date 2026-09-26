# ADR-0011 — Badge V1 requires a colour printer, and M0C cannot be completed without one

**Status:** Accepted
**Date:** 2026-09-26
**Phase:** M0C-REAL-WORLD-OPTICAL-VALIDATION (preflight)

## Context

M0C asks whether the optical reader can acquire and normalise a *physically
printed* Badge V1 target through a real smartphone, and refuse invalid
acquisitions. The preflight found two printers available on the workstation,
both reporting `*ColorDevice: False` — Canon LBP2900 and HP LaserJet P1007, both
monochrome laser.

Badge V1 defines ten reference ROIs. Four are neutral (`REF-BLACK`, `REF-DARK`,
`REF-MID`, `REF-LIGHT`) and **six are chromatic** (`REF-RED`, `REF-GREEN`,
`REF-BLUE`, `REF-CYAN`, `REF-MAGENTA`, `REF-YELLOW`).

M0A already established, algebraically, that a neutral-only reference set is
rank deficient for fitting a 3×3 colour correction matrix — there are not enough
independent chromatic directions to constrain it.

## Decision

**A colour printer is a hard prerequisite for the colour half of M0C**, and this
is recorded as a project constraint rather than a workstation inconvenience.

A monochrome print of Badge V1 reproduces M0A's rank deficiency in physical
form. It would permit the *geometry* half of M0C — detection, identification,
rectification, secondary-marker validation, occlusion, distance, rotation,
perspective, deformation, blur, false acceptance — because those depend on black
fiducials against the substrate. It cannot support §34 (correction method
comparison), §36 (multi-reference conditioning), §37 (withheld-reference
validation), §38 (reference design) or §53 (colour metrics).

Consequently M0C may be run in two parts if necessary, and a monochrome-only
result must be reported as **partial**, never as M0C complete.

## Alternatives considered

**Print the chromatic patches as distinct grey levels and proceed.** Rejected.
It would produce a correction matrix fitted on collinear data, and a fitted
residual that looks acceptable while predicting nothing — precisely the failure
mode §37 exists to catch. It would also mean the thing validated is not the
badge the product will use.

**Redesign Badge V1 to a neutral-only reference set.** Rejected. §7 forbids
redesigning the target before collecting physical evidence, and M0A's algebra
says neutral-only is the weaker design, not the stronger one. Changing the badge
to fit the available printer is fitting the instrument to the tool.

**Use a commercial printed colour chart in place of the badge references.**
Rejected for M0C as specified: the question is whether *this badge* can be
acquired and normalised. A separate characterised chart is valuable later as a
colour ground-truth reference (§9, §39) but does not substitute for printing the
target.

## Limitations

This ADR records a printing constraint. It says nothing about whether the
chromatic reference design is *sufficient* — that is the §38 experiment and
remains open. It is entirely possible that physical evidence later shows six
chromatic patches to be more than needed, and §77 requires recommending the
minimum design the evidence justifies.

## Revisit trigger

- A colour printer becomes available and the §38 reference-design experiment is
  run on physical prints.
- Physical evidence shows black-white normalisation alone is sufficient, which
  would reduce the chromatic requirement.
- Badge V1 is superseded by a geometry with a different reference set.
