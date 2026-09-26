/// Connectivity and synchronisation states (APP-PRODUCT-01 §42).
///
/// The architecture is **server-authoritative and offline-capable**. Neither
/// the server nor sync exists yet (P10), so the only states this build can
/// honestly produce are listed in [SyncState.producibleToday]. There is no
/// count of pending records anywhere: a count needs a queue, and there is no
/// queue.
library;

/// Whether the device can reach the network. Distinct from whether a server
/// exists: [online] with no server configured is still [SyncState.notConnected].
enum ConnectivityState {
  online,
  offline,

  /// Not yet determined. Never shown as "online".
  unknown,
}

/// Where a locally produced record stands with the central server.
enum SyncState {
  /// Saved on this device only, and no server exists to send it to. The
  /// honest state for every record today.
  localOnly,

  /// Waiting to be sent: a server is configured and the device is offline or
  /// the upload has not run. **Not producible today.**
  syncPending,

  /// Accepted by the server. **Not producible today.**
  synced,

  /// The server refused or the upload failed. Distinct from an invalid
  /// measurement: a sync failure says nothing about the reading. **Not
  /// producible today.**
  syncFailed,

  /// No central server is connected to this build.
  notConnected;

  static const Set<SyncState> producibleToday = {localOnly, notConnected};

  String get label => switch (this) {
    SyncState.localOnly => 'Saved on this device',
    SyncState.syncPending => 'Waiting to sync',
    SyncState.synced => 'Synced',
    SyncState.syncFailed => 'Sync failed',
    SyncState.notConnected => 'Server not connected',
  };

  /// Worker-facing sentence. Says what happened and what happens next, and
  /// claims a save only where one happened (§94).
  String get explanation => switch (this) {
    SyncState.localOnly =>
      'This record is stored on this phone. No central server is connected '
          'yet, so it has not been sent anywhere.',
    SyncState.syncPending =>
      'Saved on this phone. It will be sent when a connection is available.',
    SyncState.synced => 'This record is held by the central server.',
    SyncState.syncFailed =>
      'Saved on this phone, but sending it failed. The reading is unaffected. '
          'It will be tried again.',
    SyncState.notConnected =>
      'This build has no central server. Records stay on this phone.',
  };
}
