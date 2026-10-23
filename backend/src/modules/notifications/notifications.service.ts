import { Injectable } from '@nestjs/common';
import { DatabasePool } from '../../core/database/connection';
import { RequestContext } from '../../core/auth/request-context';
import { NotFoundError } from '../../core/errors/not-found.error';
import { ForbiddenError } from '../../core/errors/forbidden.error';
import { CreateNotificationDto } from './dto/create-notification.dto';
import { NotificationQueryDto } from './dto/notification-query.dto';

export interface NotificationRecord {
  id: string;
  title: string;
  message: string;
  notificationType: string;
  targetRole: string | null;
  recipientUserId: string | null;
  recipientName: string | null;
  recipientEmail: string | null;
  sourceModule: string;
  relatedEntityType: string | null;
  relatedEntityId: string | null;
  data: Record<string, any>;
  isRead: boolean;
  readAt: string | null;
  createdAt: string;
}

@Injectable()
export class NotificationsService {
  constructor(private readonly db: DatabasePool) {}

  /**
   * Derive the SQL visibility condition based on the authenticated user context.
   * Ensures zero cross-role leakage and strict backend authorization.
   */
  private getVisibilityCondition(
    ctx: RequestContext,
    paramStartIndex: number,
  ): { condition: string; params: any[] } {
    const role = (ctx.roleId || '').toLowerCase();
    const userId = ctx.userId;

    // Super Admin: Full system-wide visibility
    if (role === 'admin') {
      return { condition: '1=1', params: [] };
    }

    // Purchase Role: Sees purchase-targeted notifications and directly assigned records
    if (role === 'purchase_manager' || role === 'purchase') {
      return {
        condition: `(target_role IN ('purchase_manager', 'purchase') OR recipient_user_id = $${paramStartIndex})`,
        params: [userId],
      };
    }

    // Production Role: Sees production-targeted notifications and directly assigned records
    if (role === 'production_manager' || role === 'production') {
      return {
        condition: `(target_role IN ('production_manager', 'production') OR recipient_user_id = $${paramStartIndex})`,
        params: [userId],
      };
    }

    // Sales Role: Sees sales-targeted notifications and directly assigned records
    if (role === 'sales_manager' || role === 'sales') {
      return {
        condition: `(target_role IN ('sales_manager', 'sales') OR recipient_user_id = $${paramStartIndex})`,
        params: [userId],
      };
    }

    // Other internal roles: Sees their role notifications or directly assigned records
    const internalRoles = ['inventory_manager', 'accounts_manager', 'project_manager'];
    if (internalRoles.includes(role)) {
      return {
        condition: `(target_role = $${paramStartIndex} OR recipient_user_id = $${paramStartIndex + 1})`,
        params: [role, userId],
      };
    }

    // External or unprivileged roles (customers, vendors, etc.):
    // ONLY see records addressed directly to them; NEVER see internal requisitions
    return {
      condition: `(recipient_user_id = $${paramStartIndex} AND notification_type NOT IN ('purchase_requisition', 'production_requisition'))`,
      params: [userId],
    };
  }

  /**
   * Map raw database row to sanitized NotificationRecord
   */
  private mapRow(row: any): NotificationRecord {
    return {
      id: row.id,
      title: row.title,
      message: row.message,
      notificationType: row.notification_type,
      targetRole: row.target_role,
      recipientUserId: row.recipient_user_id,
      recipientName: row.recipient_name,
      recipientEmail: row.recipient_email,
      sourceModule: row.source_module,
      relatedEntityType: row.related_entity_type,
      relatedEntityId: row.related_entity_id,
      data: typeof row.data === 'string' ? JSON.parse(row.data) : (row.data || {}),
      isRead: Boolean(row.is_read),
      readAt: row.read_at ? new Date(row.read_at).toISOString() : null,
      createdAt: new Date(row.created_at).toISOString(),
    };
  }

  /**
   * Query authorized notifications for the authenticated user
   */
  async getNotifications(query: NotificationQueryDto, ctx: RequestContext) {
    const page = Math.max(1, query.page || 1);
    const limit = Math.max(1, Math.min(100, query.limit || 50));
    const offset = (page - 1) * limit;

    const { condition, params } = this.getVisibilityCondition(ctx, 1);
    const filterClauses: string[] = [condition];
    const queryParams: any[] = [...params];

    if (query.unreadOnly) {
      filterClauses.push('is_read = false');
    }

    if (query.notificationType) {
      queryParams.push(query.notificationType);
      filterClauses.push(`notification_type = $${queryParams.length}`);
    }

    if (query.targetRole) {
      queryParams.push(query.targetRole);
      filterClauses.push(`target_role = $${queryParams.length}`);
    }

    const whereSql = filterClauses.length > 0 ? `WHERE ${filterClauses.join(' AND ')}` : '';

    // Total count for current filter
    const countRes = await this.db.query<{ count: string }>(
      `SELECT COUNT(*)::int as count FROM notifications ${whereSql}`,
      queryParams,
    );
    const total = parseInt(countRes.rows[0]?.count || '0', 10);

    // Unread count specifically for this user's authorized scope
    const unreadRes = await this.db.query<{ count: string }>(
      `SELECT COUNT(*)::int as count FROM notifications WHERE ${condition} AND is_read = false`,
      params,
    );
    const unreadCount = parseInt(unreadRes.rows[0]?.count || '0', 10);

    // Fetch paginated items
    const pIdx = queryParams.length + 1;
    const itemsRes = await this.db.query<any>(
      `SELECT * FROM notifications
       ${whereSql}
       ORDER BY created_at DESC
       LIMIT $${pIdx} OFFSET $${pIdx + 1}`,
      [...queryParams, limit, offset],
    );

    return {
      items: itemsRes.rows.map((r) => this.mapRow(r)),
      unreadCount,
      total,
      page,
      limit,
    };
  }

  /**
   * Create a persistent notification with idempotent retry protection
   */
  async createNotification(dto: CreateNotificationDto, actorUserId?: string): Promise<NotificationRecord> {
    const dataJson = dto.data ? JSON.stringify(dto.data) : '{}';

    // Idempotent retry protection: prevent duplicate notifications within 60 seconds
    const soRef = dto.data?.salesOrderNumber || dto.data?.salesOrderId;
    const sku = dto.data?.productSku;
    const targetRole = dto.targetRole || null;

    if (soRef && sku) {
      const existing = await this.db.query<any>(
        `SELECT * FROM notifications
         WHERE notification_type = $1
           AND (target_role = $2 OR ($2 IS NULL AND target_role IS NULL))
           AND (data->>'salesOrderNumber' = $3 OR data->>'salesOrderId' = $3)
           AND data->>'productSku' = $4
           AND created_at > now() - interval '60 seconds'
         ORDER BY created_at DESC
         LIMIT 1`,
        [dto.notificationType || 'requisition', targetRole, String(soRef), String(sku)],
      );

      if (existing.rows.length > 0) {
        return this.mapRow(existing.rows[0]);
      }
    }

    const res = await this.db.query<any>(
      `INSERT INTO notifications (
        title, message, notification_type, target_role,
        recipient_user_id, recipient_name, recipient_email,
        source_module, related_entity_type, related_entity_id,
        data, is_read
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11::jsonb, false)
      RETURNING *`,
      [
        dto.title,
        dto.message,
        dto.notificationType || 'requisition',
        targetRole,
        dto.recipientUserId || null,
        dto.recipientName || null,
        dto.recipientEmail || null,
        dto.sourceModule || 'sales',
        dto.relatedEntityType || 'sales_order',
        dto.relatedEntityId || null,
        dataJson,
      ],
    );

    return this.mapRow(res.rows[0]);
  }

  /**
   * Mark a single notification as read with strict authorization verification
   */
  async markAsRead(id: string, ctx: RequestContext): Promise<NotificationRecord> {
    const existing = await this.db.query<any>('SELECT * FROM notifications WHERE id = $1', [id]);
    if (existing.rows.length === 0) {
      throw new NotFoundError(`Notification with ID ${id} not found`);
    }

    const notif = existing.rows[0];
    const role = (ctx.roleId || '').toLowerCase();

    // Verify user is authorized to read this notification
    const isAuthorized =
      role === 'admin' ||
      notif.recipient_user_id === ctx.userId ||
      (notif.target_role && notif.target_role.toLowerCase() === role);

    if (!isAuthorized) {
      throw new ForbiddenError('You are not authorized to modify this notification');
    }

    const updated = await this.db.query<any>(
      `UPDATE notifications
       SET is_read = true, read_at = now()
       WHERE id = $1
       RETURNING *`,
      [id],
    );

    return this.mapRow(updated.rows[0]);
  }

  /**
   * Mark all visible notifications for the authenticated user as read
   */
  async markAllAsRead(ctx: RequestContext): Promise<{ count: number }> {
    const { condition, params } = this.getVisibilityCondition(ctx, 1);

    const updateRes = await this.db.query<any>(
      `UPDATE notifications
       SET is_read = true, read_at = now()
       WHERE ${condition} AND is_read = false
       RETURNING id`,
      params,
    );

    return { count: updateRes.rows.length };
  }
}
