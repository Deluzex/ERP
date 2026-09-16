import { Injectable } from '@nestjs/common';
import { AuditService } from '../../../core/audit/audit.service';
import { DatabasePool } from '../../../core/database/connection';
import { ConflictError } from '../../../core/errors/conflict.error';
import { NotFoundError } from '../../../core/errors/not-found.error';
import { CreateCategoryDto, UpdateCategoryDto } from '../dto/category.dto';

export interface CategoryRecord {
  id: string;
  name: string;
  description: string | null;
  createdAt: Date;
  updatedAt: Date;
}

@Injectable()
export class CategoriesService {
  constructor(
    private readonly db: DatabasePool,
    private readonly auditService: AuditService,
  ) {}

  async findAll(): Promise<CategoryRecord[]> {
    const res = await this.db.query<{
      id: string;
      name: string;
      description: string | null;
      created_at: Date;
      updated_at: Date;
    }>('SELECT * FROM categories ORDER BY name ASC');

    return res.rows.map((r) => ({
      id: r.id,
      name: r.name,
      description: r.description,
      createdAt: r.created_at,
      updatedAt: r.updated_at,
    }));
  }

  async findById(id: string): Promise<CategoryRecord> {
    const res = await this.db.query<{
      id: string;
      name: string;
      description: string | null;
      created_at: Date;
      updated_at: Date;
    }>('SELECT * FROM categories WHERE id = $1', [id]);

    const cat = res.rows[0];
    if (!cat) {
      throw new NotFoundError('Category', id);
    }

    return {
      id: cat.id,
      name: cat.name,
      description: cat.description,
      createdAt: cat.created_at,
      updatedAt: cat.updated_at,
    };
  }

  async create(
    dto: CreateCategoryDto,
    userId?: string,
    correlationId?: string,
  ): Promise<CategoryRecord> {
    const existing = await this.db.query(
      'SELECT 1 FROM categories WHERE LOWER(name) = LOWER($1)',
      [dto.name.trim()],
    );
    if (existing.rowCount && existing.rowCount > 0) {
      throw new ConflictError(`Category "${dto.name}" already exists`);
    }

    const res = await this.db.query<{
      id: string;
      name: string;
      description: string | null;
      created_at: Date;
      updated_at: Date;
    }>(
      `INSERT INTO categories (name, description)
       VALUES ($1, $2)
       RETURNING id, name, description, created_at, updated_at`,
      [dto.name.trim(), dto.description || null],
    );

    const record = res.rows[0];

    await this.auditService.log({
      userId,
      userName: 'User',
      action: 'CATEGORY_CREATE',
      entityType: 'CATEGORY',
      entityId: record.id,
      afterSnapshot: { ...dto },
      correlationId,
    });

    return {
      id: record.id,
      name: record.name,
      description: record.description,
      createdAt: record.created_at,
      updatedAt: record.updated_at,
    };
  }

  async update(
    id: string,
    dto: UpdateCategoryDto,
    userId?: string,
    correlationId?: string,
  ): Promise<CategoryRecord> {
    const existing = await this.findById(id);

    const updates: string[] = [];
    const values: unknown[] = [];
    let idx = 1;

    if (dto.name !== undefined) {
      updates.push(`name = $${idx++}`);
      values.push(dto.name.trim());
    }
    if (dto.description !== undefined) {
      updates.push(`description = $${idx++}`);
      values.push(dto.description);
    }

    if (updates.length > 0) {
      updates.push(`updated_at = NOW()`);
      values.push(id);
      await this.db.query(
        `UPDATE categories SET ${updates.join(', ')} WHERE id = $${idx}`,
        values,
      );
    }

    await this.auditService.log({
      userId,
      userName: 'User',
      action: 'CATEGORY_UPDATE',
      entityType: 'CATEGORY',
      entityId: id,
      beforeSnapshot: existing as any,
      afterSnapshot: { ...existing, ...dto },
      correlationId,
    });

    return this.findById(id);
  }

  async delete(
    id: string,
    userId?: string,
    correlationId?: string,
  ): Promise<{ success: boolean }> {
    await this.findById(id);

    await this.db.query('DELETE FROM categories WHERE id = $1', [id]);

    await this.auditService.log({
      userId,
      userName: 'User',
      action: 'CATEGORY_DELETE',
      entityType: 'CATEGORY',
      entityId: id,
      correlationId,
    });

    return { success: true };
  }
}
