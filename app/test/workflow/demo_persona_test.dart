import 'package:flutter_test/flutter_test.dart';
import 'package:h2s_doseband/features/auth/data/demo_account.dart';
import 'package:h2s_doseband/features/workflow/data/simulation_catalog.dart';
import 'package:h2s_doseband/features/workflow/domain/worker_identity.dart';

/// The demo persona must be the same person everywhere.
///
/// Two places describe them: the published demo account on the sign-in screen,
/// and the simulation catalogue's demo work context. They are deliberately not
/// wired together — the workflow domain does not import the authentication
/// feature, because a stored work context is provenance that has to outlive any
/// sign-in redesign.
///
/// That independence is worth keeping, but it means the two can drift. A
/// reviewer who signs in as one person and finds a different name on the HSE
/// register learns that the demo data is arbitrary, and then discounts all of
/// it. This test is the seam that stops it.
void main() {
  test('the demo contractor is the published demo account', () {
    final worker = SimulationCatalog.demoWorker();

    expect(worker.workerType, WorkerType.contractor);
    expect(worker.workerId, DemoAccount.workerId);
    expect(worker.displayName, DemoAccount.displayName);
    expect(worker.contractorCompany, DemoAccount.contractorCompany);
  });

  test('the demo work context carries that same person by default', () {
    final worker = SimulationCatalog.demoContext().worker;

    expect(worker.workerId, DemoAccount.workerId);
    expect(worker.displayName, DemoAccount.displayName);
    expect(worker.contractorCompanyIsCoherent, isTrue);
  });

  test('an employee variant is still available and coherent', () {
    // Needed by the contractor-policy tests, which have to be able to build an
    // employee with no contractor company.
    final employee = SimulationCatalog.demoWorker(type: WorkerType.employee);

    expect(employee.workerType, WorkerType.employee);
    expect(employee.contractorCompany, isNull);
    expect(employee.contractorCompanyIsCoherent, isTrue);
  });
}
