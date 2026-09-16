import { Injectable } from '@nestjs/common';
import { BranchOutOfScopeError, StockLocationOutOfScopeError } from '../errors/forbidden.error';
import { RequestContext } from './request-context';

@Injectable()
export class ScopeValidator {
  assertBranchInScope(branchId: string, ctx: RequestContext): void {
    // Admin has organization-wide scope
    if (ctx.roleId === 'admin') {
      return;
    }
    if (!ctx.branchIds.includes(branchId)) {
      throw new BranchOutOfScopeError(branchId);
    }
  }

  assertLocationInScope(locationId: string, ctx: RequestContext): void {
    // Admin has organization-wide scope
    if (ctx.roleId === 'admin') {
      return;
    }
    if (!ctx.stockLocationIds.includes(locationId)) {
      throw new StockLocationOutOfScopeError(locationId);
    }
  }
}
