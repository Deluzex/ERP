import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { DatabasePool } from '../../core/database/connection';
import {
  RenewSubscriptionDto,
  SubscriptionStatusResponse,
  UpdateSubscriptionDto,
} from './dto/subscription.dto';

@Injectable()
export class SubscriptionService {
  constructor(private readonly db: DatabasePool) {}

  // --------------------------------------------------------------------------
  // 1. Get Live Subscription Status
  // --------------------------------------------------------------------------
  async getSubscriptionStatus(): Promise<SubscriptionStatusResponse> {
    const res = await this.db.query<any>(
      `SELECT * FROM instance_subscriptions ORDER BY created_at ASC LIMIT 1`,
    );

    if (res.rows.length === 0) {
      throw new NotFoundException('Instance subscription record not found');
    }

    const row = res.rows[0];
    const now = new Date();
    const validUntilDate = new Date(row.valid_until);

    // Is it expired?
    // 1) Expired if valid_until is in the past
    // 2) Expired if manually deactivated (is_active is false)
    const isPastDeadline = validUntilDate.getTime() <= now.getTime();
    const isExpired = !row.is_active || isPastDeadline;

    // Remaining days calculation
    const diffMillis = validUntilDate.getTime() - now.getTime();
    const daysRemaining = isPastDeadline
      ? 0
      : Math.max(0, Math.ceil(diffMillis / (1000 * 60 * 60 * 24)));

    // Warning trigger: active, not expired, and remaining days <= warning_days (default 30)
    const warningDays = row.warning_days ?? 30;
    const showRenewalWarning = !isExpired && daysRemaining <= warningDays;

    return {
      clientName: row.client_name,
      planName: row.plan_name,
      isActive: row.is_active,
      isExpired,
      validFrom: row.valid_from,
      validUntil: row.valid_until,
      daysRemaining,
      showRenewalWarning,
      supportPhone: row.support_phone,
      supportEmail: row.support_email,
    };
  }

  // --------------------------------------------------------------------------
  // 2. Gatekeeper: Assert Subscription is Active
  // --------------------------------------------------------------------------
  async checkSubscriptionActive(): Promise<SubscriptionStatusResponse> {
    const status = await this.getSubscriptionStatus();

    if (status.isExpired) {
      throw new ForbiddenException({
        code: 'SUBSCRIPTION_EXPIRED',
        error: 'SUBSCRIPTION_EXPIRED',
        message: 'આપનું સબ્સ્ક્રિપ્શન સમાપ્ત થયેલ છે. પુનઃ શરૂ કરવા માટે કૃપા કરીને અમારો સંપર્ક કરો.',
        supportPhone: status.supportPhone,
        supportEmail: status.supportEmail,
        expiredOn: status.validUntil,
      });
    }

    return status;
  }

  // --------------------------------------------------------------------------
  // 3. Renew Subscription (Extends by N months)
  // --------------------------------------------------------------------------
  async renew(dto: RenewSubscriptionDto): Promise<SubscriptionStatusResponse> {
    const months = dto.months && dto.months > 0 ? dto.months : 12;

    await this.db.query(
      `UPDATE instance_subscriptions
       SET valid_until = GREATEST(valid_until, NOW()) + ($1 || ' months')::interval,
           is_active = TRUE,
           updated_at = NOW()
       WHERE id = (SELECT id FROM instance_subscriptions ORDER BY created_at ASC LIMIT 1)`,
      [months],
    );

    return this.getSubscriptionStatus();
  }

  // --------------------------------------------------------------------------
  // 4. Update Subscription Metadata
  // --------------------------------------------------------------------------
  async update(dto: UpdateSubscriptionDto): Promise<SubscriptionStatusResponse> {
    await this.db.query(
      `UPDATE instance_subscriptions
       SET client_name = COALESCE($1, client_name),
           plan_name = COALESCE($2, plan_name),
           is_active = COALESCE($3, is_active),
           warning_days = COALESCE($4, warning_days),
           support_phone = COALESCE($5, support_phone),
           support_email = COALESCE($6, support_email),
           updated_at = NOW()
       WHERE id = (SELECT id FROM instance_subscriptions ORDER BY created_at ASC LIMIT 1)`,
      [
        dto.clientName,
        dto.planName,
        dto.isActive,
        dto.warningDays,
        dto.supportPhone,
        dto.supportEmail,
      ],
    );

    return this.getSubscriptionStatus();
  }
}
