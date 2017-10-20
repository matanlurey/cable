// Copyright 2017, Google Inc.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:meta/meta.dart';

/// Logging levels ordered _descending_ from most important to least important.
class Severity implements Comparable<Severity> {
  /// One or more systems are unusable.
  static const Severity emergency = const Severity._('emergency', 0);

  /// A person must take an action immediately.
  static const Severity alert = const Severity._('alert', 1);

  /// Critical events cause more severe problems or outages.
  static const Severity critical = const Severity._('critical', 2);

  /// Error events are likely to cause problems.
  static const Severity error = const Severity._('error', 3);

  /// Warning events might cause problems.
  static const Severity warning = const Severity._('warning', 4);

  /// Normal but significant events; start up, shut down, or configuration.
  static const Severity notice = const Severity._('notice', 5);

  /// Routine information, such as ongoing status or performance.
  static const Severity info = const Severity._('info', 6);

  /// Debug or trace information.
  static const Severity debug = const Severity._('debug', 7);

  static const List<Severity> values = const [
    emergency,
    alert,
    critical,
    error,
    warning,
    notice,
    info,
    debug,
  ];

  const Severity._(this.name, this.index);

  /// Name of the enum.
  final String name;

  /// Location of the enum in [Severity.values].
  final int index;

  @override
  int compareTo(Severity other) {
    assert(other != null);
    return other.index.compareTo(index);
  }

  @override
  String toString() => name;
}

/// Unique key used for [Logger.scope].
final Object _zoneKey = new Object();
Logger<Object> _defaultLogger;

/// Returns the currently scoped logger, or a default one otherwise.
Logger get _currentLogger {
  // TODO(https://github.com/dart-lang/sdk/issues/31169)
  // ... then rewrite as a simple lambda getter.
  final Logger current = Zone.current[_zoneKey];
  return current ??
      (_defaultLogger ??= new Logger(
        severity: Severity.values[const int.fromEnvironment(
            'CABLE_DEFAULT_SEVERITY',
            defaultValue: 7 /* Keep in sync with Severity.debug.index. */)],
      ));
}

/// Logs a [message] to the current logger.
///
/// If [severity] is less than the configured severity, nothing is logged.
///
/// See [Logger.log] for additional details.
void log(Object message, {Severity severity: Severity.info}) {
  _currentLogger.log(message, severity: severity);
}

/// Logs the result of [generate] to the current logger.
///
/// If [severity] is less than the configured severity, [generate] is not
/// invoked and nothing is logged.
///
/// See [Logger.logLazy] for additional details.
void logLazy(Object Function() generate, {Severity severity: Severity.info}) {
  _currentLogger.logLazy(generate, severity: severity);
}

/// Default implementation of `timestamp` for `new Logger`.
DateTime _defaultTimestamp() => new DateTime.now();

/// Default implementation of `formatter` for `new Logger`.
///
/// It assumes that the value of [Object.toString].
String _defaultFormatter(Record<Object> record) {
  final timestamp = record.timestamp;
  final timeFormat = new StringBuffer()
    ..write(timestamp.hour)
    ..write(':')
    ..write(timestamp.minute)
    ..write(':')
    ..write(timestamp.second)
    ..write(':')
    ..write(timestamp.millisecond);
  final name = record.origin;
  return '[${record.severity} @ $timeFormat] $name: ${record.payload}';
}

/// Common and simple implementations of [Sink<Record>].
///
/// Do not extend, implement, or mix-in this class. Use [Sink<Record>].
abstract class LogSink implements Sink<Record> {
  /// A no-op implementation of [Sink<Record>].
  static const Sink<Record> nullSink = const _NullSink();

  /// Writes the result of [Record.toFormattedString] to [print].
  static const Sink<Record> printSink = const _PrintSink();

  /// Create a sink that emits [Record.toFormattedString] to a [Sink<String>].
  const factory LogSink.writeToSink(Sink<String> sink) = _SinkSink;

  /// Create a sink that emits [Record.toFormattedString] to a [StringSink].
  const factory LogSink.writeToBuffer(StringSink sink) = _BufferSink;

  const LogSink._();

  @override
  void close() {}
}

class _NullSink extends LogSink {
  const _NullSink() : super._();

  @override
  void add(_) {}
}

class _PrintSink extends LogSink {
  const _PrintSink() : super._();

  @override
  void add(Record data) => Zone.current.print(data.toFormattedString());

  @override
  void close() {}
}

class _SinkSink implements LogSink {
  final Sink<String> _sink;

  const _SinkSink(this._sink);

  @override
  void add(Record data) => _sink.add(data.toFormattedString());

  @override
  void close() => _sink.close();
}

class _BufferSink extends LogSink {
  final StringSink _sink;

  const _BufferSink(this._sink) : super._();

  @override
  void add(Record data) => _sink.writeln(data.toFormattedString());
}

/// A class for writing messages to one more destinations.
///
/// [Logger] is the core component of the `cable` package
///
/// It is not supported to extend, implement, or mix-in this class.
@immutable
class Logger<T extends Object> {
  /// Used in debug mode to throw assertions after [close] is invoked.
  static final _closed = new Expando<bool>();

  final String _name;
  final String Function(Record<T>) _format;
  final Logger _parent;
  final Severity _severity;
  final List<Sink<Record>> _sinks;
  final DateTime Function() _timestamp;

  /// Returns a child of the current scoped [Logger].
  static Logger<T> fork<T>({
    List<LogSink> destinations: const [],
    String name,
    String Function(Record<T>) formatter: _defaultFormatter,
    Severity severity,
  }) {
    return _currentLogger.createChild<T>(
      destinations: destinations,
      name: name,
      formatter: formatter,
      severity: severity,
    );
  }

  /// Creates a new logger.
  const factory Logger({
    List<Sink<Record>> destinations,
    String name,
    String Function(Record<T>) formatter,
    Severity severity,
    DateTime Function() timestamp,
  }) = Logger<T>._;

  @literal
  const Logger._({
    List<Sink<Record>> destinations: const [LogSink.printSink],
    String Function(Record<T>) formatter: _defaultFormatter,
    Logger parent,
    String name,
    Severity severity: Severity.info,
    DateTime Function() timestamp: _defaultTimestamp,
  })
      : _name = name,
        _format = formatter,
        _parent = parent,
        _severity = severity,
        _sinks = destinations,
        _timestamp = timestamp;

  /// Closes all destinations configured for this [Logger].
  ///
  /// In debug mode (i.e. when `assert` is enabled), it is an [AssertionError]
  /// to attempt to log additional messages after this point.
  void close() {
    assert(_closed[this] = true);
    for (final sink in _sinks) {
      sink.close();
    }
  }

  /// Whether this logger is considered closed.
  bool get _isClosed => _closed[this] == true;

  /// Creates a new logger as a _child_ of this logger.
  ///
  /// Child loggers automatically propagate messages upwards, that is, a root
  /// logger will receive _all_ messages from their entire transitive tree of
  /// children.
  ///
  /// This method is useful to create isolated [Logger] instances with different
  /// default logging levels, formatting, or additional destinations to process.
  @factory
  Logger<E> createChild<E extends T>({
    List<Sink<Record>> destinations: const [],
    String name,
    String Function(Record<E>) formatter: _defaultFormatter,
    Severity severity,
  }) {
    assert(destinations != null);
    return new Logger<E>._(
      destinations: destinations,
      name: name ?? _name,
      formatter: formatter,
      parent: this,
      severity: severity ?? _severity,
      timestamp: _timestamp,
    );
  }

  void _logActual(T message, {Severity severity}) {
    assert(!_isClosed, 'Cannot log to a closed Logger');
    assert(message != null, 'Message must not be null');
    assert(severity != null);
    assert(severity.index <= _severity.index);
    _logRecord(new Record<T>._(
      formatter: _format,
      origin: _name,
      payload: message,
      severity: severity,
      timestamp: _timestamp(),
    ));
  }

  void _logRecord(Record record) {
    for (final sink in _sinks) {
      sink.add(record);
    }
    _parent?._logRecord(record);
  }

  /// Invokes [message] to [log] to the current logger.
  ///
  /// If [severity] is less than the configured severity, nothing is logged.
  /// ```dart
  /// new Logger(severity: Level.warn)
  ///   ..logLazy(() => 'S.O.S.', severity: Level.error)  // Logged.
  ///   ..logLazy(() => 'Uh oh', severity: Level.warn)    // Logged.
  ///   ..logLazy(() => 'Ho Hum', severity: Level.info)   // NOT logged.
  /// ```
  void log(
    T message, {
    Severity severity: Severity.info,
  }) {
    assert(message != null, 'Message must not be null');
    if (severity != null && severity.index > _severity.index) {
      return;
    }
    _logActual(message, severity: severity ?? _severity);
  }

  /// Logs the result of [generate] to the current logger.
  ///
  /// If [severity] is less than the configured severity, [generate] is not
  /// invoked and nothing is logged:
  /// ```dart
  /// new Logger(severity: Level.warn)
  ///   ..logLazy(() => 'S.O.S.', severity: Level.error)  // Logged.
  ///   ..logLazy(() => 'Uh oh', severity: Level.warn)    // Logged.
  ///   ..logLazy(() => 'Ho Hum', severity: Level.info)   // NOT logged.
  /// ```
  void logLazy(T Function() generate, {Severity severity: Severity.info}) {
    assert(severity != null);
    assert(generate != null);
    if (severity.index > _severity.index) {
      return;
    }
    _logActual(generate(), severity: severity);
  }

  // TODO(https://github.com/dart-lang/linter/issues/805).
  // ignore: non_constant_identifier_names
  T scope<T>(T Function() run) {
    assert(run != null);
    return runZoned(run, zoneValues: <Object, Logger>{
      _zoneKey: this,
    });
  }
}

/// Represents details of a logged message to a [Logger].
@immutable
class Record<T> {
  final String Function(Record<T>) _formatter;
  final String origin;
  final T payload;
  final Severity severity;
  final DateTime timestamp;

  @literal
  const Record._({
    @required String Function(Record<T>) formatter,
    @required this.origin,
    @required this.payload,
    @required this.severity,
    @required this.timestamp,
  })
      : _formatter = formatter;

  /// Returns the result of running a string formatter on this record.
  ///
  /// For destinations that can only handle simple string/text logging, this is
  /// an appropriate output. More specialized destinations may want to log the
  /// fields of [Record] and [payload] more specifically.
  String toFormattedString() => _formatter(this);
}
