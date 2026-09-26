/// Where a number came from. Directive s30, ADR-0006.
///
/// This is not a debug flag. It travels with every optical observation so that
/// a simulated value cannot be mistaken for a laboratory one at any point,
/// including in an export, a log line or a screenshot in a slide deck.
enum DataDomain {
  /// Synthesised. Proves the code runs; proves nothing about chemistry.
  simulated,

  /// Controlled and traceable: printed optical targets, or gas-exposed
  /// coupons from a qualified laboratory.
  lab,

  /// A real badge worn by a real worker.
  field,
}

extension DataDomainDisplay on DataDomain {
  /// The label that must accompany any presentation of this data.
  String get disclosure => switch (this) {
    DataDomain.simulated => 'SIMULATED — NOT A REAL H2S MEASUREMENT',
    DataDomain.lab => 'LABORATORY DATA',
    DataDomain.field => 'FIELD MEASUREMENT',
  };

  /// Whether a quantitative exposure value may ever be derived from data in
  /// this domain and shown to a worker.
  bool get mayProduceWorkerFacingDose => this == DataDomain.field;
}
