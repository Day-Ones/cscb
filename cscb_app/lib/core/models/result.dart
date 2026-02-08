/// Standardized result type for repository operations
class Result<T> {
  final bool success;
  final String? errorMessage;
  final T? data;

  Result.success([this.data])
      : success = true,
        errorMessage = null;

  Result.failure(this.errorMessage)
      : success = false,
        data = null;
}
