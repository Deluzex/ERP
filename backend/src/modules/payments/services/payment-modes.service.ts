import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { DatabasePool } from '../../../core/database/connection';
import {
  CreatePaymentModeDto,
  UpdatePaymentModeDto,
} from '../dto/payment-mode.dto';

export interface PaymentModeRecord {
  id: string;
  name: string;
  code: string;
  requiresReference: boolean;
  description: string | null;
  isActive: boolean;
  createdAt: Date;
  updatedAt: Date;
}

@Injectable()
export class PaymentModesService {
  constructor(private readonly db: DatabasePool) {}

  async findAll(): Promise<PaymentModeRecord[]> {
    const res = await this.db.query<any>(
      `SELECT * FROM payment_modes ORDER BY created_at ASC`,
    );
    return res.rows.map((r) => this.mapRow(r));
  }

  async findById(id: string): Promise<PaymentModeRecord> {
    const res = await this.db.query<any>(
      `SELECT * FROM payment_modes WHERE id = $1`,
      [id],
    );
    if (res.rows.length === 0) {
      throw new NotFoundException(`Payment mode with ID ${id} not found`);
    }
    return this.mapRow(res.rows[0]);
  }

  async create(dto: CreatePaymentModeDto): Promise<PaymentModeRecord> {
    const existing = await this.db.query(
      `SELECT id FROM payment_modes WHERE UPPER(code) = UPPER($1)`,
      [dto.code.trim()],
    );
    if (existing.rows.length > 0) {
      throw new ConflictException(`Payment mode with code "${dto.code}" already exists`);
    }

    const res = await this.db.query<any>(
      `INSERT INTO payment_modes (name, code, requires_reference, description, is_active)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING *`,
      [
        dto.name.trim(),
        dto.code.trim().toUpperCase(),
        dto.requiresReference ?? true,
        dto.description?.trim() || null,
        dto.isActive ?? true,
      ],
    );

    return this.mapRow(res.rows[0]);
  }

  async update(id: string, dto: UpdatePaymentModeDto): Promise<PaymentModeRecord> {
    await this.findById(id);

    const updates: string[] = [];
    const values: any[] = [];
    let idx = 1;

    if (dto.name !== undefined) {
      updates.push(`name = $${idx++}`);
      values.push(dto.name.trim());
    }
    if (dto.requiresReference !== undefined) {
      updates.push(`requires_reference = $${idx++}`);
      values.push(dto.requiresReference);
    }
    if (dto.description !== undefined) {
      updates.push(`description = $${idx++}`);
      values.push(dto.description.trim());
    }
    if (dto.isActive !== undefined) {
      updates.push(`is_active = $${idx++}`);
      values.push(dto.isActive);
    }

    if (updates.length > 0) {
      updates.push(`updated_at = NOW()`);
      values.push(id);
      await this.db.query(
        `UPDATE payment_modes SET ${updates.join(', ')} WHERE id = $${idx}`,
        values,
      );
    }

    return this.findById(id);
  }

  async updateStatus(id: string, isActive: boolean): Promise<PaymentModeRecord> {
    await this.findById(id);
    await this.db.query(
      `UPDATE payment_modes SET is_active = $1, updated_at = NOW() WHERE id = $2`,
      [isActive, id],
    );
    return this.findById(id);
  }

  private mapRow(r: any): PaymentModeRecord {
    return {
      id: r.id,
      name: r.name,
      code: r.code,
      requiresReference: r.requires_reference,
      description: r.description,
      isActive: r.is_active,
      createdAt: r.created_at,
      updatedAt: r.updated_at,
    };
  }
}
