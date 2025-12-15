class ValidationException implements Exception {
  final String message;
  final Map<String, dynamic> errors;

  ValidationException(this.message, this.errors);

  @override
  String toString() {
    return 'ValidationException: $message';
  }
}
