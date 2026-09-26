@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h2s_doseband/core/components/product_navigation.dart';
import 'package:h2s_doseband/core/components/product_page.dart';
import 'package:h2s_doseband/core/design/brand_assets.dart';
import 'package:h2s_doseband/core/components/product_states.dart';
import 'package:h2s_doseband/core/design/theme.dart';
import 'package:h2s_doseband/core/env/environment.dart';
import 'package:h2s_doseband/features/dev/component_catalog_screen.dart';
import 'package:h2s_doseband/features/workflow/application/workflow_controller.dart';
import 'package:h2s_doseband/main.dart';

import '../support/responsive.dart';

const _dev = EnvironmentConfig(
  environment: AppEnvironment.dev,
  supabaseUrl: '',
  supabaseAnonKey: '',
);

/// The canonical shared-foundation golden set (APP-PRODUCT-01 §71, §112).
///
/// Replaces the four-destination shell goldens. Deliberately compact: the
/// worker shell at each representative width, at 200% text, as a rail and in
/// landscape; then each catalog section once. Screen goldens for legacy
/// surfaces stay with their own suites and migrate with their phases.
void main() {
  Future<void> shell(
    WidgetTester tester,
    Size size, {
    String at = '/home',
    double textScale = 1,
    double bottomInset = 0,
  }) async {
    setView(tester, size, bottomInset: bottomInset);
    if (textScale != 1) setTextScale(tester, textScale);
    await tester.pumpWidget(
      ProviderScope(
        // Pinned: Home renders today's date.
        overrides: [
          clockProvider.overrideWithValue(() => DateTime(2026, 9, 27, 8, 4)),
        ],
        child: DoseBandApp(
          key: ValueKey(at),
          config: _dev,
          initialLocation: at,
        ),
      ),
    );
    // Decode the brand photograph for real before capturing. Asset decoding
    // is real IO; without this a golden shows whichever frame decoding had
    // reached, which varies from run to run.
    final context = tester.element(find.byType(Scaffold).first);
    await tester.runAsync(
      () => precacheImage(
        const AssetImage(BrandAssets.refineryBackdrop),
        context,
      ),
    );
    await tester.pumpAndSettle();
  }

  group('worker shell', () {
    final shells = <String, (Size, String, double, double)>{
      'shell-home-360': (const Size(360, 640), '/home', 1, 0),
      'shell-home-390': (const Size(390, 844), '/home', 1, 34),
      'shell-home-430': (const Size(430, 932), '/home', 1, 34),
      'shell-history-390': (const Size(390, 844), '/history', 1, 34),
      'shell-scan-390': (const Size(390, 844), '/scan', 1, 34),
      'shell-safety-390': (const Size(390, 844), '/safety', 1, 34),
      'shell-profile-390': (const Size(390, 844), '/profile', 1, 34),
      'shell-home-320-text200': (const Size(320, 568), '/home', 2, 0),
      'shell-history-360-text200': (const Size(360, 640), '/history', 2, 0),
      'shell-home-rail-1280x800': (const Size(1280, 800), '/home', 1, 0),
      'shell-safety-600x960': (const Size(600, 960), '/safety', 1, 0),
      'shell-home-landscape-844x390': (const Size(844, 390), '/home', 1, 0),
    };
    for (final e in shells.entries) {
      testWidgets(e.key, (tester) async {
        final (size, at, scale, inset) = e.value;
        await shell(tester, size, at: at, textScale: scale, bottomInset: inset);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/foundation-${e.key}.png'),
        );
      });
    }
  });

  group('components', () {
    Future<void> section(WidgetTester tester, Widget child, Size size) async {
      setView(tester, size);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildDoseBandTheme(brightness: Brightness.light),
          home: ProductPage(title: 'Component catalog', children: [child]),
        ),
      );
      // Fixed frames: loading states hold indeterminate spinners.
      await tester.pump(const Duration(milliseconds: 300));
    }

    final sections = <String, (Widget, Size)>{
      'palette': (const CatalogPalette(), const Size(390, 900)),
      'typography': (const CatalogTypography(), const Size(390, 900)),
      'buttons': (const CatalogButtons(), const Size(390, 900)),
      'inputs': (const CatalogInputs(), const Size(390, 1100)),
      'cards': (const CatalogCards(), const Size(390, 900)),
      'statuses': (const CatalogStatuses(), const Size(390, 1000)),
      'identity': (const CatalogIdentity(), const Size(390, 500)),
      'navigation': (const CatalogNavigation(), const Size(390, 400)),
      'records-phone': (const CatalogRecords(), const Size(390, 500)),
      'records-wide': (const CatalogRecords(), const Size(900, 500)),
    };
    for (final e in sections.entries) {
      testWidgets(e.key, (tester) async {
        final (widget, size) = e.value;
        await section(tester, widget, size);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/foundation-catalog-${e.key}.png'),
        );
      });
    }
  });

  group('states', () {
    for (final kind in [
      StateKind.empty,
      StateKind.offline,
      StateKind.error,
      StateKind.notConnected,
    ]) {
      testWidgets('state-${kind.name}', (tester) async {
        setView(tester, const Size(360, 640));
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildDoseBandTheme(brightness: Brightness.light),
            home: Scaffold(
              appBar: AppBar(title: const Text('History')),
              body: StateView(
                kind: kind,
                message: CatalogStates.messages[kind]!,
                actionLabel: kind == StateKind.error ? 'Scan again' : null,
                onAction: () {},
              ),
            ),
          ),
        );
        await tester.pump();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/foundation-state-${kind.name}.png'),
        );
      });
    }

    testWidgets('state-offline-in-shell', (tester) async {
      // A state inside the real shell: the floating bar under it.
      setView(tester, const Size(360, 640));
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildDoseBandTheme(brightness: Brightness.light),
          home: AdaptiveNavigationScaffold(
            destinations: WorkspaceDestinations.worker,
            selectedIndex: 1,
            onSelected: (_) {},
            body: Scaffold(
              appBar: AppBar(title: const Text('History')),
              body: StateView(
                kind: StateKind.offline,
                message: CatalogStates.messages[StateKind.offline]!,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/foundation-state-offline-in-shell.png'),
      );
    });
  });
}
