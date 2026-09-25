import { CanActivate, ExecutionContext, Injectable } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { Request } from 'express';
import { UnauthorizedError } from '../errors/unauthorized.error';
import { IS_PUBLIC_KEY } from './auth.constants';
import { RequestContext } from './request-context';
import { TokenService } from './token.service';

@Injectable()
export class AuthGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly tokenService: TokenService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const isPublic = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);

    if (isPublic) {
      return true;
    }

    const request = context.switchToHttp().getRequest<Request & { requestContext?: RequestContext }>();
    const authHeader = request.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      throw new UnauthorizedError('Missing or malformed Authorization header');
    }

    const token = authHeader.substring(7);
    const payload = await this.tokenService.verifyAccessToken(token);

    const correlationId = (request.headers['x-correlation-id'] as string) || 'unknown';
    const ipAddress = request.ip || request.socket.remoteAddress;

    // Attach trusted RequestContext derived exclusively from verified server token
    request.requestContext = {
      userId: payload.sub,
      userName: payload.name,
      roleId: payload.roleId,
      branchIds: payload.branchIds || [],
      stockLocationIds: payload.stockLocationIds || [],
      permissions: new Set(payload.permissions || []),
      correlationId,
      ipAddress,
    };

    return true;
  }
}
