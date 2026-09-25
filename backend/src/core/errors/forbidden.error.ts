import { DomainError } from './domain-error';

export class ForbiddenError extends DomainError {
  readonly code = 'PERMISSION_DENIED';
  readonly statusCode = 403;

  constructor(permissionOrMessage: string) {
    super(permissionOrMessage.startsWith('Missing') || permissionOrMessage.includes(' ')
      ? permissionOrMessage
      : `Missing required permission: ${permissionOrMessage}`);
  }
}

export class BranchOutOfScopeError extends DomainError {
  readonly code = 'BRANCH_OUT_OF_SCOPE';
  readonly statusCode = 403;

  constructor(branchId: string) {
    super(`Branch '${branchId}' is outside your authorized branch scope`);
  }
}

export class StockLocationOutOfScopeError extends DomainError {
  readonly code = 'STOCK_LOCATION_OUT_OF_SCOPE';
  readonly statusCode = 403;

  constructor(locationId: string) {
    super(`Stock location '${locationId}' is outside your authorized stock scope`);
  }
}
