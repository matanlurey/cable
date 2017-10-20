# cable

<p align="center">
  An extensible and simple logging framework.
  <br>
  <a href="https://travis-ci.org/matanlurey/cable">
    <img src="https://travis-ci.org/matanlurey/cable.svg?branch=master" alt="Build Status" />
  </a>
  <a href="https://pub.dartlang.org/packages/cable">
    <img src="https://img.shields.io/pub/v/cable.svg" alt="Pub Package Version" />
  </a>
  <a href="https://www.dartdocs.org/documentation/cable/latest">
    <img src="https://img.shields.io/badge/dartdocs-latest-blue.svg" alt="Latest Dartdocs" />
  </a>
</p>

The `cable` package provides a re-usable interface for logging and defining
custom logging _destinations_, such as file I/O, remote web services, and more.

* [Installation](#installation)
* [Usage](#usage)
  * [Getting started](#getting-started)
  * [Creating a logger](#creating-a-logger)
  * [Override functions](#override-functions)
* [Contributing](#contributing)
  * [Testing](#testing)

## Installation

Add `cable` as under `dependencies` in your [`pubspec.yaml`][pubspec] file:

```yaml
dependencies:
  cable: ^0.1.0
```

And that's it! See [usage](#usage) for details.

## Usage

### Getting started

Out of the box `cable` provides two top-level methods, `log` and `logLazy`.

For simple string messages, use `log`:

```dart
void main() {
  log('Hello World!');
}
```

And for more complex messages that will need to be computed, use `logLazy`:

```dart
void main() {
  logLazy(() => 'The 100th digit of PI is ${computePiDigits(100)}');
}
```

Depending on the severity level, the closure for `logLazy` may not be invoked.

Both of these methods are intended to be for simpler use cases, with drawbacks:
* They just `print` string-like objects to console.
* The default severity is `Severity.debug` (all messages).
* They don't (immediately) support custom formatting, destinations, severity.

> **HINT**: Define a default `Severity` using Dart declaration variables.
>
> In the VM, set `CABLE_DEFAULT_SEVERITY` to `4`, or `Severity.warning`.
>
> ```bash
> $ dart bin/app.dart -dCABLE_DEFAULT_SEVERITY=4
> ```
>
> [Read more][declaration_variables] about Dart declaration variables.

[pubspec]: https://www.dartlang.org/tools/pub/pubspec
[declaration_variables]: https://api.dartlang.org/stable/latest/dart-core/String/String.fromEnvironment.html

### Creating a logger

A `Logger` class can be created and used for dependency injection:

```dart
void main() {
  final logger = new Logger();
  final service = new Service(logger: logger);
  // ...
}
```

You can also set the severity threshold:

```dart
void main() {
  final logger = new Logger(
    severity: Severity.warning,
  );
}
```

Or define a simple string formatter:

```dart
void main() {
  final logger = new Logger(
    // Writes string logs in the format of {name}: {message}.
    formatter: (record) => '${record.origin}: ${record.payload}',
  );
}
```

By default, a `Logger` just prints to the console. You can also configure one:

#### Custom destination(s)

> **NOTE**: This package intentionally is sparse on opinions or specific
> destinations in order to reduce your transitive dependencies to an absolute
> minimum. We encourage you to write and contribute to `cable_*` packages that
> provide interesting destinations/endpoints for `cable`!

```dart
void main() {
  final logger = new Logger(
   destinations: [
     // Any class that implements Sink<Record>
   ],
 );
}
```

Several built-in classes are available cross platform:

```dart
void main() {
  final logger = new Logger(
   destinations: [
     // Does nothing.
     LogSink.nullSink,
     
     // Prints to console.
     LogSink.printSink,
     
     // Use any Sink<String> instance, such as a `StreamController`.
     new LogSink.writeToSink(someEventController),
     
     // Use any StringSink instance, such as a `StringBuffer`.
     new LogSink.writeToBuffer(stringBuffer),
   ],
  );
}
```

It's also easy to create your own plugin packages!

```dart
class FileSink implements Sink<Record> {
  @override
  void add(Record data) { /* Write to a file. */ }

  @override
  void close() { /* Close the file stream. */ }
}

void main() {
  final logger = new Logger(
    destinations: [new FileSink(/*...*/)],
  );
}
```

### Override Functions

It's possible to replace `log` and `logLazy` to forward to your own configured
`Logger` instance at runtime - use `scope`:

```dart
void runLogged(Logger logger) {
  logger.scope(() => startApplication());
}
```

Using [zones][], any calls to `log` or `logLazy` inside of context of
`startApplication()` will now use your custom `logger` class, not the default
top-level function behavior.

[zones]: https://www.dartlang.org/articles/libraries/zones

## Contributing

We welcome a diverse set of contributions, including, but not limited to:

* [Filing bugs and feature requests][file_an_issue]
* [Send a pull request][pull_request]
* Or, create something awesome using this API and share with us and others!

For the stability of the API and existing users, consider opening an issue
first before implementing a large new feature or breaking an API. For smaller
changes (like documentation, minor bug fixes), just send a pull request.

### Testing

All pull requests are validated against [travis][travis], and must pass. The
`build_runner` package lives in a mono repository with other `build` packages,
and _all_ of the following checks must pass for _each_ package.

Ensure code passes all our [analyzer checks][analysis_options]:

```sh
$ dartanalyzer .
```

Ensure all code is formatted with the latest [dev-channel SDK][dev_sdk].

```sh
$ dartfmt -w .
```

Run all of our unit tests:

```sh
$ pub run test
```

[analysis_options]: analysis_options.yaml
[travis]: https://travis-ci.org/
[dev_sdk]: https://www.dartlang.org/install]
[file_an_issue]: https://github.com/matanlurey/cable/issues/new
[pull_request]: https://github.com/matanlurey/cable/pulls
