import { DomainError } from './domain-error';

export class UnauthorizedError extends DomainError {
  readonly code = 'UNAUTHENTICATED';
  readonly statusCode = 401;

  constructor(message: string = 'Authentication required') {
    super(message);
  }
}
