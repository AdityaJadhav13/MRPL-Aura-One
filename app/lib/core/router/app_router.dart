import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/auth_models.dart';
import '../../features/auth/presentation/screens/role_selection_screen.dart';
import '../../features/auth/presentation/screens/role_workspace_placeholder.dart';
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
import '../../features/hse/presentation/hse_detail_screens.dart';
import '../../features/hse/presentation/hse_review_screens.dart';
import '../../features/hse/presentation/hse_screens.dart';
import '../../features/hse/presentation/hse_shell.dart';
import '../../features/reporting/data/reporting_demo_catalog.dart';
import '../../features/reporting/domain/report_models.dart';
import '../../features/reporting/presentation/audit_package_screen.dart';
import '../../features/reporting/presentation/occupational_register_screen.dart';
import '../../features/reporting/presentation/record_traceability_screen.dart';
import '../../features/reporting/presentation/report_builder_screen.dart';
import '../../features/reporting/presentation/reporting_screens.dart';
import '../../features/safety/presentation/safety_hub_screen.dart';
import '../../features/safety/presentation/safety_screens.dart';
import '../../core/demo/ui_demo_catalog.dart';
import '../../features/gallery/gallery_screen.dart';
import '../../features/gallery/worker_preview_screen.dart';
import '../../features/history/domain/measurement_record.dart';
import '../../features/history/history_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/profile/profile_screen.dart';
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
/// The officer and administrator shells are Phase 9; role redirect guards need
/// auth, which is Phase 7. Launch → login is a linear intro with no real auth
/// yet.
GoRouter buildRouter(
  EnvironmentConfig config, {
  String initialLocation = '/splash',
}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      // Authentication shell. MRPL-inspired corporate register; the
      // instrument surfaces stay neutral. See docs/design/auth-flow.md.
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/sign-in', builder: (_, _) => const SignInScreen()),
      GoRoute(
        path: '/select-site',
        builder: (_, _) => const SiteSelectionScreen(),
      ),
      GoRoute(
        path: '/select-role',
        builder: (_, _) => const RoleSelectionScreen(),
      ),
      GoRoute(
        path: '/workspace/:role',
        builder: (_, state) {
          final name = state.pathParameters['role'];
          final role = AppRole.values.firstWhere(
            (r) => r.name == name,
            orElse: () => AppRole.worker,
          );
          return RoleWorkspacePlaceholder(role: role);
        },
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
                builder: (_, _) => ProfileScreen(config: config),
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
      GoRoute(
        path: '/hse/record',
        builder: (_, state) => _needs<DemoExposureRecord>(
          state,
          what: 'one exposure record for review',
          returnLabel: 'Go to the exposure register',
          returnRoute: '/hse/exposures',
          build: (record) => MeasurementReviewScreen(record: record),
        ),
      ),
      GoRoute(
        path: '/hse/disposition',
        builder: (_, state) => _needs<DemoExposureRecord>(
          state,
          what: 'the record a disposition applies to',
          returnLabel: 'Go to the exposure register',
          returnRoute: '/hse/exposures',
          build: (record) => HseDispositionScreen(record: record),
        ),
      ),
      GoRoute(
        path: '/hse/handoff',
        builder: (_, state) => _needs<DemoExposureRecord>(
          state,
          what: 'the record being referred',
          returnLabel: 'Go to the exposure register',
          returnRoute: '/hse/exposures',
          build: (record) => OccupationalHealthHandoffScreen(record: record),
        ),
      ),
      GoRoute(
        path: '/hse/session',
        builder: (_, state) => _needs<DemoWorker>(
          state,
          what: 'one worker being monitored',
          returnLabel: 'Go to active monitoring',
          returnRoute: '/hse/monitoring',
          build: (worker) => ActiveMonitoringDetailScreen(worker: worker),
        ),
      ),
      GoRoute(
        path: '/hse/workers',
        builder: (_, _) => const HseWorkerSearchScreen(),
      ),
      GoRoute(
        path: '/hse/worker',
        builder: (_, state) => _needs<DemoWorker>(
          state,
          what: 'one worker\'s exposure profile',
          returnLabel: 'Search for a worker',
          returnRoute: '/hse/workers',
          build: (worker) => WorkerExposureProfileScreen(worker: worker),
        ),
      ),
      GoRoute(
        path: '/hse/exceptions',
        builder: (_, _) => const ExceptionQueueScreen(),
      ),
      GoRoute(
        path: '/hse/inventory',
        builder: (_, _) => const BadgeInventoryScreen(),
      ),
      GoRoute(
        path: '/hse/batch',
        builder: (_, state) => _needs<String>(
          state,
          what: 'one badge batch',
          returnLabel: 'Go to badge inventory',
          returnRoute: '/hse/inventory',
          build: (batchId) => BatchDetailScreen(batchId: batchId),
        ),
      ),
      GoRoute(
        path: '/hse/calibration',
        builder: (_, _) => const CalibrationDetailScreen(),
      ),
      GoRoute(path: '/hse/audit', builder: (_, _) => const AuditTrailScreen()),

      // ------------------------------------------------------- HSE shell
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => HseShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/hse',
                builder: (_, _) => const HseDashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/hse/monitoring',
                builder: (_, _) => const HseActiveMonitoringScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/hse/exposures',
                builder: (_, _) => const HseExposureRegisterScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/hse/review',
                builder: (_, _) => const HseReviewQueueScreen(),
              ),
            ],
          ),
        ],
      ),

      // ------------------------------------------------------- reporting
      GoRoute(
        path: '/reporting',
        builder: (_, _) => const ReportingCentreScreen(),
      ),
      GoRoute(
        path: '/reporting/report',
        builder: (_, state) => _needs<ReportKind>(
          state,
          what: 'one kind of report',
          returnLabel: 'Go to the reporting centre',
          returnRoute: '/reporting',
          build: (kind) => ReportDetailScreen(kind: kind),
        ),
      ),
      GoRoute(
        path: '/reporting/register',
        builder: (_, _) => const OccupationalRegisterScreen(),
      ),
      GoRoute(
        path: '/reporting/record',
        builder: (_, state) => _needs<OccupationalRecord>(
          state,
          what: 'the traceability chain behind one record',
          returnLabel: 'Go to the occupational register',
          returnRoute: '/reporting/register',
          build: (record) => RecordTraceabilityScreen(record: record),
        ),
      ),
      GoRoute(
        path: '/reporting/builder',
        builder: (_, _) => const ReportBuilderScreen(),
      ),
      GoRoute(
        path: '/reporting/preview',
        builder: (_, state) => _needs<ReportDefinition>(
          state,
          what: 'a report definition to preview',
          returnLabel: 'Go to the report builder',
          returnRoute: '/reporting/builder',
          build: (definition) => ReportPreviewScreen(definition: definition),
        ),
      ),
      GoRoute(
        path: '/reporting/audit-package',
        builder: (_, _) => const AuditPackageScreen(),
      ),
      GoRoute(
        path: '/reporting/history',
        builder: (_, _) => const ExportHistoryScreen(),
      ),

      // ----------------------------------------------------------- admin
      GoRoute(
        path: '/admin',
        builder: (_, _) => AdminHomeScreen(config: config),
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
        path: '/admin/users',
        builder: (_, _) => const AdminUsersScreen(),
      ),
      GoRoute(
        path: '/admin/users/:userId',
        builder: (_, state) {
          final id = state.pathParameters['userId']!;
          final user = AdminDemoCatalog.users()
              .where((u) => u.userId == id)
              .firstOrNull;
          if (user == null) {
            return AdminRecordNotFoundScreen(
              recordKind: 'user',
              identifier: id,
            );
          }
          return AdminUserDetailScreen(user: user);
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
        path: '/admin/devices',
        builder: (_, _) => const AdminDevicesScreen(),
      ),
      GoRoute(
        path: '/admin/devices/:deviceId',
        builder: (_, state) {
          final id = state.pathParameters['deviceId']!;
          final device = AdminDemoCatalog.devices()
              .where((d) => d.deviceId == id)
              .firstOrNull;
          if (device == null) {
            return AdminRecordNotFoundScreen(
              recordKind: 'device',
              identifier: id,
            );
          }
          return AdminDeviceDetailScreen(device: device);
        },
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
        path: '/admin/system',
        builder: (_, _) => SystemInformationScreen(config: config),
      ),
      // Compiled out of production, like the gallery and the worker previews.
      if (config.simulationAvailable)
        GoRoute(
          path: '/admin/demo-data',
          builder: (_, _) => const DemoDataControlsScreen(),
        ),
    ],
  );
}

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
