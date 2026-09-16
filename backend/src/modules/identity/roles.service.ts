import { Injectable } from '@nestjs/common';
import {
  CANONICAL_PERMISSIONS,
  CanonicalPermission,
} from '../../core/access/permission-catalogue';
import { AuditService } from '../../core/audit/audit.service';
import { DatabasePool } from '../../core/database/connection';
import { UnitOfWork } from '../../core/database/unit-of-work';
import { ConflictError } from '../../core/errors/conflict.error';
import { NotFoundError } from '../../core/errors/not-found.error';
import { CreateRoleDto } from './dto/create-role.dto';
import { UpdateRolePermissionsDto } from './dto/update-role-permissions.dto';

export interface RoleWithPermissions {
  id: string;
  name: string;
  description: string;
  isSystemRole: boolean;
  isActive: boolean;
  defaultDashboardSection: string;
  permissions: string[];
  createdAt: Date;
  updatedAt: Date;
}

@Injectable()
export class RolesService {
  constructor(
    private readonly db: DatabasePool,
    private readonly uow: UnitOfWork,
    private readonly auditService: AuditService,
  ) {}

  getCatalogue(): CanonicalPermission[] {
    return CANONICAL_PERMISSIONS;
  }

  async findAll(): Promise<RoleWithPermissions[]> {
    const rolesRes = await this.db.query<{
      id: string;
      name: string;
      description: string;
      is_system_role: boolean;
      is_active: boolean;
      default_dashboard_section: string;
      created_at: Date;
      updated_at: Date;
    }>(
      `SELECT id, name, description, is_system_role, is_active,
              default_dashboard_section, created_at, updated_at
       FROM roles
       ORDER BY is_system_role DESC, name ASC`,
    );

    const permissionsRes = await this.db.query<{
      role_id: string;
      permission_id: string;
    }>('SELECT role_id, permission_id FROM role_permissions');

    const permMap = new Map<string, string[]>();
    for (const row of permissionsRes.rows) {
      const existing = permMap.get(row.role_id) || [];
      existing.push(row.permission_id);
      permMap.set(row.role_id, existing);
    }

    return rolesRes.rows.map((r) => ({
      id: r.id,
      name: r.name,
      description: r.description,
      isSystemRole: r.is_system_role,
      isActive: r.is_active,
      defaultDashboardSection: r.default_dashboard_section,
      permissions:
        r.id === 'admin'
          ? CANONICAL_PERMISSIONS.map((p) => p.id)
          : permMap.get(r.id) || [],
      createdAt: r.created_at,
      updatedAt: r.updated_at,
    }));
  }

  async findById(id: string): Promise<RoleWithPermissions> {
    const roleRes = await this.db.query<{
      id: string;
      name: string;
      description: string;
      is_system_role: boolean;
      is_active: boolean;
      default_dashboard_section: string;
      created_at: Date;
      updated_at: Date;
    }>('SELECT * FROM roles WHERE id = $1', [id]);

    const role = roleRes.rows[0];
    if (!role) {
      throw new NotFoundError('Role', id);
    }

    let permissions: string[] = [];
    if (role.id === 'admin') {
      permissions = CANONICAL_PERMISSIONS.map((p) => p.id);
    } else {
      const permRes = await this.db.query<{ permission_id: string }>(
        'SELECT permission_id FROM role_permissions WHERE role_id = $1',
        [id],
      );
      permissions = permRes.rows.map((p) => p.permission_id);
    }

    return {
      id: role.id,
      name: role.name,
      description: role.description,
      isSystemRole: role.is_system_role,
      isActive: role.is_active,
      defaultDashboardSection: role.default_dashboard_section,
      permissions,
      createdAt: role.created_at,
      updatedAt: role.updated_at,
    };
  }

  async create(
    dto: CreateRoleDto,
    userId?: string,
    correlationId?: string,
  ): Promise<RoleWithPermissions> {
    const existing = await this.db.query('SELECT 1 FROM roles WHERE id = $1', [
      dto.id,
    ]);
    if (existing.rowCount && existing.rowCount > 0) {
      throw new ConflictError(`Role with ID "${dto.id}" already exists`);
    }

    return this.uow.runInTransaction(async (client) => {
      await client.query(
        `INSERT INTO roles (id, name, description, default_dashboard_section, is_system_role, is_active)
         VALUES ($1, $2, $3, $4, false, true)`,
        [
          dto.id,
          dto.name,
          dto.description,
          dto.defaultDashboardSection || 'dashboard',
        ],
      );

      const permsToInsert = dto.permissions || [];
      for (const perm of permsToInsert) {
        await client.query(
          `INSERT INTO role_permissions (role_id, permission_id)
           VALUES ($1, $2)
           ON CONFLICT DO NOTHING`,
          [dto.id, perm],
        );
      }

      await this.auditService.log({
        userId,
        userName: 'Admin',
        action: 'ROLE_CREATE',
        entityType: 'ROLE',
        entityId: dto.id,
        afterSnapshot: { ...dto },
        correlationId,
      });

      return {
        id: dto.id,
        name: dto.name,
        description: dto.description,
        isSystemRole: false,
        isActive: true,
        defaultDashboardSection: dto.defaultDashboardSection || 'dashboard',
        permissions: permsToInsert,
        createdAt: new Date(),
        updatedAt: new Date(),
      };
    });
  }

  async updatePermissions(
    id: string,
    dto: UpdateRolePermissionsDto,
    userId?: string,
    correlationId?: string,
  ): Promise<RoleWithPermissions> {
    const role = await this.findById(id);

    return this.uow.runInTransaction(async (client) => {
      const beforeSnapshot = { permissions: role.permissions };

      await client.query('DELETE FROM role_permissions WHERE role_id = $1', [id]);

      for (const perm of dto.permissions) {
        await client.query(
          `INSERT INTO role_permissions (role_id, permission_id)
           VALUES ($1, $2)
           ON CONFLICT DO NOTHING`,
          [id, perm],
        );
      }

      await client.query('UPDATE roles SET updated_at = NOW() WHERE id = $1', [id]);

      await this.auditService.log({
        userId,
        userName: 'Admin',
        action: 'ROLE_PERMISSIONS_UPDATE',
        entityType: 'ROLE',
        entityId: id,
        beforeSnapshot,
        afterSnapshot: { permissions: dto.permissions },
        correlationId,
      });

      return {
        ...role,
        permissions: dto.permissions,
        updatedAt: new Date(),
      };
    });
  }
}
