import { ExecutionContext } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { ForbiddenError } from '../errors/forbidden.error';
import { IS_PUBLIC_KEY, REQUIRED_PERMISSIONS_KEY } from './auth.constants';
import { PermissionGuard } from './permission.guard';

describe('PermissionGuard', () => {
  let guard: PermissionGuard;
  let reflector: Reflector;

  beforeEach(() => {
    reflector = new Reflector();
    guard = new PermissionGuard(reflector);
  });

  function createMockContext(request: any): ExecutionContext {
    return {
      getHandler: () => ({}),
      getClass: () => ({}),
      switchToHttp: () => ({
        getRequest: () => request,
      }),
    } as unknown as ExecutionContext;
  }

  it('should allow access if route is marked as public', () => {
    jest.spyOn(reflector, 'getAllAndOverride').mockImplementation((key) => {
      if (key === IS_PUBLIC_KEY) return true;
      return undefined;
    });

    const context = createMockContext({});
    expect(guard.canActivate(context)).toBe(true);
  });

  it('should deny by default if endpoint is protected but declares no permissions', () => {
    jest.spyOn(reflector, 'getAllAndOverride').mockImplementation((key) => {
      if (key === IS_PUBLIC_KEY) return false;
      if (key === REQUIRED_PERMISSIONS_KEY) return undefined;
      return undefined;
    });

    const context = createMockContext({});
    expect(() => guard.canActivate(context)).toThrow(ForbiddenError);
  });

  it('should deny Super Administrator if the required permission was stripped from their role', () => {
    jest.spyOn(reflector, 'getAllAndOverride').mockImplementation((key) => {
      if (key === IS_PUBLIC_KEY) return false;
      if (key === REQUIRED_PERMISSIONS_KEY) return ['purchase.delete'];
      return undefined;
    });

    const context = createMockContext({
      requestContext: {
        userId: 'admin-id',
        roleId: 'admin',
        permissions: new Set(['dashboard.view']),
      },
    });

    expect(() => guard.canActivate(context)).toThrow(ForbiddenError);
  });

  it('should allow user possessing the required permission', () => {
    jest.spyOn(reflector, 'getAllAndOverride').mockImplementation((key) => {
      if (key === IS_PUBLIC_KEY) return false;
      if (key === REQUIRED_PERMISSIONS_KEY) return ['inventory.view'];
      return undefined;
    });

    const context = createMockContext({
      requestContext: {
        userId: 'user-1',
        roleId: 'inventory_staff',
        permissions: new Set(['inventory.view']),
      },
    });

    expect(guard.canActivate(context)).toBe(true);
  });

  it('should throw ForbiddenError when user lacks the required permission', () => {
    jest.spyOn(reflector, 'getAllAndOverride').mockImplementation((key) => {
      if (key === IS_PUBLIC_KEY) return false;
      if (key === REQUIRED_PERMISSIONS_KEY) return ['purchase.approve'];
      return undefined;
    });

    const context = createMockContext({
      requestContext: {
        userId: 'user-1',
        roleId: 'inventory_staff',
        permissions: new Set(['inventory.view']),
      },
    });

    expect(() => guard.canActivate(context)).toThrow(ForbiddenError);
  });
});
