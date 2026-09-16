import { Injectable } from '@nestjs/common';
import { AuditService } from '../../core/audit/audit.service';
import { Argon2Service } from '../../core/auth/argon2.service';
import { DatabasePool } from '../../core/database/connection';
import { UnitOfWork } from '../../core/database/unit-of-work';
import { ConflictError } from '../../core/errors/conflict.error';
import { NotFoundError } from '../../core/errors/not-found.error';
import { CreateUserDto } from './dto/create-user.dto';
import { UpdateUserScopesDto } from './dto/update-user-scopes.dto';
import { UpdateUserDto } from './dto/update-user.dto';

export interface UserSummary {
  id: string;
  name: string;
  email: string;
  mobile: string;
  avatarUrl: string | null;
  isActive: boolean;
  roleId: string;
  roleName: string;
  branchIds: string[];
  stockLocationIds: string[];
  createdAt: Date;
  lastLoginAt: Date | null;
}

@Injectable()
export class UsersService {
  constructor(
    private readonly db: DatabasePool,
    private readonly uow: UnitOfWork,
    private readonly argon2: Argon2Service,
    private readonly auditService: AuditService,
  ) {}

  async findAll(): Promise<UserSummary[]> {
    const res = await this.db.query<{
      id: string;
      name: string;
      email: string;
      mobile: string;
      avatar_url: string | null;
      is_active: boolean;
      role_id: string;
      role_name: string;
      created_at: Date;
      last_login_at: Date | null;
    }>(
      `SELECT u.id, u.name, u.email, u.mobile, u.avatar_url, u.is_active,
              COALESCE(r.id, 'viewer') AS role_id,
              COALESCE(r.name, 'Viewer') AS role_name,
              u.created_at, u.last_login_at
       FROM users u
       LEFT JOIN user_roles ur ON ur.user_id = u.id AND ur.is_primary = true
       LEFT JOIN roles r ON r.id = ur.role_id
       ORDER BY u.created_at DESC`,
    );

    const branchRes = await this.db.query<{ user_id: string; branch_id: string }>(
      'SELECT user_id, branch_id FROM user_branch_access',
    );
    const locRes = await this.db.query<{
      user_id: string;
      stock_location_id: string;
    }>('SELECT user_id, stock_location_id FROM user_stock_location_access');

    const branchMap = new Map<string, string[]>();
    for (const b of branchRes.rows) {
      const arr = branchMap.get(b.user_id) || [];
      arr.push(b.branch_id);
      branchMap.set(b.user_id, arr);
    }

    const locMap = new Map<string, string[]>();
    for (const l of locRes.rows) {
      const arr = locMap.get(l.user_id) || [];
      arr.push(l.stock_location_id);
      locMap.set(l.user_id, arr);
    }

    return res.rows.map((u) => ({
      id: u.id,
      name: u.name,
      email: u.email,
      mobile: u.mobile,
      avatarUrl: u.avatar_url,
      isActive: u.is_active,
      roleId: u.role_id,
      roleName: u.role_name,
      branchIds: branchMap.get(u.id) || [],
      stockLocationIds: locMap.get(u.id) || [],
      createdAt: u.created_at,
      lastLoginAt: u.last_login_at,
    }));
  }

  async findById(id: string): Promise<UserSummary> {
    const res = await this.db.query<{
      id: string;
      name: string;
      email: string;
      mobile: string;
      avatar_url: string | null;
      is_active: boolean;
      role_id: string;
      role_name: string;
      created_at: Date;
      last_login_at: Date | null;
    }>(
      `SELECT u.id, u.name, u.email, u.mobile, u.avatar_url, u.is_active,
              COALESCE(r.id, 'viewer') AS role_id,
              COALESCE(r.name, 'Viewer') AS role_name,
              u.created_at, u.last_login_at
       FROM users u
       LEFT JOIN user_roles ur ON ur.user_id = u.id AND ur.is_primary = true
       LEFT JOIN roles r ON r.id = ur.role_id
       WHERE u.id = $1`,
      [id],
    );

    const user = res.rows[0];
    if (!user) {
      throw new NotFoundError('User', id);
    }

    const branches = await this.db.query<{ branch_id: string }>(
      'SELECT branch_id FROM user_branch_access WHERE user_id = $1',
      [id],
    );
    const locations = await this.db.query<{ stock_location_id: string }>(
      'SELECT stock_location_id FROM user_stock_location_access WHERE user_id = $1',
      [id],
    );

    return {
      id: user.id,
      name: user.name,
      email: user.email,
      mobile: user.mobile,
      avatarUrl: user.avatar_url,
      isActive: user.is_active,
      roleId: user.role_id,
      roleName: user.role_name,
      branchIds: branches.rows.map((b) => b.branch_id),
      stockLocationIds: locations.rows.map((l) => l.stock_location_id),
      createdAt: user.created_at,
      lastLoginAt: user.last_login_at,
    };
  }

  async create(
    dto: CreateUserDto,
    currentUserId?: string,
    correlationId?: string,
  ): Promise<UserSummary> {
    const existing = await this.db.query(
      'SELECT 1 FROM users WHERE LOWER(email) = LOWER($1)',
      [dto.email.trim()],
    );
    if (existing.rowCount && existing.rowCount > 0) {
      throw new ConflictError(`User with email "${dto.email}" already exists`);
    }

    const passwordHash = await this.argon2.hash(dto.password);

    return this.uow.runInTransaction(async (client) => {
      const userRes = await client.query<{ id: string; created_at: Date }>(
        `INSERT INTO users (name, email, mobile, password_hash, avatar_url, is_active)
         VALUES ($1, $2, $3, $4, $5, true)
         RETURNING id, created_at`,
        [
          dto.name,
          dto.email.trim().toLowerCase(),
          dto.mobile,
          passwordHash,
          dto.avatarUrl || null,
        ],
      );

      const userId = userRes.rows[0].id;

      // Assign primary role
      await client.query(
        `INSERT INTO user_roles (user_id, role_id, is_primary)
         VALUES ($1, $2, true)`,
        [userId, dto.roleId],
      );

      // Assign branch scopes
      if (dto.branchIds && dto.branchIds.length > 0) {
        for (const branchId of dto.branchIds) {
          await client.query(
            `INSERT INTO user_branch_access (user_id, branch_id)
             VALUES ($1, $2) ON CONFLICT DO NOTHING`,
            [userId, branchId],
          );
        }
      }

      // Assign stock location scopes
      if (dto.stockLocationIds && dto.stockLocationIds.length > 0) {
        for (const locId of dto.stockLocationIds) {
          await client.query(
            `INSERT INTO user_stock_location_access (user_id, stock_location_id)
             VALUES ($1, $2) ON CONFLICT DO NOTHING`,
            [userId, locId],
          );
        }
      }

      await this.auditService.log({
        userId: currentUserId,
        userName: 'Admin',
        action: 'USER_CREATE',
        entityType: 'USER',
        entityId: userId,
        afterSnapshot: {
          name: dto.name,
          email: dto.email,
          roleId: dto.roleId,
          branchIds: dto.branchIds,
          stockLocationIds: dto.stockLocationIds,
        },
        correlationId,
      });

      return {
        id: userId,
        name: dto.name,
        email: dto.email,
        mobile: dto.mobile,
        avatarUrl: dto.avatarUrl || null,
        isActive: true,
        roleId: dto.roleId,
        roleName: dto.roleId,
        branchIds: dto.branchIds || [],
        stockLocationIds: dto.stockLocationIds || [],
        createdAt: userRes.rows[0].created_at,
        lastLoginAt: null,
      };
    });
  }

  async update(
    id: string,
    dto: UpdateUserDto,
    currentUserId?: string,
    correlationId?: string,
  ): Promise<UserSummary> {
    const existing = await this.findById(id);

    return this.uow.runInTransaction(async (client) => {
      const updates: string[] = [];
      const values: unknown[] = [];
      let idx = 1;

      if (dto.name !== undefined) {
        updates.push(`name = $${idx++}`);
        values.push(dto.name);
      }
      if (dto.mobile !== undefined) {
        updates.push(`mobile = $${idx++}`);
        values.push(dto.mobile);
      }
      if (dto.avatarUrl !== undefined) {
        updates.push(`avatar_url = $${idx++}`);
        values.push(dto.avatarUrl);
      }
      if (dto.isActive !== undefined) {
        updates.push(`is_active = $${idx++}`);
        values.push(dto.isActive);
      }

      if (updates.length > 0) {
        updates.push(`updated_at = NOW()`);
        values.push(id);
        await client.query(
          `UPDATE users SET ${updates.join(', ')} WHERE id = $${idx}`,
          values,
        );
      }

      if (dto.roleId && dto.roleId !== existing.roleId) {
        await client.query(
          `INSERT INTO user_roles (user_id, role_id, is_primary)
           VALUES ($1, $2, true)
           ON CONFLICT (user_id, role_id)
           DO UPDATE SET is_primary = true`,
          [id, dto.roleId],
        );
        // Demote other roles from primary
        await client.query(
          `UPDATE user_roles SET is_primary = false WHERE user_id = $1 AND role_id != $2`,
          [id, dto.roleId],
        );
      }

      await this.auditService.log({
        userId: currentUserId,
        userName: 'Admin',
        action: 'USER_UPDATE',
        entityType: 'USER',
        entityId: id,
        beforeSnapshot: existing as any,
        afterSnapshot: { ...existing, ...dto },
        correlationId,
      });

      return {
        ...existing,
        name: dto.name ?? existing.name,
        mobile: dto.mobile ?? existing.mobile,
        avatarUrl: dto.avatarUrl ?? existing.avatarUrl,
        isActive: dto.isActive ?? existing.isActive,
        roleId: dto.roleId ?? existing.roleId,
      };
    });
  }

  async updateScopes(
    id: string,
    dto: UpdateUserScopesDto,
    currentUserId?: string,
    correlationId?: string,
  ): Promise<UserSummary> {
    const existing = await this.findById(id);

    return this.uow.runInTransaction(async (client) => {
      if (dto.branchIds !== undefined) {
        await client.query('DELETE FROM user_branch_access WHERE user_id = $1', [
          id,
        ]);
        for (const branchId of dto.branchIds) {
          await client.query(
            'INSERT INTO user_branch_access (user_id, branch_id) VALUES ($1, $2)',
            [id, branchId],
          );
        }
      }

      if (dto.stockLocationIds !== undefined) {
        await client.query(
          'DELETE FROM user_stock_location_access WHERE user_id = $1',
          [id],
        );
        for (const locId of dto.stockLocationIds) {
          await client.query(
            'INSERT INTO user_stock_location_access (user_id, stock_location_id) VALUES ($1, $2)',
            [id, locId],
          );
        }
      }

      await this.auditService.log({
        userId: currentUserId,
        userName: 'Admin',
        action: 'USER_SCOPES_UPDATE',
        entityType: 'USER',
        entityId: id,
        beforeSnapshot: {
          branchIds: existing.branchIds,
          stockLocationIds: existing.stockLocationIds,
        },
        afterSnapshot: {
          branchIds: dto.branchIds ?? existing.branchIds,
          stockLocationIds: dto.stockLocationIds ?? existing.stockLocationIds,
        },
        correlationId,
      });

      return {
        ...existing,
        branchIds: dto.branchIds ?? existing.branchIds,
        stockLocationIds: dto.stockLocationIds ?? existing.stockLocationIds,
      };
    });
  }

  async delete(
    id: string,
    currentUserId?: string,
    correlationId?: string,
  ): Promise<{ success: boolean }> {
    await this.findById(id);

    await this.uow.runInTransaction(async (client) => {
      await client.query(
        'UPDATE users SET is_active = false, updated_at = NOW() WHERE id = $1',
        [id],
      );
      await client.query(
        'UPDATE refresh_tokens SET is_revoked = true WHERE user_id = $1',
        [id],
      );

      await this.auditService.log({
        userId: currentUserId,
        userName: 'Admin',
        action: 'USER_DEACTIVATE',
        entityType: 'USER',
        entityId: id,
        correlationId,
      });
    });

    return { success: true };
  }
}
