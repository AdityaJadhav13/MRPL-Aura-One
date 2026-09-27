import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/components/wordmark.dart';
import '../../../../core/design/theme.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/router/route_gate.dart';
import '../../application/auth_controller.dart';
import '../widgets/mrpl_brandmark.dart';

/// Launch (PRODUCT BUILD v1 §55).
///
/// White, still, and gone as soon as the stored session has been read — one
/// small file. No video, no animation, no button, no artificial delay: the
/// previous splash felt slow because it *was* slow on purpose.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({this.from, super.key});

  /// Where a deep link was headed before the session was known.
  final String? from;

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _continue());
  }

  Future<void> _continue() async {
    await ref.read(authControllerProvider.notifier).restore();
    if (!mounted) return;
    final auth = ref.read(authControllerProvider);
    final session = auth.session;
    if (session == null) {
      context.go('/sign-in');
      return;
    }
    final from = widget.from;
    context.go(
      from != null && RouteGate.allows(session: session, location: from)
          ? from
          : session.activeRole.landingRoute,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.product;
    return Scaffold(
      backgroundColor: p.surfacePage,
      body: SafeArea(
        child: Center(
          child: Semantics(
            label: 'DoseBand is starting',
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                MrplBrandmark(size: 56),
                SizedBox(height: Space.lg),
                Wordmark(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
