/// A lightweight, dependency-free union type used to model the three states
/// every asynchronous repository call can be in: **loading**, **data**, or
/// **error**.
///
/// This complements Riverpod's `AsyncValue` (see the design's "shared
/// `Result<T>` / `AsyncValue` pattern"). `AsyncValue` is the right tool inside
/// the presentation layer where Riverpod is already in scope, while [Result]
/// is a pure Dart type that can be used anywhere — domain services, repository
/// boundaries, isolates, or tests — without coupling those layers to Riverpod.
///
/// The UI can render any [Result] uniformly via [when]:
///
/// ```dart
/// final result = await SomeRepo.fetch();
/// return result.when(
///   loading: () => const KShimmer(),
///   data: (services) => ServiceGrid(services: services),
///   error: (error, _) => KErrorView(message: '$error', onRetry: retry),
/// );
/// ```
library;

import 'dart:async';

/// A sealed union representing the loading / data / error state of a value of
/// type [T].
///
/// Being `sealed` means the Dart analyzer enforces exhaustive handling in
/// `switch` expressions and in the [when] helper, so a new variant can never be
/// silently ignored at a call site.
sealed class Result<T> {
  const Result();

  /// Creates a [Result] in the loading state.
  const factory Result.loading() = ResultLoading<T>;

  /// Creates a [Result] carrying a successfully loaded [value].
  const factory Result.data(T value) = ResultData<T>;

  /// Creates a [Result] carrying an [error] and an optional [stackTrace].
  const factory Result.error(Object error, [StackTrace? stackTrace]) =
      ResultError<T>;

  /// Runs [body] and captures the outcome as a [Result].
  ///
  /// A returned value becomes [ResultData]; a thrown error (with its stack
  /// trace) becomes [ResultError]. This is the synchronous companion to
  /// [guard].
  static Result<T> run<T>(T Function() body) {
    try {
      return ResultData<T>(body());
    } catch (error, stackTrace) {
      return ResultError<T>(error, stackTrace);
    }
  }

  /// Awaits [future] and captures the outcome as a [Result].
  ///
  /// A completed value becomes [ResultData]; a thrown error (with its stack
  /// trace) becomes [ResultError]. Useful for wrapping repository calls so the
  /// UI never has to deal with raw exceptions.
  static Future<Result<T>> guard<T>(Future<T> Function() future) async {
    try {
      return ResultData<T>(await future());
    } catch (error, stackTrace) {
      return ResultError<T>(error, stackTrace);
    }
  }

  /// Whether this result is in the loading state.
  bool get isLoading => this is ResultLoading<T>;

  /// Whether this result holds data.
  bool get isData => this is ResultData<T>;

  /// Whether this result holds an error.
  bool get isError => this is ResultError<T>;

  /// The contained value, or `null` if this is not a [ResultData].
  T? get valueOrNull {
    final self = this;
    return self is ResultData<T> ? self.value : null;
  }

  /// The contained error, or `null` if this is not a [ResultError].
  Object? get errorOrNull {
    final self = this;
    return self is ResultError<T> ? self.error : null;
  }

  /// Exhaustively maps each state to a value of type [R].
  ///
  /// All three branches are required, which guarantees the UI renders every
  /// state explicitly.
  R when<R>({
    required R Function() loading,
    required R Function(T value) data,
    required R Function(Object error, StackTrace? stackTrace) error,
  }) {
    final self = this;
    return switch (self) {
      ResultLoading<T>() => loading(),
      ResultData<T>(value: final v) => data(v),
      ResultError<T>(error: final e, stackTrace: final st) => error(e, st),
    };
  }

  /// Like [when] but every branch is optional, falling back to [orElse] for any
  /// state that is not explicitly handled.
  R maybeWhen<R>({
    R Function()? loading,
    R Function(T value)? data,
    R Function(Object error, StackTrace? stackTrace)? error,
    required R Function() orElse,
  }) {
    final self = this;
    return switch (self) {
      ResultLoading<T>() => loading != null ? loading() : orElse(),
      ResultData<T>(value: final v) => data != null ? data(v) : orElse(),
      ResultError<T>(error: final e, stackTrace: final st) =>
        error != null ? error(e, st) : orElse(),
    };
  }

  /// Transforms a [ResultData]'s value with [transform], preserving the
  /// loading and error states unchanged.
  ///
  /// If [transform] throws, the result becomes a [ResultError].
  Result<R> map<R>(R Function(T value) transform) {
    final self = this;
    return switch (self) {
      ResultLoading<T>() => ResultLoading<R>(),
      ResultError<T>(error: final e, stackTrace: final st) =>
        ResultError<R>(e, st),
      ResultData<T>(value: final v) => Result.run<R>(() => transform(v)),
    };
  }
}

/// The loading variant of [Result].
final class ResultLoading<T> extends Result<T> {
  /// Creates a loading result.
  const ResultLoading();

  @override
  bool operator ==(Object other) => other is ResultLoading<T>;

  @override
  int get hashCode => Object.hash(runtimeType, T);

  @override
  String toString() => 'Result<$T>.loading()';
}

/// The data variant of [Result], carrying a successfully loaded [value].
final class ResultData<T> extends Result<T> {
  /// Creates a data result wrapping [value].
  const ResultData(this.value);

  /// The successfully loaded value.
  final T value;

  @override
  bool operator ==(Object other) =>
      other is ResultData<T> && other.value == value;

  @override
  int get hashCode => Object.hash(runtimeType, value);

  @override
  String toString() => 'Result<$T>.data($value)';
}

/// The error variant of [Result], carrying an [error] and optional
/// [stackTrace].
final class ResultError<T> extends Result<T> {
  /// Creates an error result wrapping [error] and an optional [stackTrace].
  const ResultError(this.error, [this.stackTrace]);

  /// The captured error object.
  final Object error;

  /// The stack trace associated with [error], if one was available.
  final StackTrace? stackTrace;

  @override
  bool operator ==(Object other) =>
      other is ResultError<T> &&
      other.error == error &&
      other.stackTrace == stackTrace;

  @override
  int get hashCode => Object.hash(runtimeType, error, stackTrace);

  @override
  String toString() => 'Result<$T>.error($error)';
}
