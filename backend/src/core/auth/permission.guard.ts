import { CanActivate, ExecutionContext, Injectable } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { Request } from 'express';
import { ForbiddenError } from '../errors/forbidden.error';
import {
  ALLOW_AUTHENTICATED_KEY,
  IS_PUBLIC_KEY,
  REQUIRED_PERMISSIONS_KEY,
} from './auth.constants';
import { RequestContext } from './request-context';

@Injectable()
export class PermissionGuard implements CanActivate {
  constructor(private readonly reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const isPublic = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);

    if (isPublic) {
      return true;
    }

    const request = context.switchToHttp().getRequest<Request & { requestContext?: RequestContext }>();
    const ctx = request.requestContext;

    if (!ctx) {
      throw new ForbiddenError('Security context missing');
    }

    const isAllowAuth = this.reflector.getAllAndOverride<boolean>(ALLOW_AUTHENTICATED_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);

    if (isAllowAuth) {
      return true;
    }

    const requiredPermissions = this.reflector.getAllAndOverride<string[]>(REQUIRED_PERMISSIONS_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);

    // Deny by default: if an endpoint is protected but declares no permission, fail closed
    if (!requiredPermissions || requiredPermissions.length === 0) {
      throw new ForbiddenError('Endpoint is protected but declares no required permissions');
    }

    // Verify caller possesses ALL required permissions for the action
    for (const permission of requiredPermissions) {
      if (!ctx.permissions.has(permission)) {
        throw new ForbiddenError(permission);
      }
    }

    return true;
  }
}
