import { Injectable } from '@nestjs/common';
import { AuditService } from '../../../core/audit/audit.service';
import { Money } from '../../../core/common/money';
import { DatabasePool } from '../../../core/database/connection';
import { ConflictError } from '../../../core/errors/conflict.error';
import { NotFoundError } from '../../../core/errors/not-found.error';
import {
  CreateVendorDto,
  DeleteVendorDto,
  UpdateVendorDto,
} from '../dto/vendor.dto';

export interface VendorRecord {
  id: string;
  name: string;
  contactPerson: string;
  mobile: string;
  email: string;
  gstNumber: string;
  panNumber: string;
  address: string;
  paymentTerms: string;
  creditLimit: string;
  outstandingBalance: string;
  isDeleted: boolean;
  deleteReason: string | null;
  deletedAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
}

@Injectable()
export class VendorsService {
  constructor(
    private readonly db: DatabasePool,
    private readonly auditService: AuditService,
  ) {}

  async findAll(search?: string, includeDeleted = false): Promise<VendorRecord[]> {
    const conditions: string[] = [];
    const values: unknown[] = [];
    let idx = 1;

    if (!includeDeleted) {
      conditions.push('is_deleted = false');
    }

    if (search && search.trim().length > 0) {
      conditions.push(
        `(name ILIKE $${idx} OR contact_person ILIKE $${idx} OR mobile ILIKE $${idx} OR gst_number ILIKE $${idx})`,
      );
      values.push(`%${search.trim()}%`);
      idx++;
    }

    const whereClause = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';

    const res = await this.db.query<{
      id: string;
      name: string;
      contact_person: string;
      mobile: string;
      email: string;
      gst_number: string;
      pan_number: string;
      address: string;
      payment_terms: string;
      credit_limit: string;
      outstanding_balance: string;
      is_deleted: boolean;
      delete_reason: string | null;
      deleted_at: Date | null;
      created_at: Date;
      updated_at: Date;
    }>(
      `SELECT * FROM vendors ${whereClause} ORDER BY name ASC`,
      values,
    );

    return res.rows.map((r) => this.mapRow(r));
  }

  async findById(id: string): Promise<VendorRecord> {
    const res = await this.db.query<{
      id: string;
      name: string;
      contact_person: string;
      mobile: string;
      email: string;
      gst_number: string;
      pan_number: string;
      address: string;
      payment_terms: string;
      credit_limit: string;
      outstanding_balance: string;
      is_deleted: boolean;
      delete_reason: string | null;
      deleted_at: Date | null;
      created_at: Date;
      updated_at: Date;
    }>('SELECT * FROM vendors WHERE id = $1', [id]);

    const row = res.rows[0];
    if (!row) {
      throw new NotFoundError('Vendor', id);
    }

    return this.mapRow(row);
  }

  async create(
    dto: CreateVendorDto,
    userId?: string,
    correlationId?: string,
  ): Promise<VendorRecord> {
    const existing = await this.db.query(
      'SELECT 1 FROM vendors WHERE UPPER(gst_number) = UPPER($1) AND is_deleted = false',
      [dto.gstNumber.trim()],
    );
    if (existing.rowCount && existing.rowCount > 0) {
      throw new ConflictError(`Active vendor with GST "${dto.gstNumber}" already exists`);
    }

    const creditLimit = Money.format(dto.creditLimit ?? 500000);

    const res = await this.db.query<{
      id: string;
      name: string;
      contact_person: string;
      mobile: string;
      email: string;
      gst_number: string;
      pan_number: string;
      address: string;
      payment_terms: string;
      credit_limit: string;
      outstanding_balance: string;
      is_deleted: boolean;
      delete_reason: string | null;
      deleted_at: Date | null;
      created_at: Date;
      updated_at: Date;
    }>(
      `INSERT INTO vendors (
        name, contact_person, mobile, email, gst_number, pan_number,
        address, payment_terms, credit_limit, outstanding_balance
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, '0.00')
      RETURNING *`,
      [
        dto.name.trim(),
        dto.contactPerson.trim(),
        dto.mobile.trim(),
        dto.email.trim().toLowerCase(),
        dto.gstNumber.trim().toUpperCase(),
        dto.panNumber.trim().toUpperCase(),
        dto.address.trim(),
        dto.paymentTerms || 'Net 30 Days',
        creditLimit,
      ],
    );

    const record = this.mapRow(res.rows[0]);

    await this.auditService.log({
      userId,
      userName: 'User',
      action: 'VENDOR_CREATE',
      entityType: 'VENDOR',
      entityId: record.id,
      afterSnapshot: { ...dto },
      correlationId,
    });

    return record;
  }

  async update(
    id: string,
    dto: UpdateVendorDto,
    userId?: string,
    correlationId?: string,
  ): Promise<VendorRecord> {
    const existing = await this.findById(id);

    const updates: string[] = [];
    const values: unknown[] = [];
    let idx = 1;

    if (dto.name !== undefined) {
      updates.push(`name = $${idx++}`);
      values.push(dto.name.trim());
    }
    if (dto.contactPerson !== undefined) {
      updates.push(`contact_person = $${idx++}`);
      values.push(dto.contactPerson.trim());
    }
    if (dto.mobile !== undefined) {
      updates.push(`mobile = $${idx++}`);
      values.push(dto.mobile.trim());
    }
    if (dto.email !== undefined) {
      updates.push(`email = $${idx++}`);
      values.push(dto.email.trim().toLowerCase());
    }
    if (dto.gstNumber !== undefined) {
      updates.push(`gst_number = $${idx++}`);
      values.push(dto.gstNumber.trim().toUpperCase());
    }
    if (dto.panNumber !== undefined) {
      updates.push(`pan_number = $${idx++}`);
      values.push(dto.panNumber.trim().toUpperCase());
    }
    if (dto.address !== undefined) {
      updates.push(`address = $${idx++}`);
      values.push(dto.address.trim());
    }
    if (dto.paymentTerms !== undefined) {
      updates.push(`payment_terms = $${idx++}`);
      values.push(dto.paymentTerms.trim());
    }
    if (dto.creditLimit !== undefined) {
      updates.push(`credit_limit = $${idx++}`);
      values.push(Money.format(dto.creditLimit));
    }

    if (updates.length > 0) {
      updates.push(`updated_at = NOW()`);
      values.push(id);
      await this.db.query(
        `UPDATE vendors SET ${updates.join(', ')} WHERE id = $${idx}`,
        values,
      );
    }

    await this.auditService.log({
      userId,
      userName: 'User',
      action: 'VENDOR_UPDATE',
      entityType: 'VENDOR',
      entityId: id,
      beforeSnapshot: existing as any,
      afterSnapshot: { ...existing, ...dto },
      correlationId,
    });

    return this.findById(id);
  }

  async delete(
    id: string,
    dto?: DeleteVendorDto,
    userId?: string,
    correlationId?: string,
  ): Promise<{ success: boolean }> {
    await this.findById(id);

    await this.db.query(
      `UPDATE vendors
       SET is_deleted = true,
           delete_reason = $1,
           deleted_at = NOW(),
           updated_at = NOW()
       WHERE id = $2`,
      [dto?.deleteReason || null, id],
    );

    await this.auditService.log({
      userId,
      userName: 'User',
      action: 'VENDOR_SOFT_DELETE',
      entityType: 'VENDOR',
      entityId: id,
      reason: dto?.deleteReason,
      correlationId,
    });

    return { success: true };
  }

  private mapRow(r: any): VendorRecord {
    return {
      id: r.id,
      name: r.name,
      contactPerson: r.contact_person,
      mobile: r.mobile,
      email: r.email,
      gstNumber: r.gst_number,
      panNumber: r.pan_number,
      address: r.address,
      paymentTerms: r.payment_terms,
      creditLimit: Money.format(r.credit_limit),
      outstandingBalance: Money.format(r.outstanding_balance),
      isDeleted: r.is_deleted,
      deleteReason: r.delete_reason,
      deletedAt: r.deleted_at,
      createdAt: r.created_at,
      updatedAt: r.updated_at,
    };
  }
}
