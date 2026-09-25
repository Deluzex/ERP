import { DomainError } from './domain-error';

export class NotFoundError extends DomainError {
  readonly code = 'NOT_FOUND';
  readonly statusCode = 404;

  constructor(resource: string, identifier?: string) {
    super(identifier ? `${resource} with identifier '${identifier}' was not found` : `${resource} not found`);
  }
}
