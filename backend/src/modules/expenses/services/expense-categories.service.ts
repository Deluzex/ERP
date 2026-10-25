import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { DatabasePool } from '../../../core/database/connection';
import {
  CreateExpenseCategoryDto,
  ExpenseCategoryQueryDto,
  UpdateExpenseCategoryDto,
} from '../dto/expense-category.dto';

export interface ExpenseCategoryRecord {
  id: string;
  name: string;
  code: string;
  description: string | null;
  isActive: boolean;
  linkedKey?: string | null;
  createdAt: Date;
  updatedAt: Date;
}

@Injectable()
export class ExpenseCategoriesService {
  constructor(private readonly db: DatabasePool) {}

  async findAll(query: ExpenseCategoryQueryDto) {
    const page = query.page || 1;
    const limit = query.limit || 50;
    const offset = (page - 1) * limit;

    const conditions: string[] = [];
    const values: any[] = [];
    let idx = 1;

    if (query.search && query.search.trim().length > 0) {
      conditions.push(`(name ILIKE $${idx} OR code ILIKE $${idx} OR description ILIKE $${idx})`);
      values.push(`%${query.search.trim()}%`);
      idx++;
    }

    if (query.isActive !== undefined) {
      conditions.push(`is_active = $${idx}`);
      values.push(query.isActive);
      idx++;
    }

    const whereClause = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';

    const countRes = await this.db.query<{ count: string }>(
      `SELECT count(*) FROM expense_categories ${whereClause}`,
      values,
    );
    const totalItems = parseInt(countRes.rows[0].count, 10);
    const totalPages = Math.ceil(totalItems / limit) || 1;

    values.push(limit);
    values.push(offset);

    const rowsRes = await this.db.query<any>(
      `SELECT * FROM expense_categories ${whereClause} 
       ORDER BY created_at ASC 
       LIMIT $${idx} OFFSET $${idx + 1}`,
      values,
    );

    return {
      items: rowsRes.rows.map((r) => this.mapRow(r)),
      pagination: {
        totalItems,
        totalPages,
        currentPage: page,
        limit,
        hasNextPage: page < totalPages,
        hasPrevPage: page > 1,
      },
    };
  }

  async findById(id: string): Promise<ExpenseCategoryRecord> {
    const res = await this.db.query<any>(
      `SELECT * FROM expense_categories WHERE id = $1`,
      [id],
    );
    if (res.rows.length === 0) {
      throw new NotFoundException(`Expense category with ID ${id} not found`);
    }
    return this.mapRow(res.rows[0]);
  }

  async create(dto: CreateExpenseCategoryDto): Promise<ExpenseCategoryRecord> {
    const existing = await this.db.query(
      `SELECT id FROM expense_categories WHERE UPPER(code) = UPPER($1)`,
      [dto.code.trim()],
    );
    if (existing.rows.length > 0) {
      throw new ConflictException(`Expense category with code "${dto.code}" already exists`);
    }

    const res = await this.db.query<any>(
      `INSERT INTO expense_categories (name, code, description, is_active, linked_key)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING *`,
      [
        dto.name.trim(),
        dto.code.trim().toUpperCase(),
        dto.description?.trim() || null,
        dto.isActive ?? true,
        dto.linkedKey?.trim() || null,
      ],
    );

    return this.mapRow(res.rows[0]);
  }

  async update(id: string, dto: UpdateExpenseCategoryDto): Promise<ExpenseCategoryRecord> {
    await this.findById(id);

    if (dto.code) {
      const existing = await this.db.query(
        `SELECT id FROM expense_categories WHERE UPPER(code) = UPPER($1) AND id != $2`,
        [dto.code.trim(), id],
      );
      if (existing.rows.length > 0) {
        throw new ConflictException(`Expense category with code "${dto.code}" already exists`);
      }
    }

    const updates: string[] = [];
    const values: any[] = [];
    let idx = 1;

    if (dto.name !== undefined) {
      updates.push(`name = $${idx++}`);
      values.push(dto.name.trim());
    }
    if (dto.code !== undefined) {
      updates.push(`code = $${idx++}`);
      values.push(dto.code.trim().toUpperCase());
    }
    if (dto.description !== undefined) {
      updates.push(`description = $${idx++}`);
      values.push(dto.description.trim());
    }
    if (dto.isActive !== undefined) {
      updates.push(`is_active = $${idx++}`);
      values.push(dto.isActive);
    }
    if (dto.linkedKey !== undefined) {
      updates.push(`linked_key = $${idx++}`);
      values.push(dto.linkedKey?.trim() || null);
    }

    if (updates.length > 0) {
      updates.push(`updated_at = NOW()`);
      values.push(id);
      await this.db.query(
        `UPDATE expense_categories SET ${updates.join(', ')} WHERE id = $${idx}`,
        values,
      );
    }

    return this.findById(id);
  }

  async updateStatus(id: string, isActive: boolean): Promise<ExpenseCategoryRecord> {
    await this.findById(id);
    await this.db.query(
      `UPDATE expense_categories SET is_active = $1, updated_at = NOW() WHERE id = $2`,
      [isActive, id],
    );
    return this.findById(id);
  }

  async delete(id: string): Promise<{ success: boolean }> {
    await this.findById(id);
    await this.db.query('DELETE FROM expense_categories WHERE id = $1', [id]);
    return { success: true };
  }

  private mapRow(r: any): ExpenseCategoryRecord {
    return {
      id: r.id,
      name: r.name,
      code: r.code,
      description: r.description,
      isActive: r.is_active,
      linkedKey: r.linked_key || null,
      createdAt: r.created_at,
      updatedAt: r.updated_at,
    };
  }
}
