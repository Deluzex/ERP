import { CanActivate, ExecutionContext, Injectable } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { Request } from 'express';
import { IS_PUBLIC_KEY } from './auth.constants';
import { SubscriptionService } from '../../modules/subscription/subscription.service';

@Injectable()
export class SubscriptionGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly subscriptionService: SubscriptionService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const isPublic = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);

    // Whitelist public endpoints (login, status, refresh, health)
    if (isPublic) {
      return true;
    }

    const req = context.switchToHttp().getRequest<Request>();
    const path = req.path || req.url || '';

    // Allow renewal endpoint so authorized admins can restore an expired instance
    if (path.includes('/subscription/renew')) {
      return true;
    }

    // All protected business endpoints enforce active subscription
    await this.subscriptionService.checkSubscriptionActive();
    return true;
  }
}
