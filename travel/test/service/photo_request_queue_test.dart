import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel/service/photo_request_queue.dart';

void main() {
  test(
    'two photos run concurrently and a slow first photo does not block third',
    () async {
      final queue = PhotoRequestQueue();
      final first = Completer<void>();
      final second = Completer<void>();
      final started = <int>[];
      final a = queue.run(() async {
        started.add(1);
        await first.future;
      });
      final b = queue.run(() async {
        started.add(2);
        await second.future;
      });
      final c = queue.run(() async {
        started.add(3);
      });
      expect(started, [1, 2]);
      second.complete();
      await b;
      await Future<void>.delayed(Duration.zero);
      expect(started, [1, 2, 3]);
      first.complete();
      await Future.wait([a, c]);
    },
  );
}
