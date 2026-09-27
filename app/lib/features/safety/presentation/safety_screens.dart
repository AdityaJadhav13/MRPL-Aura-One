import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/components/corporate.dart';
import '../../../core/design/corporate_colors.dart';
import '../../../core/design/theme.dart';
import '../../../core/design/tokens.dart';
import '../../../core/util/async_value_x.dart';
import '../../../core/util/format.dart';
import '../../workflow/application/workflow_controller.dart';
import '../../workflow/domain/workflow_state.dart';
import '../../workflow/presentation/widgets/provenance.dart';
import '../data/safety_demo_catalog.dart';
import '../domain/safety_content.dart';
import 'widgets/safety_components.dart';
import 'widgets/safety_scaffold.dart';

// ===========================================================================
// H₂S information
// ===========================================================================

/// What hydrogen sulphide is, and what DoseBand does about it.
///
/// ## What this screen deliberately does not contain
///
/// No exposure limits, no alarm set points, no ppm figures, no
/// symptom-by-concentration table, and no advice about what to do at a given
/// reading. Those numbers are jurisdictional and organisational. Quoting them
/// from memory in an app a worker carries into a refinery would be a
/// fabrication with the worst possible consequences, and a worker who found
/// one wrong would rightly distrust everything else here.
///
/// Every section says who is speaking — general information, a statement
/// about this product, or a pointer at the organisation's own material.
class H2sInformationScreen extends StatelessWidget {
  const H2sInformationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SafetyScaffold(
      title: 'Hydrogen sulphide',
      subtitle: 'What it is and how exposure is monitored',
      children: [
        NotAnAlarmNotice(),
        SizedBox(height: Space.base),

        SafetySection(
          heading: 'What is H₂S?',
          source: SafetyContentSource.general,
          paragraphs: [
            'Hydrogen sulphide is a toxic gas that occurs naturally in crude '
                'oil and natural gas, and is produced by several refining '
                'processes. It is colourless and heavier than air, so it '
                'collects in low-lying and enclosed spaces — sumps, pits, '
                'vessels and trenches.',
            'Its smell is not a reliable warning. The sense of smell stops '
                'registering it well before it stops being dangerous, so '
                '"I can no longer smell it" must never be read as "it has '
                'gone".',
          ],
        ),

        SafetySection(
          heading: 'Why exposure monitoring matters',
          source: SafetyContentSource.general,
          paragraphs: [
            'Two different things can harm someone: a short encounter with a '
                'high concentration, and repeated smaller amounts accumulating '
                'across a working period.',
            'Gas detectors address the first. Exposure monitoring addresses '
                'the second, by recording how much a person was actually '
                'around over time rather than what the air held at one '
                'moment.',
          ],
        ),

        SafetySection(
          heading: 'Real-time detection versus cumulative monitoring',
          source: SafetyContentSource.general,
          paragraphs: [
            'A gas detector answers "is there dangerous gas here, right now?" '
                'and sounds an alarm. It protects you during the event, and it '
                'is the thing that saves lives.',
            'A dosimeter badge answers a different question: "how much did '
                'this person breathe in, in total, across the whole period?" '
                'It has no alarm and is read afterwards.',
            'The two are not substitutes for one another. DoseBand is the '
                'second kind, and it does not reduce the need for the first.',
          ],
        ),

        SafetySection(
          heading: 'How the passive badge works',
          source: SafetyContentSource.general,
          paragraphs: [
            'A passive badge has no pump and no electronics. Gas reaches a '
                'chemically treated window by diffusion, and the chemistry '
                'changes colour in proportion to how much passed through.',
            'The badge is then photographed, and the colour is measured '
                'against reference patches printed alongside it, so the '
                'reading does not depend on the lighting or the phone.',
          ],
        ),

        SafetySection(
          heading: 'What DoseBand measures',
          source: SafetyContentSource.product,
          paragraphs: [
            'The intended output is cumulative exposure — a concentration '
                'integrated over the time the badge was worn, expressed in '
                'ppm·h.',
            'It also records the period the badge covered, the work context '
                'it was attached to, and which badge produced the reading.',
          ],
        ),

        SafetySection(
          heading: 'What DoseBand does not measure',
          source: SafetyContentSource.product,
          bullets: [
            'It does not measure the concentration in the air now. There is '
                'no live reading, no sound and no alarm.',
            'It does not measure how much H₂S entered your body. Exposure is '
                'what was in the air around the badge; absorbed dose is a '
                'different quantity and DoseBand does not estimate it.',
            'It says nothing about your health. A reading is not a diagnosis '
                'and cannot be used as one.',
            'It does not decide whether work is safe, and it does not '
                'authorise anything.',
          ],
        ),

        SafetySection(
          heading: 'Handling your badge',
          source: SafetyContentSource.product,
          bullets: [
            'Wear it in the open on the upper body, not under a coat or '
                'clothing. A covered badge samples the air inside your '
                'clothing rather than the air you are breathing.',
            'Do not touch, wet, wipe or mark the sensor window. The reading '
                'is a colour measurement, so anything on the window becomes '
                'part of what is measured.',
            'Keep it on for the whole monitored period, including breaks '
                'taken in the same area.',
            'Return it for reading at the end. A badge that is never read '
                'produces no record at all.',
          ],
        ),

        SafetySection(
          heading: 'Limitations of a reading',
          source: SafetyContentSource.product,
          paragraphs: [
            'A reading describes one badge over one period. It does not '
                'describe the area generally, other people nearby, or any '
                'other time.',
            'Quantitative H₂S calibration is not yet available. DoseBand '
                'does not yet produce a ppm·h figure from a real badge; a '
                'real scan is recorded with no reading, and anything '
                'resembling a figure is simulated and labelled as such.',
          ],
        ),

        SafetySection(
          heading: 'When DoseBand cannot give you a result',
          source: SafetyContentSource.product,
          paragraphs: [
            'DoseBand refuses rather than guesses. If the photograph, the '
                'badge or the monitored period cannot be trusted, it reports '
                'no reading and explains why.',
            'A refusal is not an exposure of zero. It means the exposure over '
                'that period is unknown, and it is shown as "- - -" rather '
                'than as a number.',
          ],
          bullets: [
            'The image was too blurred, dark or glared to measure.',
            'The reference patches could not be read.',
            'The badge was expired, damaged or already used.',
            'No calibration exists for that batch.',
            'The device clock moved during the period, so its duration '
                'cannot be established.',
          ],
        ),

        _OrganisationMaterialCard(),
      ],
    );
  }
}

/// Points at the authoritative source for the numbers this app will not carry.
class _OrganisationMaterialCard extends StatelessWidget {
  const _OrganisationMaterialCard();

  @override
  Widget build(BuildContext context) {
    return const NotConfiguredCard(
      what: 'Exposure limits and alarm set points',
      explanation:
          'Occupational exposure limits, alarm set points and the actions '
          'required at each of them are set by regulation and by your '
          'organisation, and they differ between jurisdictions and sites. '
          'DoseBand does not publish them and will not reproduce them from '
          'memory.',
      instead:
          'Follow your site’s approved material, training and gas-detection '
          'procedures for any figure you need to act on.',
      icon: Icons.straighten_outlined,
    );
  }
}

// ===========================================================================
// Emergency
// ===========================================================================

/// Site emergency information.
///
/// ## Nothing on this screen is invented
///
/// Every value is a configuration slot and every slot is empty. There are no
/// phone numbers, assembly points, evacuation routes or maps, and there is no
/// button that appears to call anyone.
///
/// A wrong number here would be dialled in the one situation where a second
/// matters, by someone who had no reason to doubt it. The general guidance
/// below is the most this product can honestly say.
class EmergencyScreen extends StatelessWidget {
  const EmergencyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;

    return SafetyScaffold(
      title: 'Emergency',
      subtitle: 'Site information',
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(Space.base),
          decoration: BoxDecoration(
            color: corporate.accentMuted,
            borderRadius: BorderRadius.circular(CorporateRadii.md),
            border: Border.all(color: corporate.accent.withValues(alpha: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.campaign_outlined,
                    size: 21,
                    color: corporate.accent,
                  ),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        'Follow site alarms and approved procedures',
                        style: t.bodyStrong.copyWith(
                          color: corporate.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.sm),
              Text(
                'In an emergency, act on the site alarm and your training, '
                'and use your site’s approved emergency communication '
                'channels. DoseBand is not an emergency gas alarm and will '
                'not alert you to anything.',
                style: t.body.copyWith(color: corporate.textPrimary),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.lg),

        const NotConfiguredCard(
          what: 'Site emergency information',
          explanation:
              'No emergency information has been configured for this '
              'installation. DoseBand will not display a contact number, an '
              'assembly point, a route or a procedure it has not been given.',
          instead:
              'Use the emergency contacts and assembly points posted at your '
              'site and covered in your induction.',
          icon: Icons.location_off_outlined,
        ),

        const SectionHeader(title: 'Awaiting configuration'),
        InfoCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: const [
              _EmptySlot(
                icon: Icons.call_outlined,
                label: 'Emergency contacts',
              ),
              _EmptySlot(icon: Icons.place_outlined, label: 'Assembly point'),
              _EmptySlot(
                icon: Icons.rule_folder_outlined,
                label: 'Emergency procedure',
              ),
              _EmptySlot(icon: Icons.map_outlined, label: 'Site map'),
              _EmptySlot(
                icon: Icons.local_hospital_outlined,
                label: 'Medical / occupational health contact',
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.base),
        InfoCard(
          child: Text(
            'These slots stay empty until your organisation supplies the '
            'information. DoseBand does not generate emergency content, and '
            'no control on this screen places a call.',
            style: t.caption.copyWith(color: corporate.textSecondary),
          ),
        ),
      ],
    );
  }
}

class _EmptySlot extends StatelessWidget {
  const _EmptySlot({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;

    return Semantics(
      label: '$label. Unavailable, not configured.',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.md,
          vertical: Space.md,
        ),
        child: Row(
          children: [
            Icon(icon, size: 19, color: corporate.textSecondary),
            const SizedBox(width: Space.base),
            Expanded(
              child: Text(
                label,
                style: t.body.copyWith(color: corporate.textSecondary),
              ),
            ),
            Text(
              'Unavailable',
              style: t.caption.copyWith(color: corporate.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// Near miss and hazard
// ===========================================================================

/// Hand off to the organisation's reporting process.
///
/// DoseBand does not receive hazard reports and will not become a competing
/// incident-management system. The submit control is disabled: a button that
/// appears to file a hazard report and silently does nothing is the most
/// dangerous control this product could ship, because the worker would
/// reasonably stop thinking about it.
class HazardReportScreen extends StatelessWidget {
  const HazardReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;

    return SafetyScaffold(
      title: 'Near miss or hazard',
      subtitle: 'Handoff to the organisation process',
      children: [
        Text(
          'Reporting is your organisation’s process. DoseBand’s role is to '
          'hand off to it, carrying the work context of your current '
          'monitored period so you do not have to re-enter it.',
          style: t.body.copyWith(color: corporate.textSecondary),
        ),
        const SizedBox(height: Space.lg),

        const SectionHeader(title: 'What are you reporting?'),
        InfoCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: const [
              _HazardKind(
                icon: Icons.warning_amber_outlined,
                label: 'Near miss',
                detail: 'Something that could have caused harm but did not',
              ),
              _HazardKind(
                icon: Icons.report_problem_outlined,
                label: 'Unsafe condition',
                detail: 'A hazard in the plant or the work area',
              ),
              _HazardKind(
                icon: Icons.person_off_outlined,
                label: 'Unsafe act',
                detail: 'Something being done in an unsafe way',
              ),
              _HazardKind(
                icon: Icons.more_horiz,
                label: 'Other hazard',
                detail: 'Anything else worth recording',
              ),
            ],
          ),
        ),

        const SectionHeader(title: 'Handoff'),
        const NotConfiguredCard(
          what: 'Hazard and near-miss reporting',
          explanation:
              'No reporting integration is connected, so DoseBand cannot '
              'submit anything on your behalf and cannot tell you a report '
              'was received.',
          instead:
              'Report through your normal site process. Nothing you select '
              'here has been sent or recorded anywhere.',
          icon: Icons.outbox_outlined,
        ),
        const SizedBox(height: Space.base),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: null,
            icon: const Icon(Icons.open_in_new),
            label: const Text('Continue to organisation reporting'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(kMinTouchTarget),
            ),
          ),
        ),
        const SizedBox(height: Space.sm),
        Text(
          'Unavailable until the reporting integration is connected.',
          textAlign: TextAlign.center,
          style: t.caption.copyWith(color: corporate.textSecondary),
        ),
      ],
    );
  }
}

class _HazardKind extends StatelessWidget {
  const _HazardKind({
    required this.icon,
    required this.label,
    required this.detail,
  });

  final IconData icon;
  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.md,
        vertical: Space.md,
      ),
      child: Row(
        children: [
          Icon(icon, size: 21, color: corporate.textSecondary),
          const SizedBox(width: Space.base),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: t.body.copyWith(color: corporate.textPrimary),
                ),
                const SizedBox(height: 1),
                Text(
                  detail,
                  style: t.caption.copyWith(color: corporate.textSecondary),
                ),
              ],
            ),
          ),
          const OriginChip(DataOrigin.notConnected, compact: true),
        ],
      ),
    );
  }
}

// ===========================================================================
// Occupational health
// ===========================================================================

/// The worker's view of the occupational-health handoff.
///
/// DoseBand holds occupational *hygiene* information — who wore a badge,
/// where, for how long, and what the reading was. It holds no medical
/// information, makes no clinical assessment, produces no health score and
/// infers nothing about fitness for work.
class OccupationalHealthScreen extends ConsumerWidget {
  const OccupationalHealthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session =
        ref.watch(shiftSessionProvider).dataOrNull ?? ShiftSession.none;
    final workContext = session.context;
    final now = DateTime.now();

    return SafetyScaffold(
      title: 'Occupational health',
      subtitle: 'Exposure record handoff',
      children: [
        const SafetySection(
          heading: 'What DoseBand can and cannot do here',
          source: SafetyContentSource.product,
          paragraphs: [
            'DoseBand holds exposure records: who wore a badge, where, for '
                'how long, and what the reading was. That is occupational '
                'hygiene information.',
            'It holds no medical information, makes no clinical assessment, '
                'and cannot tell you whether an exposure affected your health. '
                'Those are questions for an occupational health professional.',
          ],
          bullets: [
            'No diagnosis is made or stored.',
            'No treatment is suggested.',
            'No health score is calculated.',
            'No judgement about fitness for work is made.',
          ],
        ),

        const SectionHeader(title: 'Your current monitoring record'),
        if (workContext == null)
          const InfoCard(
            child: Text(
              'No monitored period has been recorded. There is nothing to '
              'hand off.',
            ),
          )
        else
          InfoCard(
            child: Column(
              children: [
                RecordRow(
                  label: 'Worker',
                  value: workContext.worker.displayName,
                ),
                RecordRow(
                  label: 'Worker ID',
                  value: workContext.worker.workerId,
                  mono: true,
                ),
                RecordRow(label: 'Site', value: workContext.site.name),
                RecordRow(label: 'Work area', value: workContext.workArea.name),
                RecordRow(
                  label: 'Started',
                  value: session.startedAt == null
                      ? 'Not started'
                      : Fmt.stamp(session.startedAt!),
                  mono: session.startedAt != null,
                ),
                // Unknown stays unknown, here as everywhere.
                RecordRow(
                  label: 'Covered',
                  value: Fmt.duration(session.coverageAt(now)),
                  mono: true,
                ),
                RecordRow(
                  label: 'Measurement',
                  value: session.result == null
                      ? 'No reading yet'
                      : session.result!.status.name,
                ),
              ],
            ),
          ),

        const SectionHeader(title: 'HSE review'),
        const NotConfiguredCard(
          what: 'Review status',
          explanation:
              'No record store exists yet, so DoseBand cannot show whether '
              'this period has been reviewed.',
          icon: Icons.rule_outlined,
        ),

        const SectionHeader(title: 'Referral'),
        const NotConfiguredCard(
          what: 'Occupational health service',
          explanation:
              'No occupational health integration is connected. Nothing has '
              'been referred, and no record has been sent to anyone.',
          instead:
              'Contact occupational health through your organisation’s normal '
              'route if you have concerns about an exposure.',
          icon: Icons.medical_information_outlined,
        ),
      ],
    );
  }
}

// ===========================================================================
// PTW and JSA guidance
// ===========================================================================

/// How DoseBand relates to the permit process, with the current reference.
class PtwGuidanceScreen extends ConsumerWidget {
  const PtwGuidanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workContext = ref.watch(shiftSessionProvider).dataOrNull?.context;

    return SafetyScaffold(
      title: 'Permit to Work',
      subtitle: 'How DoseBand relates to your permit',
      children: [
        const SafetySection(
          heading: 'The permit is your organisation’s, not DoseBand’s',
          source: SafetyContentSource.product,
          paragraphs: [
            'When you record a work context, DoseBand asks for a PTW '
                'reference. That number is written next to your exposure '
                'record so the reading can be understood later: what work was '
                'happening, under what authority.',
            'DoseBand cannot tell whether the number you typed belongs to a '
                'permit that exists, is open, or covers your job. It is marked '
                '"Manual" for exactly that reason.',
          ],
          bullets: [
            'DoseBand does not issue a permit.',
            'DoseBand does not approve, extend or close a permit.',
            'DoseBand does not check a permit against any system.',
            'Holding a reference here is not permission to start work.',
          ],
        ),
        const SafetySection(
          heading: '"Ready for dosimetry" is not an authorisation',
          source: SafetyContentSource.product,
          paragraphs: [
            'It means DoseBand has the minimum information it needs to begin '
                'recording exposure. It is a statement about this app and '
                'about nothing else — not the atmosphere, not the permit, not '
                'the job.',
          ],
        ),
        const SectionHeader(title: 'Your current reference'),
        if (workContext == null)
          const InfoCard(child: Text('No PTW reference has been recorded.'))
        else
          InfoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProvenanceRow.of(
                  label: 'PTW reference',
                  value: workContext.permit.reference,
                  secondary: workContext.permit.type?.name,
                ),
                RecordRow(label: 'Work area', value: workContext.workArea.name),
                RecordRow(label: 'Job', value: workContext.job.title),
              ],
            ),
          ),
        const SizedBox(height: Space.base),
        const NotConfiguredCard(
          what: 'Permit to Work integration',
          explanation:
              'No permit system is connected, so no reference shown in '
              'DoseBand has been confirmed by anyone.',
          icon: Icons.link_off,
        ),
      ],
    );
  }
}

/// How DoseBand relates to the JSA process, with the current reference.
class JsaGuidanceScreen extends ConsumerWidget {
  const JsaGuidanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workContext = ref.watch(shiftSessionProvider).dataOrNull?.context;

    return SafetyScaffold(
      title: 'Job Safety Analysis',
      subtitle: 'How DoseBand relates to your JSA',
      children: [
        const SafetySection(
          heading: 'The JSA is your organisation’s process',
          source: SafetyContentSource.product,
          paragraphs: [
            'A JSA reference recorded here attaches your exposure record to '
                'the analysis that covered the work. It is context for the '
                'reading, and nothing more.',
          ],
          bullets: [
            'DoseBand does not create a JSA.',
            'DoseBand does not approve, sign or close a JSA.',
            'DoseBand does not replace a JSA.',
            'DoseBand does not assess whether its controls are adequate.',
          ],
        ),
        const SafetySection(
          heading: 'Toolbox talk',
          source: SafetyContentSource.product,
          paragraphs: [
            'The acknowledgement you record notes that the toolbox-talk '
                'status was recorded for this work context. It is not '
                'evidence that the talk happened, who attended or what was '
                'covered — DoseBand is not in the room.',
            'It does not replace your organisation’s toolbox-talk process, '
                'and it does not record training.',
          ],
        ),
        const SectionHeader(title: 'Your current reference'),
        if (workContext == null)
          const InfoCard(child: Text('No JSA reference has been recorded.'))
        else
          InfoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProvenanceRow.of(
                  label: 'JSA reference',
                  value: workContext.jsa.reference,
                ),
                RecordRow(label: 'Job', value: workContext.job.title),
                RecordRow(label: 'Toolbox talk', value: 'Acknowledged'),
              ],
            ),
          ),
        const SizedBox(height: Space.base),
        const NotConfiguredCard(
          what: 'Job Safety Analysis integration',
          explanation:
              'No JSA system is connected, so no reference shown in DoseBand '
              'has been confirmed by anyone.',
          icon: Icons.link_off,
        ),
      ],
    );
  }
}

// ===========================================================================
// PPE
// ===========================================================================

/// PPE reference.
///
/// The categories are general. The **requirements** are deliberately absent:
/// what PPE a job needs depends on the job, the area and the organisation's
/// assessment of both.
///
/// DoseBand must never recommend PPE from its own measurement either. It
/// measures exposure after the fact; deriving a respirator recommendation from
/// a cumulative reading would be both scientifically wrong and the sort of
/// advice a worker might follow.
class PpeScreen extends StatelessWidget {
  const PpeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;

    return SafetyScaffold(
      title: 'PPE',
      subtitle: 'Personal protective equipment',
      children: [
        const NotConfiguredCard(
          what: 'Organisation-specific PPE requirements',
          explanation:
              'What PPE a job requires depends on the job, the work area and '
              'your organisation’s assessment of both. DoseBand has not been '
              'given that material and will not guess — a list of equipment '
              'invented by an app is exactly the kind of thing that gets '
              'trusted and should not be.',
          instead:
              'Follow the PPE requirements that apply to your site, your job, '
              'and your permit and JSA.',
          icon: Icons.engineering_outlined,
        ),
        const SizedBox(height: Space.lg),

        const SectionHeader(
          title: 'Categories',
          subtitle: 'Requirements are supplied by your organisation',
        ),
        InfoCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final category in SafetyDemoCatalog.ppeCategories())
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Space.md,
                    vertical: Space.md,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          category,
                          style: t.body.copyWith(color: corporate.textPrimary),
                        ),
                      ),
                      Text(
                        'Not configured',
                        style: t.caption.copyWith(
                          color: corporate.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: Space.base),
        InfoCard(
          child: Text(
            'DoseBand does not recommend PPE from its own readings. It '
            'measures exposure after a period has ended; it cannot tell you '
            'what to wear before one begins.',
            style: t.caption.copyWith(color: corporate.textSecondary),
          ),
        ),
      ],
    );
  }
}

// ===========================================================================
// Document libraries
// ===========================================================================

/// Toolbox and briefing material.
///
/// No document library is connected, so this screen says so and points at
/// the real source. It used to list demonstration entries; a resource
/// button must not open a document that does not exist (Worker directive
/// §42).
class ToolboxResourcesScreen extends StatelessWidget {
  const ToolboxResourcesScreen({super.key});

  @override
  Widget build(BuildContext context) => const SafetyScaffold(
    title: 'Toolbox resources',
    subtitle: 'Briefing material',
    children: [
      NotConfiguredCard(
        what: 'Toolbox and briefing library',
        explanation:
            'No document library is connected to DoseBand, so there is no '
            'briefing material to show. DoseBand does not write its own.',
        instead:
            'Use the toolbox-talk material your supervisor or site HSE '
            'provides.',
        icon: Icons.groups_outlined,
      ),
      SizedBox(height: Space.base),
      _ViewingIsNotTrainingNotice(),
    ],
  );
}

/// Opening a document is not attending a talk.
class _ViewingIsNotTrainingNotice extends StatelessWidget {
  const _ViewingIsNotTrainingNotice();

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;

    return InfoCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 17, color: corporate.textSecondary),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Text(
              'Acknowledging a toolbox talk in your work context is not a '
              'record of training or competence. Those are kept by your '
              'organisation, not by DoseBand.',
              style: t.caption.copyWith(color: corporate.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Safety data sheets.
///
/// DoseBand holds none: an out-of-date or invented sheet read as current is
/// a hazard in its own right. The screen points at the site's approved
/// register instead of listing placeholders.
class SdsScreen extends StatelessWidget {
  const SdsScreen({super.key});

  @override
  Widget build(BuildContext context) => const SafetyScaffold(
    title: 'Safety data sheets',
    subtitle: 'Substance documents',
    children: [
      NotConfiguredCard(
        what: 'Safety data sheet library',
        explanation:
            'DoseBand does not hold safety data sheets and no SDS repository '
            'is connected. An out-of-date or invented sheet read as current '
            'would be a hazard in its own right.',
        instead:
            'Use your site’s approved SDS register — including the sheet for '
            'hydrogen sulphide — through your supervisor or HSE department.',
        icon: Icons.description_outlined,
      ),
    ],
  );
}

/// Offline availability.
class OfflineDocumentsScreen extends StatelessWidget {
  const OfflineDocumentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;

    return SafetyScaffold(
      title: 'Offline documents',
      subtitle: 'Availability without a connection',
      children: [
        InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.cloud_off_outlined,
                    size: 19,
                    color: corporate.textSecondary,
                  ),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        'Nothing is downloaded',
                        style: t.bodyStrong.copyWith(
                          color: corporate.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.sm),
              Text(
                'No document source is configured, so there is nothing to '
                'download and no storage in use. DoseBand shows an empty '
                'list rather than inventing one.',
                style: t.body.copyWith(color: corporate.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.base),

        // Offline is a first-class state for this product, not an error: the
        // whole workflow is designed to run in a plant with no signal.
        InfoCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.wifi_off_outlined,
                size: 17,
                color: corporate.textSecondary,
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Text(
                  'Working offline is normal. Recording a work context, '
                  'assigning a badge, monitoring and scanning all work with '
                  'no connection — they are stored on this device.',
                  style: t.caption.copyWith(color: corporate.textSecondary),
                ),
              ),
            ],
          ),
        ),

        InfoCard(
          child: Text(
            'Storage used is not shown because nothing is stored. A figure '
            'here would be invented.',
            style: t.caption.copyWith(color: corporate.textSecondary),
          ),
        ),
      ],
    );
  }
}
