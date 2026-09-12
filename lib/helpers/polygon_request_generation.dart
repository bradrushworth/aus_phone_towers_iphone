import 'package:dio/dio.dart';

/// Owns the lifetime of asynchronous coverage-polygon requests.
///
/// A Follow GPS or polygon-settings refresh invalidates the whole generation. Every request from
/// the older generation is cancelled, and even a transport that completes cancellation late can
/// be identified as stale before it draws map overlays.
class PolygonRequestGeneration {
  int _current = 0;
  final Set<CancelToken> _active = <CancelToken>{};

  int get current => _current;
  int get activeCount => _active.length;

  bool isCurrent(int generation) => generation == _current;

  CancelToken createToken() {
    final CancelToken token = CancelToken();
    _active.add(token);
    return token;
  }

  void complete(CancelToken token) {
    _active.remove(token);
  }

  void invalidate(String reason) {
    _current++;
    for (final CancelToken token in _active) {
      if (!token.isCancelled) {
        token.cancel(reason);
      }
    }
    _active.clear();
  }
}
