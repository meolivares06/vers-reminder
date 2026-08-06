import 'package:flutter_test/flutter_test.dart';

import 'package:vers_reminder/shared/event_bus/event_bus.dart';
import 'package:vers_reminder/shared/event_bus/events.dart';

// ── Test event types ────────────────────────────────────────────────────────

class TestEvent {
  final String message;
  const TestEvent(this.message);
}

class OtherEvent {
  final int value;
  const OtherEvent(this.value);
}

class EmptyEvent {
  const EmptyEvent();
}

// ── R1: Typed lifecycle ─────────────────────────────────────────────────────

void main() {
  group('EventBus typed lifecycle (R1)', () {
    test('emit delivers event to matching handler', () async {
      final bus = EventBus.instance;

      TestEvent? received;
      bus.on<TestEvent>((event) async {
        received = event;
      });

      await bus.emit(const TestEvent('hello'));

      expect(received, isNotNull);
      expect(received!.message, 'hello');
    });

    test('emit does NOT deliver to handler of different type', () async {
      final bus = EventBus.instance;

      OtherEvent? received;
      bus.on<OtherEvent>((event) async {
        received = event;
      });

      await bus.emit(const TestEvent('ignored'));

      expect(received, isNull);
    });

    test('no handler registered completes silently', () async {
      final bus = EventBus.instance;

      // Should not throw — emit completes normally when no handler for type
      await bus.emit(const EmptyEvent());
    });

    test('multiple handlers for same type all receive event', () async {
      final bus = EventBus.instance;

      final received = <String>[];
      bus.on<TestEvent>((event) async {
        received.add('A:${event.message}');
      });
      bus.on<TestEvent>((event) async {
        received.add('B:${event.message}');
      });

      await bus.emit(const TestEvent('multi'));

      expect(received.length, 2);
      expect(received, contains('A:multi'));
      expect(received, contains('B:multi'));
    });
  });

  // ── R2: Error isolation ────────────────────────────────────────────────────

  group('EventBus error isolation (R2)', () {
    test(
      'second handler throws, third still executes',
      () async {
        final bus = EventBus.instance;

        final executed = <String>[];
        bus.on<TestEvent>((event) async {
          executed.add('A');
        });
        bus.on<TestEvent>((event) async {
          executed.add('B');
          throw StateError('handler B failure');
        });
        bus.on<TestEvent>((event) async {
          executed.add('C');
        });

        await bus.emit(const TestEvent('chain'));

        expect(executed, ['A', 'B', 'C']);
      },
    );

    test('all handlers throw, emit does not crash', () async {
      final bus = EventBus.instance;

      bus.on<TestEvent>((event) async {
        throw Exception('fail 1');
      });
      bus.on<TestEvent>((event) async {
        throw Exception('fail 2');
      });

      // Should NOT throw — emit catches both and returns normally
      await bus.emit(const TestEvent('all-fail'));
    });
  });

  // ── R3: Registration-order execution ───────────────────────────────────────

  group('EventBus registration order (R3)', () {
    test('handlers execute in registration order', () async {
      final bus = EventBus.instance;

      final order = <int>[];
      bus.on<TestEvent>((event) async {
        order.add(1);
      });
      bus.on<TestEvent>((event) async {
        order.add(2);
      });
      bus.on<TestEvent>((event) async {
        order.add(3);
      });

      await bus.emit(const TestEvent('ord'));

      expect(order, [1, 2, 3]);
    });

    test('order preserved across registrations of different types', () async {
      final bus = EventBus.instance;

      final log = <String>[];
      bus.on<TestEvent>((event) async {
        log.add('TE');
      });
      bus.on<OtherEvent>((event) async {
        log.add('OE1');
      });
      bus.on<OtherEvent>((event) async {
        log.add('OE2');
      });

      await bus.emit(const OtherEvent(42));

      expect(log, ['OE1', 'OE2']);
    });
  });

  // ── Backup events (F2: BackupRequested + BackupRestored) ───────────────────

  group('Backup events', () {
    test('BackupRequested carries operation field via event bus', () async {
      final bus = EventBus.instance;

      String? receivedOp;
      bus.on<BackupRequested>((event) async {
        receivedOp = event.operation;
      });

      await bus.emit(const BackupRequested(operation: 'backup'));

      expect(receivedOp, 'backup');
    });

    test('BackupRequested restore operation is distinct', () async {
      final bus = EventBus.instance;

      String? receivedOp;
      bus.on<BackupRequested>((event) async {
        receivedOp = event.operation;
      });

      await bus.emit(const BackupRequested(operation: 'restore'));

      expect(receivedOp, 'restore');
    });

    test('BackupRestored carries success and operation fields', () async {
      final bus = EventBus.instance;

      BackupRestored? received;
      bus.on<BackupRestored>((event) async {
        received = event;
      });

      await bus.emit(
        const BackupRestored(success: true, operation: 'backup'),
      );

      expect(received, isNotNull);
      expect(received!.success, true);
      expect(received!.operation, 'backup');
    });

    test('BackupRestored failure is delivered with success=false', () async {
      final bus = EventBus.instance;

      BackupRestored? received;
      bus.on<BackupRestored>((event) async {
        received = event;
      });

      await bus.emit(
        const BackupRestored(success: false, operation: 'restore'),
      );

      expect(received, isNotNull);
      expect(received!.success, false);
      expect(received!.operation, 'restore');
    });

    test(
      'BackupRequested → BackupRestored end-to-end chain',
      () async {
        final bus = EventBus.instance;
        final log = <String>[];

        // Simulate: backup service listens for BackupRequested
        // and emits BackupRestored on completion
        bus.on<BackupRequested>((event) async {
          log.add('requested:${event.operation}');
          await bus.emit(BackupRestored(
            success: true,
            operation: event.operation,
          ));
        });

        bus.on<BackupRestored>((event) async {
          log.add('restored:${event.operation}:${event.success}');
        });

        await bus.emit(const BackupRequested(operation: 'backup'));

        expect(log, ['requested:backup', 'restored:backup:true']);
      },
    );
  });

  // ── Edge cases ─────────────────────────────────────────────────────────────

  group('EventBus edge cases', () {
    test('emit with empty handler list does not throw', () async {
      final bus = EventBus.instance;

      // Register and then... well, emit a type that has handlers but
      // there's no "deregister" API. Instead, just emit a type
      // that was never registered.
      await bus.emit(const TestEvent('unregistered-type'));
    });

    test('multiple emits in sequence work correctly', () async {
      final bus = EventBus.instance;

      final received = <String>[];
      bus.on<TestEvent>((event) async {
        received.add(event.message);
      });

      await bus.emit(const TestEvent('first'));
      await bus.emit(const TestEvent('second'));
      await bus.emit(const TestEvent('third'));

      expect(received, ['first', 'second', 'third']);
    });
  });
}
