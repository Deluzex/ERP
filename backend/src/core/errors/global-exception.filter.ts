import { ArgumentsHost, Catch, ExceptionFilter, HttpException, HttpStatus } from '@nestjs/common';
import { Request, Response } from 'express';
import { DomainError } from './domain-error';
import { ValidationError } from './validation.error';

@Catch()
export class GlobalExceptionFilter implements ExceptionFilter {
  catch(exception: unknown, host: ArgumentsHost): void {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();

    const correlationId = (request.headers['x-correlation-id'] as string) || 'unknown';

    let status = HttpStatus.INTERNAL_SERVER_ERROR;
    let code = 'INTERNAL_SERVER_ERROR';
    let message = 'An unexpected internal error occurred';
    let details: Record<string, unknown> | undefined = undefined;

    if (exception instanceof DomainError) {
      status = exception.statusCode;
      code = exception.code;
      message = exception.message;
      if (exception instanceof ValidationError && exception.details) {
        details = exception.details;
      }
    } else if (exception instanceof HttpException) {
      status = exception.getStatus();
      const res = exception.getResponse();
      if (typeof res === 'string') {
        message = res;
        code = exception.name.toUpperCase();
      } else if (typeof res === 'object' && res !== null) {
        const resObj = res as Record<string, unknown>;
        message = (resObj['message'] as string) || exception.message;
        code = (resObj['error'] as string) || exception.name.toUpperCase();
        if (Array.isArray(resObj['message'])) {
          message = 'Validation failed';
          code = 'VALIDATION_FAILED';
          details = { validationErrors: resObj['message'] };
        }
      }
    } else if (exception instanceof Error) {
      // Unhandled application errors - log internally, hide internal details from client
      // Never expose SQL or driver messages (SECURITY_RULES.md §8)
      message = process.env.NODE_ENV === 'development' ? exception.message : 'An unexpected error occurred';
    }

    response.status(status).json({
      error: {
        code,
        message,
        ...(details ? { details } : {}),
        correlationId,
      },
    });
  }
}
