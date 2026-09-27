/// The claims DoseBand may never make, in one place.
///
/// ## Why this is centralized
///
/// Eight test files grew their own forbidden-phrase lists as each module was
/// built. Each list was right for its module, and that is exactly the problem:
/// a phrase added to the HSE list did not protect the Reporting screens, so a
/// claim could appear on whichever surface happened to have the shorter list.
///
/// This is the full vocabulary, swept over every route by
/// `test/surface/claims_test.dart`. The module tests keep their own lists —
/// they carry module-specific reasoning worth reading at the point of use —
/// but nothing depends on those lists being complete any more.
///
/// Entries are lowercase substrings, matched against lowercased visible text.
library;

/// DoseBand does not authorise work and cannot tell anyone they are safe.
///
/// It measures cumulative external exposure after the fact. It has no alarm,
/// it is read afterwards, and it knows nothing about the atmosphere a worker
/// is standing in right now.
const safetyClaims = <String>[
  'safe to work',
  'h₂s safe',
  'h2s safe',
  'safe exposure',
  'safe level',
  'you are safe',
  'no risk',
  'within safe',
  'normal exposure',
  'ptw approved',
  'jsa approved',
  'permit approved',
  'medically cleared',
  'fit for duty',
  'cleared for work',
  'safe to enter',
];

/// No authority has assessed, approved or certified this software.
const regulatoryClaims = <String>[
  'oisd compliant',
  'oisd approved',
  'oisd certified',
  'dgms compliant',
  'dgms approved',
  'dgms certified',
  'mrpl approved',
  'mrpl certified',
  'mrpl verified',
  'regulatory compliant',
  'fully compliant',
  'statutory approved',
];

/// No security property has been established, and UI polish is not evidence
/// of one.
const securityClaims = <String>[
  'enterprise secure',
  'fully encrypted',
  'end-to-end encrypted',
  'encrypted at rest',
  'zero trust',
  'iso 27001',
  'soc 2',
  'gdpr compliant',
  'military grade',
  'bank grade',
  'secure by design',
];

/// No calibration exists, so no performance figure can be stated.
const calibrationClaims = <String>[
  'calibration validated',
  'validated calibration',
  'calibrated and verified',
  'accuracy validated',
  'clinically validated',
  'scientifically validated',
  'laboratory validated',
];

/// Nothing is connected, generated, exported or filed.
const maturityClaims = <String>[
  'production ready',
  'audit ready',
  'fully integrated',
  'successfully connected',
  'successfully exported',
  'successfully submitted',
  'report generated',
  'export complete',
  'sync complete',
  'all systems operational',
];

/// A refusal is not a zero, and an absent value is not a measured one.
const zeroCollapseClaims = <String>[
  '0.0 ppm·h',
  '0 ppm·h',
  '0.00 ppm·h',
  'zero exposure',
  'no exposure detected',
  'exposure: 0',
];

/// Everything above, for a single sweep.
const allProhibitedClaims = <String>[
  ...safetyClaims,
  ...regulatoryClaims,
  ...securityClaims,
  ...calibrationClaims,
  ...maturityClaims,
  ...zeroCollapseClaims,
];

/// Every route registered without a path parameter.
///
/// Parameterised and `extra`-carrying routes are covered by
/// `route_integrity_test.dart`; this list is what a sweep can simply open.
const allRoutes = <String>[
  '/splash',
  '/sign-in',
  // First-time setup (Worker directive §15).
  '/select-site',
  '/select-role',
  '/home',
  '/scan',
  '/history',
  '/profile',
  '/profile/settings',
  // Development-only (APP-PRODUCT-01): the tools hub and component catalog.
  '/dev',
  '/dev/components',
  '/dev/labels',
  '/doseband/scan',
  '/doseband/check/DB-2609-0011',
  '/history/record/CAP-TEST-1',
  '/shift',
  '/worker-identity',
  '/work-context',
  '/work-area',
  '/ptw',
  '/jsa',
  '/toolbox',
  '/assign',
  '/scan-badge',
  '/verify',
  '/prework',
  '/active',
  '/end',
  '/read',
  '/processing',
  '/result',
  '/measurement',
  '/traceability',
  '/safety',
  '/safety/h2s',
  '/safety/emergency',
  '/safety/hazard',
  '/safety/occupational-health',
  '/safety/ptw',
  '/safety/jsa',
  '/safety/ppe',
  '/safety/toolbox',
  '/safety/sds',
  '/safety/offline',
  '/supervisor',
  '/supervisor/team',
  '/supervisor/monitoring',
  '/supervisor/exceptions',
  '/supervisor/more',
  '/management',
  '/management/monitoring',
  '/management/trends',
  '/management/reports',
  '/management/more',
  '/hse',
  '/hse/exposures',
  '/hse/reviews',
  '/hse/reports',
  '/hse/more',
  '/admin',
  '/admin/people',
  '/admin/doseband',
  '/admin/system',
  '/admin/more',
  '/admin/audit',
  '/admin/integrations',
  '/admin/sites',
  '/admin/departments',
  '/admin/work-areas',
  '/admin/organisation',
  '/admin/retention',
  '/admin/versions',
  '/admin/sync',
  '/admin/calibration',
  '/admin/badges',
  '/admin/demo-data',
  '/admin/system/info',
];

/// Whether [text] actually *asserts* [claim], rather than denying it.
///
/// A naive substring search is wrong here, and wrong in the direction that
/// matters: DoseBand's screens are full of sentences like "No validated
/// calibration model exists" and "This does not mean the worker is safe".
/// Those contain the forbidden phrase precisely because they exist to refute
/// it, and flagging them would push an author toward deleting the denial —
/// the opposite of what these tests are for.
///
/// So a match is ignored when a negator governs it. The window is short and
/// the negator list is small on purpose: a long window would start excusing
/// genuine claims that happen to follow an unrelated "no" earlier in a
/// paragraph.
bool assertsClaim(String haystack, String claim) {
  const negators = [
    'no ',
    'not ',
    "n't ",
    'never ',
    'cannot ',
    'can not ',
    'without ',
    'nothing ',
    'none ',
    'refuses ',
    'does not ',
    'is not ',
    'are not ',
    'has not ',
    'have not ',
    'may not ',
    'must not ',
    'unable ',
    'absent ',
    'lacks ',
    'awaiting ',
  ];

  final text = haystack.toLowerCase();
  final needle = claim.toLowerCase();

  var from = 0;
  while (true) {
    final at = text.indexOf(needle, from);
    if (at < 0) return false;

    final windowStart = at < 40 ? 0 : at - 40;
    final before = text.substring(windowStart, at);
    final negated = negators.any(before.contains);

    if (!negated) return true;
    from = at + needle.length;
  }
}
