import { Body, Controller, ForbiddenException, Get, Patch, Put } from '@nestjs/common';
import { AllowAuthenticated } from '../../core/auth/allow-authenticated.decorator';
import { Ctx } from '../../core/auth/ctx.decorator';
import { Public } from '../../core/auth/public.decorator';
import { RequestContext } from '../../core/auth/request-context';
import {
  RenewSubscriptionDto,
  SubscriptionStatusResponse,
  UpdateSubscriptionDto,
} from './dto/subscription.dto';
import { SubscriptionService } from './subscription.service';

@Controller('subscription')
export class SubscriptionController {
  constructor(private readonly subscriptionService: SubscriptionService) {}

  /**
   * 1. Public Endpoint: Get Live Subscription Status
   * Accessible by login screen, status checks, and client dashboard
   */
  @Public()
  @Get('status')
  async getStatus(): Promise<SubscriptionStatusResponse> {
    return this.subscriptionService.getSubscriptionStatus();
  }

  /**
   * 2. Protected Endpoint: Renew Subscription
   * Only authenticated, authorized administrators can renew.
   * Whitelisted in SubscriptionGuard so expired instances can be recovered.
   */
  @AllowAuthenticated()
  @Patch('renew')
  async renew(
    @Body() dto: RenewSubscriptionDto,
    @Ctx() ctx: RequestContext,
  ): Promise<SubscriptionStatusResponse> {
    this.assertAdminPrivilege(ctx, 'renew');
    return this.subscriptionService.renew(dto, ctx);
  }

  /**
   * 3. Protected Endpoint: Update Subscription Settings
   */
  @AllowAuthenticated()
  @Put()
  async update(
    @Body() dto: UpdateSubscriptionDto,
    @Ctx() ctx: RequestContext,
  ): Promise<SubscriptionStatusResponse> {
    this.assertAdminPrivilege(ctx, 'update settings for');
    return this.subscriptionService.update(dto, ctx);
  }

  private assertAdminPrivilege(ctx: RequestContext, action: string): void {
    if (!ctx) {
      throw new ForbiddenException({
        code: 'INSUFFICIENT_PERMISSIONS',
        message: 'Authentication context required to ' + action + ' subscription.',
      });
    }

    const isAdmin =
      ctx.roleId === 'super_admin' ||
      ctx.roleId === 'admin' ||
      ctx.permissions.has('system.manage') ||
      ctx.permissions.has('settings.manage') ||
      ctx.permissions.has('admin.all');

    if (!isAdmin) {
      throw new ForbiddenException({
        code: 'INSUFFICIENT_PERMISSIONS',
        message: 'Only authorized administrators can ' + action + ' the instance subscription.',
      });
    }
  }
}
