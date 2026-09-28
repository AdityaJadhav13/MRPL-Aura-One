import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/screens/role_selection_screen.dart';
import '../../features/auth/presentation/screens/sign_in_screen.dart';
import '../../features/auth/presentation/screens/site_selection_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../components/states.dart';
import '../design/theme.dart';
import '../../features/dev/component_catalog_screen.dart';
import '../../features/dev/developer_tools_screen.dart';
import '../env/app_version.dart';
import '../../features/admin/data/admin_demo_catalog.dart';
import '../../features/admin/presentation/admin_governance_screens.dart';
import '../../features/admin/presentation/admin_screens.dart';
import '../../features/auth/data/site_repository.dart';
import '../../features/capture/presentation/capture_host_screen.dart';
import '../../features/research/presentation/physical_capture_screen.dart';
import '../../features/scan/worker_capture_screen.dart';
import '../../features/research/presentation/research_captures_screen.dart';
import '../../features/safety/presentation/safety_hub_screen.dart';
import '../../features/safety/presentation/safety_screens.dart';
import '../../features/gallery/gallery_screen.dart';
import '../../features/gallery/worker_preview_screen.dart';
import '../../features/history/domain/measurement_record.dart';
import '../../features/history/history_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/operations/domain/assignment.dart';
import '../../features/presentation/presentation/presentation_controls_screen.dart';
import '../../features/profile/settings_screen.dart';
import '../../features/result/measurement_detail_screen.dart';
import '../../features/result/result_screen.dart';
import '../../features/scan/guided_scan_screen.dart';
import '../../features/scan/processing_screen.dart';
import '../../features/scan/scan_screen.dart';
import '../../features/workflow/domain/badge_specimen.dart';
import '../../features/workflow/presentation/active_monitoring_screen.dart';
import '../../features/workflow/presentation/badge_assignment_screen.dart';
import '../../features/workflow/presentation/badge_screens.dart';
import '../../features/workflow/presentation/context_detail_screens.dart';
import '../../features/workflow/presentation/badge_verification_screen.dart';
import '../../features/workflow/presentation/end_monitoring_screen.dart';
import '../../features/workflow/presentation/prework_check_screen.dart';
import '../../features/workflow/presentation/work_context_screen.dart';
import '../env/environment.dart';
import '../../features/management/presentation/management_screens.dart';
import '../../features/supervisor/presentation/supervisor_screens.dart';
import '../components/product_navigation.dart';
import '../../features/doseband/presentation/doseband_check_screen.dart';
import '../../features/doseband/presentation/pre_use_capture_screen.dart';
import '../../features/doseband/presentation/qr_scan_screen.dart';
import '../../features/history/record_route.dart';
import '../../features/hse/presentation/hse_workspace.dart';
import '../../features/reporting/presentation/hse_reports_screen.dart';
import '../../features/admin/presentation/admin_workspace.dart';
import '../../features/dev/label_sheet_screen.dart';
import 'router_gate.dart';
import 'workspace_shell.dart';
import 'worker_shell.dart';

/// The worker shell's five destinations — Home · History · Scan · Safety ·
/// Profile — per APP-PRODUCT-01 §6.
///
/// "Current shift" is deliberately not a tab: it is what Home *is* when a shift
/// is active. The worker journey screens (assignment → monitoring → scan →
/// result) are pushed over the shell as full-screen steps, outside the bottom
/// navigation, so a step's primary action is never competing with a tab bar.
///
/// Developer and research tools live under `/dev`, outside every workspace,
/// and exist only where simulation is available (APP-PRODUCT-01 §91).
///
/// Every workspace sits behind [RouterGate]: signed out → sign-in; signed in
/// → only the active role's workspace. The gate is navigation, not security —
/// the operations services refuse unauthorised data below the UI regardless.
GoRouter buildRouter(
  EnvironmentConfig config, {
  String initialLocation = '/splash',
  RouterGate? gate,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: gate,
    redirect: gate == null
        ? null
        : (context, state) => gate.redirect(state.uri.toString()),
    routes: [
      // Launch and sign-in. The role is never chosen here: it comes from the
      // account (PRODUCT BUILD v1 §54).
      GoRoute(
        path: '/splash',
        builder: (_, state) =>
            SplashScreen(from: state.uri.queryParameters['from']),
      ),
      GoRoute(path: '/sign-in', builder: (_, _) => const SignInScreen()),
      // First-time setup (Worker directive §15). Open before sign-in; the
      // choices are requests that Sign In checks, never grants.
      GoRoute(
        path: '/select-site',
        builder: (_, _) => const SiteSelectionScreen(),
      ),
      GoRoute(
        path: '/select-role',
        builder: (_, _) => const RoleSelectionScreen(),
      ),

      // Worker journey — pushed over the shell.
      GoRoute(
        path: '/work-context',
        builder: (_, _) => const WorkContextScreen(),
      ),
      GoRoute(
        path: '/assign',
        builder: (_, _) => const BadgeAssignmentScreen(),
      ),
      GoRoute(
        path: '/verify',
        builder: (_, state) => _needs<BadgeSpecimen>(
          state,
          what: 'a badge to verify',
          returnLabel: 'Assign a badge',
          returnRoute: '/assign',
          build: (specimen) => BadgeVerificationScreen(specimen: specimen),
        ),
      ),
      GoRoute(path: '/prework', builder: (_, _) => const PreWorkCheckScreen()),
      GoRoute(
        path: '/active',
        builder: (_, _) => const ActiveMonitoringScreen(),
      ),
      GoRoute(path: '/end', builder: (_, _) => const EndMonitoringScreen()),
      // Real camera for a physical badge, labelled simulation for a
      // presentation specimen — decided by the badge, not a mode flag.
      GoRoute(
        path: '/read',
        builder: (_, _) => const InstrumentTheme(
          child: ReadBadgeScreen(simulated: GuidedScanScreen()),
        ),
      ),
      GoRoute(
        path: '/processing',
        builder: (_, _) => const InstrumentTheme(child: ProcessingScreen()),
      ),
      GoRoute(
        path: '/result',
        builder: (_, state) => _needs<MeasurementRecord>(
          state,
          what: 'the result of a badge reading',
          returnLabel: 'Go to history',
          returnRoute: '/history',
          build: (record) => ResultScreen(record: record),
        ),
      ),
      GoRoute(
        path: '/measurement',
        builder: (_, state) => _needs<MeasurementRecord>(
          state,
          what: 'one measurement in detail',
          returnLabel: 'Go to history',
          returnRoute: '/history',
          build: (record) =>
              InstrumentTheme(child: MeasurementDetailScreen(record: record)),
        ),
      ),

      // DoseBand scan → check → assign (PRODUCT BUILD v1 §7–§12).
      GoRoute(
        path: '/doseband/scan',
        builder: (_, state) => QrScanScreen(
          purpose: QrScanPurpose.parse(state.uri.queryParameters['purpose']),
        ),
      ),
      GoRoute(
        path: '/doseband/check/:id',
        builder: (_, state) => DoseBandCheckScreen(
          dosebandId: state.pathParameters['id']!,
          identifiedBy:
              BandIdentification.values
                  .where((v) => v.name == state.uri.queryParameters['via'])
                  .firstOrNull ??
              BandIdentification.qrCode,
          qrPayload: state.uri.queryParameters['qr'],
        ),
        routes: [
          GoRoute(
            path: 'photo',
            builder: (_, state) => InstrumentTheme(
              child: PreUseCaptureScreen(
                dosebandId: state.pathParameters['id']!,
              ),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/history/record/:id',
        builder: (_, state) => WorkerRecordRoute(
          recordId: state.pathParameters['id']!,
          carried: state.extra,
        ),
      ),

      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => WorkerShell(shell: shell),
        // Order is the bar's order: Home · History · Scan · Safety · Profile.
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/history',
                builder: (_, _) => const HistoryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/scan', builder: (_, _) => const ScanScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/safety',
                builder: (_, _) => const SafetyHubScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (_, _) => const ProfileScreen(),
                routes: [
                  GoRoute(
                    path: 'settings',
                    builder: (_, _) => SettingsScreen(config: config),
                    routes: [
                      // SIH demonstration fallback. Registered only where
                      // presentation accounts exist; never in production.
                      if (config.simulationAvailable)
                        GoRoute(
                          path: 'presentation',
                          builder: (_, _) => const PresentationControlsScreen(),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),

      // ---------------------------------------------- developer / research
      //
      // Outside every workspace, and compiled out of production by the same
      // flag that removes simulation. Moved here from under `/profile` in
      // APP-PRODUCT-01 §91 so research tooling is not a child of the worker's
      // own profile. Old path → new path is recorded in
      // docs/product/screen-rationalization-inventory.md.
      if (config.simulationAvailable)
        GoRoute(
          path: '/dev',
          builder: (_, _) => const DeveloperToolsScreen(),
          routes: [
            GoRoute(
              path: 'components',
              builder: (_, _) => const ComponentCatalogScreen(),
            ),
            // The instrument components: readouts, scale, markers, results.
            GoRoute(
              path: 'labels',
              builder: (_, _) => const LabelSheetScreen(),
            ),
            GoRoute(path: 'gallery', builder: (_, _) => const GalleryScreen()),
            // Seeds the workflow store directly — the last thing a worker
            // should be able to do.
            GoRoute(
              path: 'worker-previews',
              builder: (_, _) => const WorkerPreviewScreen(),
            ),
            // Dossier V0 capture: a real camera producing research images,
            // never a worker-facing record.
            GoRoute(
              path: 'capture',
              builder: (_, _) => const InstrumentTheme(
                child: CaptureHostScreen(appVersion: appVersion),
              ),
            ),
            // Physical Capture Test — the M0C bench workflow. Research records
            // only. APP-INTEGRATION-01 §40.
            GoRoute(
              path: 'physical-capture',
              builder: (_, _) =>
                  const InstrumentTheme(child: PhysicalCaptureSetupScreen()),
              routes: <RouteBase>[
                GoRoute(
                  path: 'camera',
                  builder: (_, _) => const InstrumentTheme(
                    child: PhysicalCaptureSessionScreen(),
                  ),
                ),
              ],
            ),
            GoRoute(
              path: 'research-captures',
              builder: (_, _) =>
                  const InstrumentTheme(child: ResearchCapturesScreen()),
            ),
          ],
        ),

      // ------------------------------------------- worker context detail
      GoRoute(path: '/shift', builder: (_, _) => const ShiftScreen()),
      GoRoute(
        path: '/worker-identity',
        builder: (_, _) => const WorkerIdentityScreen(),
      ),
      GoRoute(path: '/work-area', builder: (_, _) => const WorkAreaScreen()),
      GoRoute(path: '/ptw', builder: (_, _) => const PtwReferenceScreen()),
      GoRoute(path: '/jsa', builder: (_, _) => const JsaReferenceScreen()),
      GoRoute(
        path: '/toolbox',
        builder: (_, _) => const ToolboxAcknowledgementScreen(),
      ),
      GoRoute(
        path: '/scan-badge',
        builder: (_, _) => const ScanBadgeQrScreen(),
      ),
      GoRoute(
        path: '/traceability',
        builder: (_, _) => const BadgeTraceabilityScreen(),
      ),

      // ------------------------------------------------ safety (worker tab)
      GoRoute(
        path: '/safety/h2s',
        builder: (_, _) => const H2sInformationScreen(),
      ),
      GoRoute(
        path: '/safety/emergency',
        builder: (_, _) => const EmergencyScreen(),
      ),
      GoRoute(
        path: '/safety/hazard',
        builder: (_, _) => const HazardReportScreen(),
      ),
      GoRoute(
        path: '/safety/occupational-health',
        builder: (_, _) => const OccupationalHealthScreen(),
      ),
      GoRoute(
        path: '/safety/ptw',
        builder: (_, _) => const PtwGuidanceScreen(),
      ),
      GoRoute(
        path: '/safety/jsa',
        builder: (_, _) => const JsaGuidanceScreen(),
      ),
      GoRoute(path: '/safety/ppe', builder: (_, _) => const PpeScreen()),
      GoRoute(
        path: '/safety/toolbox',
        builder: (_, _) => const ToolboxResourcesScreen(),
      ),
      GoRoute(path: '/safety/sds', builder: (_, _) => const SdsScreen()),
      GoRoute(
        path: '/safety/offline',
        builder: (_, _) => const OfflineDocumentsScreen(),
      ),

      // --------------------------------------------------------- HSE detail
      // ------------------------------------------------ supervisor shell
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => WorkspaceShell(
          destinations: WorkspaceDestinations.supervisor,
          shell: shell,
        ),
        branches: [
          _branch('/supervisor', (_) => const SupervisorOverviewScreen()),
          _branch(
            '/supervisor/team',
            (state) => SupervisorTeamScreen(
              initialStatus: teamStatusParam(
                state.uri.queryParameters['status'],
              ),
            ),
          ),
          _branch(
            '/supervisor/monitoring',
            (_) => const SupervisorMonitoringScreen(),
          ),
          _branch(
            '/supervisor/exceptions',
            (_) => const SupervisorExceptionsScreen(),
          ),
          _branch(
            '/supervisor/more',
            (_) => SupervisorMoreScreen(config: config),
          ),
        ],
      ),
      GoRoute(
        path: '/supervisor/worker/:workerId',
        builder: (_, state) =>
            SupervisorWorkerScreen(workerId: state.pathParameters['workerId']!),
      ),

      // ------------------------------------------------ management shell
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => WorkspaceShell(
          destinations: WorkspaceDestinations.management,
          shell: shell,
        ),
        branches: [
          _branch('/management', (_) => const ManagementOverviewScreen()),
          _branch(
            '/management/monitoring',
            (_) => const ManagementMonitoringScreen(),
          ),
          _branch('/management/trends', (_) => const ManagementTrendsScreen()),
          _branch(
            '/management/reports',
            (_) => const ManagementReportsScreen(),
          ),
          _branch(
            '/management/more',
            (_) => ManagementMoreScreen(config: config),
          ),
        ],
      ),

      // ------------------------------------------------------- HSE shell
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => WorkspaceShell(
          destinations: WorkspaceDestinations.hse,
          shell: shell,
        ),
        branches: [
          _branch('/hse', (_) => const HseOverviewScreen()),
          _branch('/hse/exposures', (_) => const HseExposureRegisterScreen()),
          _branch('/hse/reviews', (_) => const HseReviewQueueScreen()),
          _branch('/hse/reports', (_) => const HseReportsScreen()),
          _branch('/hse/more', (_) => HseMoreScreen(config: config)),
        ],
      ),
      GoRoute(
        path: '/hse/record/:id',
        builder: (_, state) =>
            HseRecordScreen(measurementId: state.pathParameters['id']!),
      ),

      // ----------------------------------------------------------- admin
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => WorkspaceShell(
          destinations: WorkspaceDestinations.admin,
          shell: shell,
        ),
        branches: [
          _branch('/admin', (_) => const AdminOverviewScreen()),
          _branch('/admin/people', (_) => const AdminPeopleScreen()),
          _branch('/admin/doseband', (_) => const AdminDoseBandsScreen()),
          _branch('/admin/system', (_) => const AdminSystemScreen()),
          _branch('/admin/more', (_) => AdminMoreScreen(config: config)),
        ],
      ),
      GoRoute(
        path: '/admin/people/:personId',
        builder: (_, state) =>
            AdminPersonScreen(personId: state.pathParameters['personId']!),
      ),
      GoRoute(
        path: '/admin/doseband/lot/:lotId',
        builder: (_, state) =>
            AdminLotScreen(lotId: state.pathParameters['lotId']!),
      ),
      GoRoute(
        path: '/admin/doseband/band/:id',
        builder: (_, state) =>
            AdminBandScreen(dosebandId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/admin/audit',
        builder: (_, _) => const AdminAuditScreen(),
      ),
      GoRoute(
        path: '/admin/integrations',
        builder: (_, _) => const IntegrationStatusScreen(),
      ),
      GoRoute(
        path: '/admin/integrations/:integrationId',
        builder: (_, state) {
          final id = state.pathParameters['integrationId']!;
          final integration = AdminDemoCatalog.integrationById(id);
          if (integration == null) {
            return AdminRecordNotFoundScreen(
              recordKind: 'integration',
              identifier: id,
            );
          }
          return IntegrationDetailScreen(integration: integration);
        },
      ),
      GoRoute(
        path: '/admin/sites',
        builder: (_, _) => AdminSitesScreen(
          sites: [
            for (final site in const SeededSiteRepository().sites())
              (id: site.id, name: site.name, locality: site.locality),
          ],
        ),
      ),
      GoRoute(
        path: '/admin/departments',
        builder: (_, _) => const AdminDepartmentsScreen(),
      ),
      GoRoute(
        path: '/admin/work-areas',
        builder: (_, _) => AdminWorkAreasScreen(
          siteIds: [
            for (final site in const SeededSiteRepository().sites()) site.id,
          ],
        ),
      ),
      GoRoute(
        path: '/admin/retention',
        builder: (_, _) => const AdminRetentionScreen(),
      ),
      GoRoute(path: '/admin/sync', builder: (_, _) => const AdminSyncScreen()),
      GoRoute(
        path: '/admin/organisation',
        builder: (_, _) => const OrganisationConfigurationScreen(),
      ),
      GoRoute(
        path: '/admin/calibration',
        builder: (_, _) => const CalibrationAdministrationScreen(),
      ),
      GoRoute(
        path: '/admin/badges',
        builder: (_, _) => const BadgeConfigurationScreen(),
      ),
      GoRoute(
        path: '/admin/versions',
        builder: (_, _) => AdminVersionsScreen(config: config),
      ),
      GoRoute(
        path: '/admin/system/info',
        builder: (_, _) => SystemInformationScreen(config: config),
      ),
      // Compiled out of production, like the gallery and the worker previews.
      if (config.simulationAvailable)
        GoRoute(
          path: '/admin/demo-data',
          builder: (_, _) => const PresentationDataScreen(),
        ),
    ],
  );
}

/// One shell branch with a single root route.
StatefulShellBranch _branch(
  String path,
  Widget Function(GoRouterState state) build,
) => StatefulShellBranch(
  routes: [GoRoute(path: path, builder: (_, state) => build(state))],
);

/// Builds a detail screen from the record carried in `GoRouterState.extra`, or
/// explains its absence instead of throwing.
///
/// `extra` travels with the navigation call, not in the URL, so it is null on
/// a deep link, a typed address and a cold-start restore. Twelve routes take
/// their subject this way; funnelling them all through here means a new one
/// cannot reintroduce the crash by writing `state.extra!`.
Widget _needs<T>(
  GoRouterState state, {
  required String what,
  required String returnLabel,
  required String returnRoute,
  required Widget Function(T value) build,
}) {
  final extra = state.extra;
  if (extra is T) return build(extra);
  return Builder(
    builder: (BuildContext context) => MissingRouteContextScreen(
      what: what,
      returnLabel: returnLabel,
      onReturn: () => context.go(returnRoute),
    ),
  );
}
