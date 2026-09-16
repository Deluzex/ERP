/// Strongly-typed exception for ERP API errors
class ApiException implements Exception {
  final int? statusCode;
  final String errorCode;
  final String message;
  final List<String> validationErrors;
  final String? correlationId;

  const ApiException({
    this.statusCode,
    required this.errorCode,
    required this.message,
    this.validationErrors = const [],
    this.correlationId,
  });

  @override
  String toString() {
    if (validationErrors.isNotEmpty) {
      return '$message: ${validationErrors.join(", ")}';
    }
    return message;
  }
}

class UnauthorizedException extends ApiException {
  const UnauthorizedException({
    super.message = 'Session expired or invalid credentials. Please log in again.',
    super.correlationId,
  }) : super(
          statusCode: 401,
          errorCode: 'UNAUTHORIZED',
        );
}

class ForbiddenException extends ApiException {
  const ForbiddenException({
    super.message = 'You do not have permission to perform this action.',
    super.correlationId,
  }) : super(
          statusCode: 403,
          errorCode: 'FORBIDDEN',
        );
}

class ConflictException extends ApiException {
  const ConflictException({
    required super.message,
    super.correlationId,
  }) : super(
          statusCode: 409,
          errorCode: 'CONFLICT',
        );
}

class NotFoundException extends ApiException {
  const NotFoundException({
    required super.message,
    super.correlationId,
  }) : super(
          statusCode: 404,
          errorCode: 'NOT_FOUND',
        );
}
