import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'api_config.dart';
import 'api_exception.dart';
import 'token_storage.dart';

/// Centralized HTTP API Client for NestJS ERP Backend
class ApiClient {
  static final ApiClient instance = ApiClient._internal();

  late final Dio dio;
  late final Dio _refreshDio;

  ApiClient._internal() {
    final baseOptions = BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: ApiConfig.connectTimeout,
      receiveTimeout: ApiConfig.receiveTimeout,
      sendTimeout: ApiConfig.sendTimeout,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    );

    dio = Dio(baseOptions);
    _refreshDio = Dio(baseOptions); // Standalone instance without interceptors for refresh

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = TokenStorage.instance.accessToken;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          // Generate or preserve Correlation ID
          if (!options.headers.containsKey('X-Correlation-ID')) {
            final cid = 'flt_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
            options.headers['X-Correlation-ID'] = cid;
          }

          if (kDebugMode) {
            debugPrint('[HTTP REQ] ${options.method} ${options.baseUrl}${options.path}');
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          if (kDebugMode) {
            debugPrint('[HTTP RES ${response.statusCode}] ${response.requestOptions.path}');
          }
          return handler.next(response);
        },
        onError: (DioException error, handler) async {
          if (kDebugMode) {
            debugPrint('[HTTP ERR ${error.response?.statusCode}] ${error.requestOptions.path} : ${error.message}');
          }

          // Automatic 401 Token Refresh Rotation
          if (error.response?.statusCode == 401) {
            final refreshToken = TokenStorage.instance.refreshToken;
            final isLoginOrRefresh = error.requestOptions.path.contains('/auth/login') ||
                error.requestOptions.path.contains('/auth/refresh');

            if (refreshToken != null && !isLoginOrRefresh) {
              try {
                final refreshRes = await _refreshDio.post('/auth/refresh', data: {
                  'refreshToken': refreshToken,
                });

                final resData = refreshRes.data;
                final dataObj = (resData is Map && resData.containsKey('data')) ? resData['data'] : resData;

                final newAccessToken = dataObj['accessToken'] as String?;
                final newRefreshToken = dataObj['refreshToken'] as String?;

                if (newAccessToken != null) {
                  TokenStorage.instance.saveTokens(
                    accessToken: newAccessToken,
                    refreshToken: newRefreshToken ?? refreshToken,
                  );

                  // Retry original failed request with new token
                  final originalOptions = error.requestOptions;
                  originalOptions.headers['Authorization'] = 'Bearer $newAccessToken';

                  final cloneRes = await dio.fetch(originalOptions);
                  return handler.resolve(cloneRes);
                }
              } catch (_) {
                TokenStorage.instance.clear();
              }
            }
          }

          return handler.reject(error);
        },
      ),
    );
  }

  /// Unwraps standard backend { data: T, meta: { ... } } responses
  T unwrap<T>(Response response) {
    final raw = response.data;
    if (raw is Map<String, dynamic> && raw.containsKey('data')) {
      return raw['data'] as T;
    }
    return raw as T;
  }

  /// Translates DioException into strongly typed domain ApiException
  ApiException handleDioError(dynamic error) {
    if (error is ApiException) return error;

    if (error is DioException) {
      final statusCode = error.response?.statusCode;
      final responseData = error.response?.data;

      String message = 'A network error occurred. Please check your connection.';
      String code = 'NETWORK_ERROR';
      List<String> validationErrors = [];
      String? correlationId;

      if (responseData is Map<String, dynamic>) {
        if (responseData.containsKey('error') && responseData['error'] is Map) {
          final errObj = responseData['error'] as Map<String, dynamic>;
          code = errObj['code']?.toString() ?? 'API_ERROR';
          message = errObj['message']?.toString() ?? message;
          correlationId = errObj['correlationId']?.toString();

          if (errObj['details'] is Map && errObj['details']['validationErrors'] is List) {
            validationErrors = List<String>.from(errObj['details']['validationErrors']);
          }
        } else if (responseData.containsKey('message')) {
          if (responseData['message'] is List) {
            validationErrors = List<String>.from(responseData['message']);
            message = 'Validation failed';
          } else {
            message = responseData['message'].toString();
          }
        }
      } else if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        message = 'Connection timed out. Please try again.';
        code = 'TIMEOUT';
      }

      switch (statusCode) {
        case 401:
          return UnauthorizedException(message: message, correlationId: correlationId);
        case 403:
          return ForbiddenException(message: message, correlationId: correlationId);
        case 404:
          return NotFoundException(message: message, correlationId: correlationId);
        case 409:
          return ConflictException(message: message, correlationId: correlationId);
        default:
          return ApiException(
            statusCode: statusCode,
            errorCode: code,
            message: message,
            validationErrors: validationErrors,
            correlationId: correlationId,
          );
      }
    }

    return ApiException(
      errorCode: 'UNKNOWN_ERROR',
      message: error?.toString() ?? 'An unexpected error occurred',
    );
  }
}
