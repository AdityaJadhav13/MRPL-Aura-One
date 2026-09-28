import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h2s_doseband/core/components/identity.dart';
import 'package:h2s_doseband/core/design/brand_assets.dart';
import 'package:h2s_doseband/core/env/environment.dart';
import 'package:h2s_doseband/features/auth/application/auth_controller.dart';
import 'package:h2s_doseband/features/operations/application/operations_repository.dart';
import 'package:h2s_doseband/features/operations/data/operations_store.dart';
import 'package:h2s_doseband/features/operations/data/presentation_dataset.dart';
import 'package:h2s_doseband/features/operations/domain/operations_snapshot.dart';
import 'package:h2s_doseband/features/operations/domain/organisation.dart';
import 'package:h2s_doseband/features/workflow/application/workflow_controller.dart';
import 'package:h2s_doseband/features/workflow/data/workflow_store.dart';
import 'package:h2s_doseband/main.dart';

import '../support/signed_in.dart';

const _dev = EnvironmentConfig(
  environment: AppEnvironment.dev,
  supabaseUrl: '',
  supabaseAnonKey: '',
);

/// Worker directive §6–§11, §32–§34, §48, §56: Profile is the worker's own
/// record, resolved from the signed-in identity; Settings holds account and
/// app information; signing out ends the session and nothing else.
void main() {
  final now = DateTime(2026, 9, 27, 10, 30);

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    String personId = PresentationDataset.aditya,
    String at = '/profile',
    OperationsSnapshot? seed,
  }) async {
    tester.view.physicalSize = const Size(390 * 2, 1600 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [
        environmentConfigProvider.overrideWithValue(_dev),
        ...signedInOverrides(
          personId: personId,
          now: now,
          store: InMemoryOperationsStore(seed ?? datasetWithRecord(now)),
        ),
        workflowStoreProvider.overrideWithValue(InMemoryWorkflowStore()),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: DoseBandApp(config: _dev, initialLocation: at),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('shows the signed-in worker, not a fixed identity', (
    tester,
  ) async {
    await pump(tester, personId: PresentationDataset.lavitra);
    expect(find.text('Lavitra Satam'), findsOneWidget);
    expect(find.text('Aditya Jadhav'), findsNothing);
    expect(find.text('Employee · ID E-10231'), findsOneWidget);
  });

  testWidgets('Today’s shift carries site, department, shift and area', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('TODAY’S SHIFT'), findsOneWidget);
    for (final label in ['Site', 'Department', 'Shift', 'Work area']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('Mangalore Refinery'), findsOneWidget);
    expect(find.text('Date'), findsOneWidget);
  });

  testWidgets('Work context references; it never approves', (tester) async {
    await pump(tester);
    expect(find.text('WORK CONTEXT'), findsOneWidget);
    for (final t in tester.widgetList<Text>(find.byType(Text))) {
      final s = (t.data ?? '').toLowerCase();
      expect(s, isNot(contains('safe to work')));
      expect(s, isNot(contains('approved')));
    }
  });

  testWidgets('initials until a photograph is supplied', (tester) async {
    await pump(tester);
    final avatar = tester.widget<IdentityAvatar>(find.byType(IdentityAvatar));
    expect(avatar.photo, isNull);
    expect(find.text('AJ'), findsOneWidget);
  });

  testWidgets('an approved photograph replaces the initials without a '
      'redesign', (tester) async {
    final base = datasetWithRecord(now);
    final seed = base.copyWith(
      people: [
        for (final p in base.people)
          p.personId == PresentationDataset.aditya
              ? Person(
                  personId: p.personId,
                  displayName: p.displayName,
                  workerType: p.workerType,
                  siteId: p.siteId,
                  departmentId: p.departmentId,
                  designation: p.designation,
                  roles: p.roles,
                  provenance: p.provenance,
                  contractorCompany: p.contractorCompany,
                  defaultWorkAreaId: p.defaultWorkAreaId,
                  defaultShiftId: p.defaultShiftId,
                  // Any bundled asset stands in for a supplied photograph.
                  photoAsset: BrandAssets.mrplLogo,
                )
              : p,
      ],
    );
    await pump(tester, seed: seed);
    final avatar = tester.widget<IdentityAvatar>(find.byType(IdentityAvatar));
    expect(avatar.photo, isA<AssetImage>());
  });

  testWidgets('Settings: account, privacy, about — no developer tools', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    for (final label in [
      'Signed in as',
      'Role',
      'Location',
      'Version',
      'Build',
      'Measurement engine',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('Developer and research tools'), findsNothing);
    expect(find.byType(Switch), findsNothing, reason: 'no decorative toggles');
  });

  testWidgets('signing out keeps every monitoring record', (tester) async {
    final c = await pump(tester, at: '/profile/settings');
    final before = (await c.read(operationsProvider.future)).measurements;
    expect(before, isNotEmpty);

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
    await tester.pumpAndSettle();

    expect(c.read(authControllerProvider).isSignedIn, isFalse);
    final after = (await c.read(operationsProvider.future)).measurements;
    expect(after.map((m) => m.id), before.map((m) => m.id));
  });
}
