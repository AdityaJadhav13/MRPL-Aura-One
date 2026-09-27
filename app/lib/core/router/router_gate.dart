import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/application/auth_controller.dart';
import 'route_gate.dart';

/// Connects [RouteGate] to the router: re-evaluates on every auth change.
abstract interface class RouterGate implements Listenable {
  String? redirect(String location);
}

/// The application's gate, reading auth state from Riverpod.
final class AuthRouterGate extends ChangeNotifier implements RouterGate {
  AuthRouterGate(this._container) {
    _subscription = _container.listen(
      authControllerProvider,
      (_, _) => notifyListeners(),
    );
  }

  final ProviderContainer _container;
  late final ProviderSubscription<Object?> _subscription;

  @override
  String? redirect(String location) => RouteGate.redirect(
    auth: _container.read(authControllerProvider),
    location: location,
    devToolsAvailable: _container
        .read(environmentConfigProvider)
        .simulationAvailable,
  );

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}
