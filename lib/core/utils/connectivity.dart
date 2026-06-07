import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Lightweight, dependency-free connectivity abstraction (Requirement 17).
///
/// The project's network access is restricted and no `connectivity_plus`
/// package is available, so rather than taking a new dependency this service
/// performs a best-effort reachability probe using only `dart:io`. It resolves
/// a well-known host (Firestore's API endpoint by default) and treats a
/// successful DNS lookup as "online" and a [SocketException] / timeout as
/// "offline".
///
/// A periodic [Timer] re-probes on a fixed interval and the service emits on
/// [onlineChanges] only when the resolved state *changes*, so consumers can
/// cheaply react to connectivity transitions (e.g. auto-retrying a failed
/// catalog or chat fetch when the network returns — Requirement 17.2).
///
/// The probe is intentionally defensive: any error other than a genuine
/// connectivity failure (for example running on a platform where `dart:io`
/// socket lookups are unsupported) is swallowed and reported as **online**, so
/// the connectivity layer can never wedge an otherwise-working app into a
/// permanently "offline" state.
class ConnectivityService {
  /// Creates a connectivity service.
  ///
  /// [host] is the endpoint resolved by the default probe; [pollInterval] is
  /// how often connectivity is re-checked. [probe] can be injected in tests to
  /// avoid real DNS lookups.
  ConnectivityService({
    this.host = 'firestore.googleapis.com',
    this.pollInterval = const Duration(seconds: 10),
    Future<bool> Function(String host)? probe,
  }) : _probe = probe ?? _defaultProbe;

  /// The host whose reachability is used as the online/offline signal.
  final String host;

  /// How frequently connectivity is re-probed once [start] has been called.
  final Duration pollInterval;

  final Future<bool> Function(String host) _probe;

  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  Timer? _timer;
  bool? _last;
  bool _started = false;

  /// Emits the latest online/offline state whenever it *changes* (`true` =
  /// online). It does not replay the current value to new listeners; callers
  /// that need an immediate reading should call [isOnline] first.
  Stream<bool> get onlineChanges => _controller.stream;

  /// Performs a one-off, best-effort connectivity check.
  ///
  /// Returns `true` when the [host] resolves (online) and `false` on a genuine
  /// connectivity failure. Never throws.
  Future<bool> isOnline() => _probe(host);

  /// Begins periodic polling. Safe to call more than once (subsequent calls are
  /// no-ops). Performs an immediate check before scheduling the recurring poll.
  void start() {
    if (_started) {
      return;
    }
    _started = true;
    unawaited(_check());
    _timer = Timer.periodic(pollInterval, (_) => unawaited(_check()));
  }

  Future<void> _check() async {
    final bool online = await isOnline();
    if (online != _last) {
      _last = online;
      if (!_controller.isClosed) {
        _controller.add(online);
      }
    }
  }

  /// Default reachability probe backed by [InternetAddress.lookup].
  ///
  /// A non-empty lookup result means online. A [SocketException] or timeout is
  /// a genuine connectivity failure (offline); any other error is treated as a
  /// platform that cannot perform the lookup, in which case we optimistically
  /// assume the device is online.
  static Future<bool> _defaultProbe(String host) async {
    try {
      final List<InternetAddress> result = await InternetAddress.lookup(host)
          .timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } on SocketException {
      return false;
    } on TimeoutException {
      return false;
    } catch (_) {
      // Unsupported platform / unexpected error: default to online so the
      // connectivity layer never falsely blocks a working app.
      return true;
    }
  }

  /// Cancels polling and releases the underlying stream.
  void dispose() {
    _timer?.cancel();
    _timer = null;
    unawaited(_controller.close());
  }
}

/// Exposes the singleton [ConnectivityService] and starts its polling.
///
/// Disposed automatically with the owning [ProviderScope]. Override in tests
/// with a service constructed using a fake `probe` to drive connectivity
/// transitions deterministically.
final connectivityProvider = Provider<ConnectivityService>((ref) {
  final service = ConnectivityService()..start();
  ref.onDispose(service.dispose);
  return service;
});

/// Streams the device's online/offline state (`true` = online).
///
/// Seeds with an immediate [ConnectivityService.isOnline] reading so consumers
/// receive a value without waiting for the first poll, then follows live
/// [ConnectivityService.onlineChanges]. Catalog and chat providers watch this
/// so they automatically re-subscribe (retry) when connectivity is regained
/// (Requirement 17.2).
final isOnlineProvider = StreamProvider<bool>((ref) async* {
  final ConnectivityService service = ref.watch(connectivityProvider);
  yield await service.isOnline();
  yield* service.onlineChanges;
});
