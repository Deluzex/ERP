import { Body, Controller, Get, Patch, Put } from '@nestjs/common';
import { AllowAuthenticated } from '../../core/auth/allow-authenticated.decorator';
import { Public } from '../../core/auth/public.decorator';
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
   * Extends valid_until and reactivates instance
   */
  @AllowAuthenticated()
  @Patch('renew')
  async renew(
    @Body() dto: RenewSubscriptionDto,
  ): Promise<SubscriptionStatusResponse> {
    return this.subscriptionService.renew(dto);
  }

  /**
   * 3. Protected Endpoint: Update Subscription Settings
   */
  @AllowAuthenticated()
  @Put()
  async update(
    @Body() dto: UpdateSubscriptionDto,
  ): Promise<SubscriptionStatusResponse> {
    return this.subscriptionService.update(dto);
  }
}
