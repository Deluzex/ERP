import { CallHandler, ExecutionContext, Injectable, NestInterceptor } from '@nestjs/common';
import { Request } from 'express';
import { Observable } from 'rxjs';
import { map } from 'rxjs/operators';

export interface ResponseEnvelope<T> {
  data: T;
  meta: {
    correlationId: string;
    pagination?: {
      page: number;
      pageSize: number;
      totalItems: number;
      totalPages: number;
    };
  };
}

@Injectable()
export class ResponseEnvelopeInterceptor<T> implements NestInterceptor<T, ResponseEnvelope<T> | T> {
  intercept(context: ExecutionContext, next: CallHandler): Observable<ResponseEnvelope<T> | T> {
    const request = context.switchToHttp().getRequest<Request>();
    const correlationId = (request.headers['x-correlation-id'] as string) || 'unknown';

    return next.handle().pipe(
      map((result) => {
        // If the result is already enveloped or null/undefined or a raw stream/buffer, return as-is
        if (!result && result !== null) {
          return result;
        }

        // Check if result is a PaginatedResult with data and meta
        if (result && typeof result === 'object' && 'data' in result && 'meta' in result && result.meta?.page !== undefined) {
          return {
            data: result.data,
            meta: {
              correlationId,
              pagination: result.meta,
            },
          };
        }

        // Standard single or collection resource
        return {
          data: result,
          meta: {
            correlationId,
          },
        };
      }),
    );
  }
}
