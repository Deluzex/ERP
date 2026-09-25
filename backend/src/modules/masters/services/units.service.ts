import { Injectable } from '@nestjs/common';
import { AuditService } from '../../../core/audit/audit.service';
import { DatabasePool } from '../../../core/database/connection';
import { ConflictError } from '../../../core/errors/conflict.error';
import { NotFoundError } from '../../../core/errors/not-found.error';
import { CreateUnitDto } from '../dto/unit.dto';

export interface MeasurementUnitRecord {
  id: string;
  name: string;
  symbol: string;
  createdAt: Date;
}

@Injectable()
export class UnitsService {
  constructor(
    private readonly db: DatabasePool,
    private readonly auditService: AuditService,
  ) {}

  async findAll(): Promise<MeasurementUnitRecord[]> {
    const res = await this.db.query<{
      id: string;
      name: string;
      symbol: string;
      created_at: Date;
    }>('SELECT * FROM measurement_units ORDER BY symbol ASC');

    return res.rows.map((r) => ({
      id: r.id,
      name: r.name,
      symbol: r.symbol,
      createdAt: r.created_at,
    }));
  }

  async findById(id: string): Promise<MeasurementUnitRecord> {
    const res = await this.db.query<{
      id: string;
      name: string;
      symbol: string;
      created_at: Date;
    }>('SELECT * FROM measurement_units WHERE id = $1', [id]);

    const unit = res.rows[0];
    if (!unit) {
      throw new NotFoundError('MeasurementUnit', id);
    }

    return {
      id: unit.id,
      name: unit.name,
      symbol: unit.symbol,
      createdAt: unit.created_at,
    };
  }

  async create(
    dto: CreateUnitDto,
    userId?: string,
    correlationId?: string,
  ): Promise<MeasurementUnitRecord> {
    const existing = await this.db.query(
      'SELECT 1 FROM measurement_units WHERE UPPER(symbol) = UPPER($1)',
      [dto.symbol.trim()],
    );
    if (existing.rowCount && existing.rowCount > 0) {
      throw new ConflictError(`Unit symbol "${dto.symbol}" already exists`);
    }

    const res = await this.db.query<{
      id: string;
      name: string;
      symbol: string;
      created_at: Date;
    }>(
      `INSERT INTO measurement_units (name, symbol)
       VALUES ($1, $2)
       RETURNING id, name, symbol, created_at`,
      [dto.name.trim(), dto.symbol.trim().toUpperCase()],
    );

    const record = res.rows[0];

    await this.auditService.log({
      userId,
      userName: 'User',
      action: 'UNIT_CREATE',
      entityType: 'UNIT',
      entityId: record.id,
      afterSnapshot: { ...dto },
      correlationId,
    });

    return {
      id: record.id,
      name: record.name,
      symbol: record.symbol,
      createdAt: record.created_at,
    };
  }

  async delete(
    id: string,
    userId?: string,
    correlationId?: string,
  ): Promise<{ success: boolean }> {
    await this.findById(id);

    await this.db.query('DELETE FROM measurement_units WHERE id = $1', [id]);

    await this.auditService.log({
      userId,
      userName: 'User',
      action: 'UNIT_DELETE',
      entityType: 'UNIT',
      entityId: id,
      correlationId,
    });

    return { success: true };
  }
}
