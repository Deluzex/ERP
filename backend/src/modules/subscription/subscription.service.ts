import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { AuditService } from '../../core/audit/audit.service';
import { RequestContext } from '../../core/auth/request-context';
import { DatabasePool } from '../../core/database/connection';
import {
  RenewSubscriptionDto,
  SubscriptionStatusResponse,
  UpdateSubscriptionDto,
} from './dto/subscription.dto';

@Injectable()
export class SubscriptionService {
  constructor(
    private readonly db: DatabasePool,
    private readonly auditService: AuditService,
  ) {}

  // --------------------------------------------------------------------------
  // 1. Get Live Subscription Status (Authoritative PostgreSQL Database Time)
  // --------------------------------------------------------------------------
  async getSubscriptionStatus(): Promise<SubscriptionStatusResponse> {
    const res = await this.db.query<{
      id: string;
      client_name: string;
      plan_name: string;
      valid_from: Date;
      valid_until: Date;
      is_active: boolean;
      warning_days: number;
      support_phone: string;
      support_email: string;
      is_expired: boolean;
      days_remaining: number;
    }>(
      `SELECT id, client_name, plan_name, valid_from, valid_until, is_active, warning_days,
              support_phone, support_email,
              (valid_until <= NOW() OR is_active = FALSE) AS is_expired,
              GREATEST(0, CEIL(EXTRACT(EPOCH FROM (valid_until - NOW())) / 86400))::INT AS days_remaining
       FROM instance_subscriptions
       ORDER BY created_at ASC
       LIMIT 1`,
    );

    if (res.rows.length === 0) {
      throw new NotFoundException('Instance subscription record not found');
    }

    const row = res.rows[0];
    const isExpired = Boolean(row.is_expired);
    const daysRemaining = Number(row.days_remaining);
    const warningDays = row.warning_days ?? 30;
    const showRenewalWarning = !isExpired && daysRemaining <= warningDays;

    return {
      clientName: row.client_name,
      planName: row.plan_name,
      isActive: row.is_active,
      isExpired,
      validFrom: row.valid_from instanceof Date ? row.valid_from.toISOString() : String(row.valid_from),
      validUntil: row.valid_until instanceof Date ? row.valid_until.toISOString() : String(row.valid_until),
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
        message: 'Your subscription has expired. Please contact support to renew and restore access.',
        supportPhone: status.supportPhone,
        supportEmail: status.supportEmail,
        expiredOn: status.validUntil,
      });
    }

    return status;
  }

  // --------------------------------------------------------------------------
  // 3. Renew Subscription (Extends by N months with Audit Logging)
  // --------------------------------------------------------------------------
  async renew(dto: RenewSubscriptionDto, ctx?: RequestContext): Promise<SubscriptionStatusResponse> {
    const months = dto.months && dto.months > 0 ? dto.months : 12;

    const beforeRes = await this.db.query<any>(
      `SELECT id, valid_until, is_active FROM instance_subscriptions ORDER BY created_at ASC LIMIT 1`,
    );
    const beforeRow = beforeRes.rows[0];

    const updateRes = await this.db.query<any>(
      `UPDATE instance_subscriptions
       SET valid_until = GREATEST(valid_until, NOW()) + ($1 || ' months')::interval,
           is_active = TRUE,
           updated_at = NOW()
       WHERE id = (SELECT id FROM instance_subscriptions ORDER BY created_at ASC LIMIT 1)
       RETURNING id, valid_until, is_active`,
      [months],
    );

    const updatedRow = updateRes.rows[0];

    // Record audit trail if context available
    if (ctx && updatedRow) {
      await this.auditService.record({
        action: 'SUBSCRIPTION_RENEWAL',
        entityType: 'instance_subscriptions',
        entityId: updatedRow.id,
        beforeSnapshot: beforeRow ? { validUntil: beforeRow.valid_until, isActive: beforeRow.is_active } : null,
        afterSnapshot: { validUntil: updatedRow.valid_until, isActive: updatedRow.is_active, monthsAdded: months },
        reason: 'Administrative instance subscription extension',
        userId: ctx.userId,
        userName: ctx.userName,
        correlationId: ctx.correlationId,
        ipAddress: ctx.ipAddress,
      });
    }

    return this.getSubscriptionStatus();
  }

  // --------------------------------------------------------------------------
  // 4. Update Subscription Metadata
  // --------------------------------------------------------------------------
  async update(dto: UpdateSubscriptionDto, ctx?: RequestContext): Promise<SubscriptionStatusResponse> {
    const beforeRes = await this.db.query<any>(
      `SELECT id, client_name, plan_name, is_active, warning_days, support_phone, support_email
       FROM instance_subscriptions ORDER BY created_at ASC LIMIT 1`,
    );
    const beforeRow = beforeRes.rows[0];

    const res = await this.db.query<any>(
      `UPDATE instance_subscriptions
       SET client_name = COALESCE($1, client_name),
           plan_name = COALESCE($2, plan_name),
           is_active = COALESCE($3, is_active),
           warning_days = COALESCE($4, warning_days),
           support_phone = COALESCE($5, support_phone),
           support_email = COALESCE($6, support_email),
           updated_at = NOW()
       WHERE id = (SELECT id FROM instance_subscriptions ORDER BY created_at ASC LIMIT 1)
       RETURNING *`,
      [
        dto.clientName,
        dto.planName,
        dto.isActive,
        dto.warningDays,
        dto.supportPhone,
        dto.supportEmail,
      ],
    );

    const updatedRow = res.rows[0];

    if (ctx && updatedRow) {
      await this.auditService.record({
        action: 'SUBSCRIPTION_UPDATED',
        entityType: 'instance_subscriptions',
        entityId: updatedRow.id,
        beforeSnapshot: beforeRow,
        afterSnapshot: updatedRow,
        reason: 'Administrative subscription configuration update',
        userId: ctx.userId,
        userName: ctx.userName,
        correlationId: ctx.correlationId,
        ipAddress: ctx.ipAddress,
      });
    }

    return this.getSubscriptionStatus();
  }
}
