import {
  BranchOutOfScopeError,
  StockLocationOutOfScopeError,
} from '../errors/forbidden.error';
import { RequestContext } from './request-context';
import { ScopeValidator } from './scope.guard';

describe('ScopeValidator', () => {
  let validator: ScopeValidator;

  beforeEach(() => {
    validator = new ScopeValidator();
  });

  const createContext = (
    roleId: string,
    branchIds: string[],
    stockLocationIds: string[],
  ): RequestContext => ({
    userId: 'user-1',
    userName: 'Test User',
    roleId,
    branchIds,
    stockLocationIds,
    permissions: new Set(),
    correlationId: 'test-cid',
  });

  describe('assertBranchInScope', () => {
    it('should allow admin access to any branch', () => {
      const ctx = createContext('admin', [], []);
      expect(() => validator.assertBranchInScope('branch-999', ctx)).not.toThrow();
    });

    it('should allow user access to assigned branch', () => {
      const ctx = createContext('manager', ['branch-1', 'branch-2'], []);
      expect(() => validator.assertBranchInScope('branch-1', ctx)).not.toThrow();
    });

    it('should throw BranchOutOfScopeError for unassigned branch', () => {
      const ctx = createContext('manager', ['branch-1'], []);
      expect(() => validator.assertBranchInScope('branch-2', ctx)).toThrow(
        BranchOutOfScopeError,
      );
    });
  });

  describe('assertLocationInScope', () => {
    it('should allow admin access to any stock location', () => {
      const ctx = createContext('admin', [], []);
      expect(() =>
        validator.assertLocationInScope('loc-999', ctx),
      ).not.toThrow();
    });

    it('should allow user access to assigned stock location', () => {
      const ctx = createContext('staff', [], ['loc-1', 'loc-2']);
      expect(() => validator.assertLocationInScope('loc-2', ctx)).not.toThrow();
    });

    it('should throw StockLocationOutOfScopeError for unassigned location', () => {
      const ctx = createContext('staff', [], ['loc-1']);
      expect(() => validator.assertLocationInScope('loc-2', ctx)).toThrow(
        StockLocationOutOfScopeError,
      );
    });
  });
});
