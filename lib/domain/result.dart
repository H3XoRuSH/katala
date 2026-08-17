/// Sealed Result type for functional error handling without throwing exceptions.
sealed class Result<T, E> {
  const Result();

  /// Convenience factory for [Success].
  const factory Result.success(T value) = Success<T, E>;

  /// Convenience factory for [Failure].
  const factory Result.failure(E error) = Failure<T, E>;

  /// Returns true if this instance represents a [Success].
  bool get isSuccess => this is Success<T, E>;

  /// Returns true if this instance represents a [Failure].
  bool get isFailure => this is Failure<T, E>;

  /// Returns the successful value, or null if this is a failure.
  T? get valueOrNull => isSuccess ? (this as Success<T, E>).value : null;

  /// Returns the error value, or null if this is a success.
  E? get errorOrNull => isFailure ? (this as Failure<T, E>).error : null;

  /// Maps the success value using [transform].
  Result<R, E> map<R>(R Function(T value) transform) {
    if (this is Success<T, E>) {
      return Success(transform((this as Success<T, E>).value));
    } else {
      return Failure((this as Failure<T, E>).error);
    }
  }

  /// Pattern matching handler.
  R when<R>({
    required R Function(T value) success,
    required R Function(E error) failure,
  }) {
    if (this is Success<T, E>) {
      return success((this as Success<T, E>).value);
    } else if (this is Failure<T, E>) {
      return failure((this as Failure<T, E>).error);
    }
    throw StateError('Unknown Result subclass: $runtimeType');
  }
}

/// Represents a successful computation.
class Success<T, E> extends Result<T, E> {
  final T value;
  const Success(this.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Success<T, E> && runtimeType == other.runtimeType && value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'Result.success($value)';
}

/// Represents a failed computation.
class Failure<T, E> extends Result<T, E> {
  final E error;
  const Failure(this.error);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Failure<T, E> && runtimeType == other.runtimeType && error == other.error;

  @override
  int get hashCode => error.hashCode;

  @override
  String toString() => 'Result.failure($error)';
}
