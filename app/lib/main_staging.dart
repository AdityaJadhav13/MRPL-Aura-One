import 'package:h2s_doseband/core/env/environment.dart';
import 'package:h2s_doseband/main.dart';

void main() =>
    bootstrap(EnvironmentConfig.fromDartDefines(AppEnvironment.staging));
