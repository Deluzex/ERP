import { Injectable } from '@nestjs/common';
import { DatabasePool } from '../database/connection';
import { TransactionalContext } from '../database/unit-of-work';
import { AppLogger } from '../logging/logger.service';

export interface AuditRecordOptions {
  userId?: string | null;
  userName?: string | null;
  action: string;
  entityType: string;
  entityId?: string | null;
  beforeSnapshot?: Record<string, unknown> | null;
  afterSnapshot?: Record<string, unknown> | null;
  reason?: string | null;
  correlationId?: string | null;
  ipAddress?: string | null;
}

@Injectable()
export class AuditService {
  constructor(
    private readonly pool: DatabasePool,
    private readonly logger: AppLogger,
  ) {}

  async record(options: AuditRecordOptions, tx?: TransactionalContext): Promise<void> {
    const text = `
      INSERT INTO audit_logs (
        id, user_id, user_name, action, entity_type, entity_id,
        before_snapshot, after_snapshot, reason, correlation_id, ip_address, created_at
      ) VALUES (
        gen_random_uuid(), $1, $2, $3, $4, $5,
        $6, $7, $8, $9, $10, now()
      )
    `;

    const params = [
      options.userId || null,
      options.userName || null,
      options.action,
      options.entityType,
      options.entityId || null,
      options.beforeSnapshot ? JSON.stringify(options.beforeSnapshot) : null,
      options.afterSnapshot ? JSON.stringify(options.afterSnapshot) : null,
      options.reason || null,
      options.correlationId || null,
      options.ipAddress || null,
    ];

    try {
      if (tx) {
        await tx.query(text, params);
      } else {
        await this.pool.query(text, params);
      }
    } catch (err: unknown) {
      this.logger.error('Failed to write audit log entry', (err as Error).stack, 'AuditService');
    }
  }

  async log(options: AuditRecordOptions, tx?: TransactionalContext): Promise<void> {
    return this.record(options, tx);
  }
}
