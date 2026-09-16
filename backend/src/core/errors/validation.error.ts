import { DomainError } from './domain-error';

export class ValidationError extends DomainError {
  readonly code = 'VALIDATION_FAILED';
  readonly statusCode = 422;
  readonly details?: Record<string, string[]>;

  constructor(message: string, details?: Record<string, string[]>) {
    super(message);
    this.details = details;
  }
}
