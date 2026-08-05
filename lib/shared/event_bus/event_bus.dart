import 'dart:async';

/// Lightweight typed async event bus for inter-module communication.
///
/// Handlers registered via [on] run sequentially in registration order
/// within each event type. One handler throwing does **not** prevent
/// other handlers for the same type from executing (error isolation).
///
/// ```dart
/// final bus = EventBus.instance;
/// bus.on<WallpaperGenerated>((event) async { ... });
/// await bus.emit(const WallpaperGenerated(path: '/tmp/w.png'));
/// ```
class EventBus {
  EventBus._();

  /// The process-wide singleton.
  static final EventBus instance = EventBus._();

  final Map<Type, List<Function>> _handlers = {};

  /// Register a typed handler for events of type [T].
  ///
  /// Each handler receives every [emit] call whose type argument
  /// matches [T]. Handlers execute in the order they were registered.
  void on<T>(Future<void> Function(T) handler) {
    _handlers.putIfAbsent(T, () => []).add(handler);
  }

  /// Dispatch [event] to all handlers registered for [T].
  ///
  /// Returns after every handler has completed (or thrown). Thrown
  /// exceptions are caught per-handler and do not abort the
  /// remaining dispatch chain.
  Future<void> emit<T>(T event) async {
    final handlers = _handlers[T];
    if (handlers == null || handlers.isEmpty) return;

    for (final handler in handlers) {
      try {
        await (handler as Future<void> Function(T))(event);
      } catch (_) {
        // Handler error isolation (R2): one failure must not
        // prevent other handlers from executing.
      }
    }
  }
}
