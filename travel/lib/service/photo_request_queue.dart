import 'dart:async';
import 'dart:collection';

/// Bounded concurrency for image metadata requests, not image downloads.
class PhotoRequestQueue {
  final Queue<Future<void> Function()> _waiting = Queue();
  int _active = 0;
  Future<void> run(Future<void> Function() task) {
    final result = Completer<void>();
    _waiting.add(() async {
      try {
        await task();
        result.complete();
      } catch (error, stack) {
        result.completeError(error, stack);
      }
    });
    _drain();
    return result.future;
  }

  void _drain() {
    while (_active < 2 && _waiting.isNotEmpty) {
      _active++;
      final task = _waiting.removeFirst();
      task().whenComplete(() {
        _active--;
        _drain();
      });
    }
  }
}
