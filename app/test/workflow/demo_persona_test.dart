import 'package:flutter_test/flutter_test.dart';
import 'package:h2s_doseband/features/operations/data/presentation_dataset.dart';
import 'package:h2s_doseband/features/workflow/data/simulation_catalog.dart';
import 'package:h2s_doseband/features/workflow/domain/worker_identity.dart';

/// The demo persona must be the same person everywhere.
///
/// Two places describe them: the presentation dataset's contractor account,
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
  final account = PresentationDataset.people.firstWhere(
    (p) => p.personId == PresentationDataset.aditya,
  );

  test('the demo contractor is the presentation contractor account', () {
    final worker = SimulationCatalog.demoWorker();

    expect(worker.workerType, WorkerType.contractor);
    expect(worker.workerId, account.personId);
    expect(worker.displayName, account.displayName);
    expect(worker.contractorCompany, account.contractorCompany);
  });

  test('the demo work context carries that same person by default', () {
    final worker = SimulationCatalog.demoContext().worker;

    expect(worker.workerId, account.personId);
    expect(worker.displayName, account.displayName);
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
