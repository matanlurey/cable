// Copyright 2017, Google Inc.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:cable/cable.dart';
import 'package:test/test.dart';

void main() {
  group('Top-level method', () {
    group('log', () {
      test('should log to the default logger', () {
        expect(capturePrint(() => log('Hello')), [endsWith('Hello')]);
      });

      test('should delegate to a new scoped logger', () {
        final buffer = <String>[];
        new Logger(
          destinations: [new ListSink(buffer)],
          formatter: simpleFormat,
        ).scope(() {
          log('Hello');
        });
        expect(buffer, ['Hello']);
      });
    });

    group('logLazy', () {
      test('should log to the default logger', () {
        expect(capturePrint(() => logLazy(() => 'Hello')), [endsWith('Hello')]);
      });

      test('should delegate to a new scoped logger', () {
        final buffer = <String>[];
        new Logger(
          destinations: [new ListSink(buffer)],
          formatter: simpleFormat,
        ).scope(() {
          logLazy(() => 'Hello');
        });
        expect(buffer, ['Hello']);
      });

      test('should not invoke the function on low severity', () {
        final buffer = <String>[];
        new Logger(
          destinations: [new ListSink(buffer)],
          severity: Severity.warning,
        ).scope(() {
          // ignore: only_throw_errors
          logLazy(() => throw 'Should never be invoked!');
        });
        expect(buffer, isEmpty);
      });
    });
  });

  test('createChild should propagate upwards', () {
    final buffer = <String>[];
    final logger = new Logger(destinations: [
      new ListSink(buffer),
    ], formatter: simpleFormat);
    logger.createChild(name: 'child').log('Hello World');
    expect(buffer, [
      endsWith('child: Hello World'),
    ]);
  });

  test('timestamp should override the default', () {
    final buffer = <String>[];
    new Logger(
      destinations: [new ListSink(buffer)],
      timestamp: () => new DateTime.utc(2017),
    ).log('Hello World', severity: Severity.warning);
    expect(buffer, [
      '[warning @ 0:0:0] Hello World',
    ]);
  });
}

/// Simply returns [Record.payload] with `toString()`.
String simpleFormat(Record record) => record.payload.toString();

/// Writes to an existing [List<String>].
class ListSink implements Sink<Record> {
  final List<String> _list;

  const ListSink(this._list);

  @override
  void add(Record data) => _list.add(data.toFormattedString());

  @override
  void close() {}
}

/// Returns a result of all [print] statements in [run].
List<String> capturePrint(void Function() run) {
  final buffer = <String>[];
  runZoned(
    run,
    zoneSpecification: new ZoneSpecification(
      print: (_, __, ___, message) => buffer.add(message),
    ),
  );
  return buffer;
}
