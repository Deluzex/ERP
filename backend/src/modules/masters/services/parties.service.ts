import { Injectable } from '@nestjs/common';
import { AuditService } from '../../../core/audit/audit.service';
import { Money } from '../../../core/common/money';
import { DatabasePool } from '../../../core/database/connection';
import { UnitOfWork } from '../../../core/database/unit-of-work';
import { NotFoundError } from '../../../core/errors/not-found.error';
import {
  CreateArchitectDto,
  LinkArchitectCustomerDto,
  UpdateArchitectDto,
} from '../dto/architect.dto';
import { CreateCustomerDto, UpdateCustomerDto } from '../dto/customer.dto';
import { CreateDealerDto, UpdateDealerDto } from '../dto/dealer.dto';

export interface CustomerRecord {
  id: string;
  name: string;
  mobile: string;
  email: string;
  gstNumber: string | null;
  address: string;
  stateCode: string;
  outstandingAmount: string;
  creditBalance: string;
  linkedArchitectId: string | null;
  isAlsoArchitect: boolean;
  isDeleted: boolean;
  createdAt: Date;
  updatedAt: Date;
}

export interface DealerRecord {
  id: string;
  name: string;
  contactPerson: string;
  companyName: string;
  mobile: string;
  email: string;
  gstNumber: string;
  address: string;
  stateCode: string;
  outstandingAmount: string;
  isDeleted: boolean;
  createdAt: Date;
  updatedAt: Date;
}

export interface ArchitectRecord {
  id: string;
  name: string;
  companyName: string;
  mobile: string;
  email: string;
  gstNumber: string | null;
  address: string;
  defaultCommissionRate: number;
  totalCommissionEarned: string;
  pendingCommission: string;
  approvedCommission: string;
  paidCommission: string;
  linkedCustomerId: string | null;
  isAlsoCustomer: boolean;
  isDeleted: boolean;
  createdAt: Date;
  updatedAt: Date;
}

@Injectable()
export class PartiesService {
  constructor(
    private readonly db: DatabasePool,
    private readonly uow: UnitOfWork,
    private readonly auditService: AuditService,
  ) {}

  // -------------------------------------------------------------
  // CUSTOMERS
  // -------------------------------------------------------------
  async findAllCustomers(search?: string, isAlsoArchitect?: boolean): Promise<CustomerRecord[]> {
    const conditions: string[] = ['is_deleted = false'];
    const values: unknown[] = [];
    let idx = 1;

    if (isAlsoArchitect !== undefined) {
      conditions.push(`is_also_architect = $${idx++}`);
      values.push(isAlsoArchitect);
    }

    if (search && search.trim().length > 0) {
      conditions.push(`(name ILIKE $${idx} OR mobile ILIKE $${idx} OR email ILIKE $${idx})`);
      values.push(`%${search.trim()}%`);
      idx++;
    }

    const res = await this.db.query(
      `SELECT * FROM customers WHERE ${conditions.join(' AND ')} ORDER BY name ASC`,
      values,
    );

    return res.rows.map((r: any) => ({
      id: r.id,
      name: r.name,
      mobile: r.mobile,
      email: r.email,
      gstNumber: r.gst_number,
      address: r.address,
      stateCode: r.state_code,
      outstandingAmount: Money.format(r.outstanding_amount),
      creditBalance: Money.format(r.credit_balance),
      linkedArchitectId: r.linked_architect_id,
      isAlsoArchitect: r.is_also_architect,
      isDeleted: r.is_deleted,
      createdAt: r.created_at,
      updatedAt: r.updated_at,
    }));
  }

  async findCustomerById(id: string): Promise<CustomerRecord> {
    const res = await this.db.query('SELECT * FROM customers WHERE id = $1', [id]);
    const r = res.rows[0];
    if (!r) throw new NotFoundError('Customer', id);

    return {
      id: r.id,
      name: r.name,
      mobile: r.mobile,
      email: r.email,
      gstNumber: r.gst_number,
      address: r.address,
      stateCode: r.state_code,
      outstandingAmount: Money.format(r.outstanding_amount),
      creditBalance: Money.format(r.credit_balance),
      linkedArchitectId: r.linked_architect_id,
      isAlsoArchitect: r.is_also_architect,
      isDeleted: r.is_deleted,
      createdAt: r.created_at,
      updatedAt: r.updated_at,
    };
  }

  async createCustomer(dto: CreateCustomerDto, userId?: string, correlationId?: string): Promise<CustomerRecord> {
    const res = await this.db.query<{ id: string }>(
      `INSERT INTO customers (
        name, mobile, email, gst_number, address, state_code,
        linked_architect_id, is_also_architect
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
      RETURNING id`,
      [
        dto.name.trim(),
        dto.mobile.trim(),
        dto.email.trim().toLowerCase(),
        dto.gstNumber?.trim().toUpperCase() || null,
        dto.address.trim(),
        dto.stateCode || '24',
        dto.linkedArchitectId || null,
        dto.isAlsoArchitect || false,
      ],
    );

    const record = await this.findCustomerById(res.rows[0].id);

    await this.auditService.log({
      userId,
      userName: 'User',
      action: 'CUSTOMER_CREATE',
      entityType: 'CUSTOMER',
      entityId: record.id,
      afterSnapshot: { ...dto },
      correlationId,
    });

    return record;
  }

  async updateCustomer(id: string, dto: UpdateCustomerDto, userId?: string, correlationId?: string): Promise<CustomerRecord> {
    const existing = await this.findCustomerById(id);
    const updates: string[] = [];
    const values: unknown[] = [];
    let idx = 1;

    if (dto.name !== undefined) { updates.push(`name = $${idx++}`); values.push(dto.name.trim()); }
    if (dto.mobile !== undefined) { updates.push(`mobile = $${idx++}`); values.push(dto.mobile.trim()); }
    if (dto.email !== undefined) { updates.push(`email = $${idx++}`); values.push(dto.email.trim().toLowerCase()); }
    if (dto.gstNumber !== undefined) { updates.push(`gst_number = $${idx++}`); values.push(dto.gstNumber.trim().toUpperCase()); }
    if (dto.address !== undefined) { updates.push(`address = $${idx++}`); values.push(dto.address.trim()); }
    if (dto.stateCode !== undefined) { updates.push(`state_code = $${idx++}`); values.push(dto.stateCode); }
    if (dto.linkedArchitectId !== undefined) { updates.push(`linked_architect_id = $${idx++}`); values.push(dto.linkedArchitectId); }
    if (dto.isAlsoArchitect !== undefined) { updates.push(`is_also_architect = $${idx++}`); values.push(dto.isAlsoArchitect); }

    if (updates.length > 0) {
      updates.push('updated_at = NOW()');
      values.push(id);
      await this.db.query(`UPDATE customers SET ${updates.join(', ')} WHERE id = $${idx}`, values);
    }

    await this.auditService.log({
      userId,
      userName: 'User',
      action: 'CUSTOMER_UPDATE',
      entityType: 'CUSTOMER',
      entityId: id,
      beforeSnapshot: existing as any,
      afterSnapshot: { ...existing, ...dto },
      correlationId,
    });

    return this.findCustomerById(id);
  }

  async deleteCustomer(id: string, userId?: string, correlationId?: string): Promise<{ success: boolean }> {
    await this.findCustomerById(id);
    await this.db.query('UPDATE customers SET is_deleted = true, updated_at = NOW() WHERE id = $1', [id]);
    await this.auditService.log({ userId, userName: 'User', action: 'CUSTOMER_DELETE', entityType: 'CUSTOMER', entityId: id, correlationId });
    return { success: true };
  }

  // -------------------------------------------------------------
  // DEALERS
  // -------------------------------------------------------------
  async findAllDealers(search?: string): Promise<DealerRecord[]> {
    const conditions: string[] = ['is_deleted = false'];
    const values: unknown[] = [];
    let idx = 1;

    if (search && search.trim().length > 0) {
      conditions.push(`(name ILIKE $${idx} OR company_name ILIKE $${idx} OR mobile ILIKE $${idx})`);
      values.push(`%${search.trim()}%`);
      idx++;
    }

    const res = await this.db.query(
      `SELECT * FROM dealers WHERE ${conditions.join(' AND ')} ORDER BY name ASC`,
      values,
    );

    return res.rows.map((r: any) => ({
      id: r.id,
      name: r.name,
      contactPerson: r.contact_person,
      companyName: r.company_name,
      mobile: r.mobile,
      email: r.email,
      gstNumber: r.gst_number,
      address: r.address,
      stateCode: r.state_code,
      outstandingAmount: Money.format(r.outstanding_amount),
      isDeleted: r.is_deleted,
      createdAt: r.created_at,
      updatedAt: r.updated_at,
    }));
  }

  async findDealerById(id: string): Promise<DealerRecord> {
    const res = await this.db.query('SELECT * FROM dealers WHERE id = $1', [id]);
    const r = res.rows[0];
    if (!r) throw new NotFoundError('Dealer', id);

    return {
      id: r.id,
      name: r.name,
      contactPerson: r.contact_person,
      companyName: r.company_name,
      mobile: r.mobile,
      email: r.email,
      gstNumber: r.gst_number,
      address: r.address,
      stateCode: r.state_code,
      outstandingAmount: Money.format(r.outstanding_amount),
      isDeleted: r.is_deleted,
      createdAt: r.created_at,
      updatedAt: r.updated_at,
    };
  }

  async createDealer(dto: CreateDealerDto, userId?: string, correlationId?: string): Promise<DealerRecord> {
    const res = await this.db.query<{ id: string }>(
      `INSERT INTO dealers (
        name, contact_person, company_name, mobile, email, gst_number, address, state_code
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
      RETURNING id`,
      [
        dto.name.trim(),
        dto.contactPerson.trim(),
        dto.companyName.trim(),
        dto.mobile.trim(),
        dto.email.trim().toLowerCase(),
        dto.gstNumber ? dto.gstNumber.trim().toUpperCase() : '',
        dto.address.trim(),
        dto.stateCode || '24',
      ],
    );

    const record = await this.findDealerById(res.rows[0].id);

    await this.auditService.log({
      userId,
      userName: 'User',
      action: 'DEALER_CREATE',
      entityType: 'DEALER',
      entityId: record.id,
      afterSnapshot: { ...dto },
      correlationId,
    });

    return record;
  }

  async updateDealer(id: string, dto: UpdateDealerDto, userId?: string, correlationId?: string): Promise<DealerRecord> {
    const existing = await this.findDealerById(id);
    const updates: string[] = [];
    const values: unknown[] = [];
    let idx = 1;

    if (dto.name !== undefined) { updates.push(`name = $${idx++}`); values.push(dto.name.trim()); }
    if (dto.contactPerson !== undefined) { updates.push(`contact_person = $${idx++}`); values.push(dto.contactPerson.trim()); }
    if (dto.companyName !== undefined) { updates.push(`company_name = $${idx++}`); values.push(dto.companyName.trim()); }
    if (dto.mobile !== undefined) { updates.push(`mobile = $${idx++}`); values.push(dto.mobile.trim()); }
    if (dto.email !== undefined) { updates.push(`email = $${idx++}`); values.push(dto.email.trim().toLowerCase()); }
    if (dto.gstNumber !== undefined) { updates.push(`gst_number = $${idx++}`); values.push(dto.gstNumber ? dto.gstNumber.trim().toUpperCase() : ''); }
    if (dto.address !== undefined) { updates.push(`address = $${idx++}`); values.push(dto.address.trim()); }
    if (dto.stateCode !== undefined) { updates.push(`state_code = $${idx++}`); values.push(dto.stateCode); }

    if (updates.length > 0) {
      updates.push('updated_at = NOW()');
      values.push(id);
      await this.db.query(`UPDATE dealers SET ${updates.join(', ')} WHERE id = $${idx}`, values);
    }

    await this.auditService.log({
      userId,
      userName: 'User',
      action: 'DEALER_UPDATE',
      entityType: 'DEALER',
      entityId: id,
      beforeSnapshot: existing as any,
      afterSnapshot: { ...existing, ...dto },
      correlationId,
    });

    return this.findDealerById(id);
  }

  async deleteDealer(id: string, userId?: string, correlationId?: string): Promise<{ success: boolean }> {
    await this.findDealerById(id);
    await this.db.query('UPDATE dealers SET is_deleted = true, updated_at = NOW() WHERE id = $1', [id]);
    await this.auditService.log({ userId, userName: 'User', action: 'DEALER_DELETE', entityType: 'DEALER', entityId: id, correlationId });
    return { success: true };
  }

  // -------------------------------------------------------------
  // ARCHITECTS
  // -------------------------------------------------------------
  async findAllArchitects(search?: string): Promise<ArchitectRecord[]> {
    const conditions: string[] = ['is_deleted = false'];
    const values: unknown[] = [];
    let idx = 1;

    if (search && search.trim().length > 0) {
      conditions.push(`(name ILIKE $${idx} OR company_name ILIKE $${idx} OR mobile ILIKE $${idx})`);
      values.push(`%${search.trim()}%`);
      idx++;
    }

    const res = await this.db.query(
      `SELECT * FROM architects WHERE ${conditions.join(' AND ')} ORDER BY name ASC`,
      values,
    );

    return res.rows.map((r: any) => ({
      id: r.id,
      name: r.name,
      companyName: r.company_name,
      mobile: r.mobile,
      email: r.email,
      gstNumber: r.gst_number,
      address: r.address,
      defaultCommissionRate: parseFloat(r.default_commission_rate) || 5.0,
      totalCommissionEarned: Money.format(r.total_commission_earned),
      pendingCommission: Money.format(r.pending_commission),
      approvedCommission: Money.format(r.approved_commission),
      paidCommission: Money.format(r.paid_commission),
      linkedCustomerId: r.linked_customer_id,
      isAlsoCustomer: r.is_also_customer,
      isDeleted: r.is_deleted,
      createdAt: r.created_at,
      updatedAt: r.updated_at,
    }));
  }

  async findArchitectById(id: string): Promise<ArchitectRecord> {
    const res = await this.db.query('SELECT * FROM architects WHERE id = $1', [id]);
    const r = res.rows[0];
    if (!r) throw new NotFoundError('Architect', id);

    return {
      id: r.id,
      name: r.name,
      companyName: r.company_name,
      mobile: r.mobile,
      email: r.email,
      gstNumber: r.gst_number,
      address: r.address,
      defaultCommissionRate: parseFloat(r.default_commission_rate) || 5.0,
      totalCommissionEarned: Money.format(r.total_commission_earned),
      pendingCommission: Money.format(r.pending_commission),
      approvedCommission: Money.format(r.approved_commission),
      paidCommission: Money.format(r.paid_commission),
      linkedCustomerId: r.linked_customer_id,
      isAlsoCustomer: r.is_also_customer,
      isDeleted: r.is_deleted,
      createdAt: r.created_at,
      updatedAt: r.updated_at,
    };
  }

  async createArchitect(dto: CreateArchitectDto, userId?: string, correlationId?: string): Promise<ArchitectRecord> {
    const res = await this.db.query<{ id: string }>(
      `INSERT INTO architects (
        name, company_name, mobile, email, gst_number, address,
        default_commission_rate, linked_customer_id, is_also_customer
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
      RETURNING id`,
      [
        dto.name.trim(),
        dto.companyName.trim(),
        dto.mobile.trim(),
        dto.email.trim().toLowerCase(),
        dto.gstNumber?.trim().toUpperCase() || null,
        dto.address.trim(),
        dto.defaultCommissionRate ?? 5.0,
        dto.linkedCustomerId || null,
        dto.isAlsoCustomer || false,
      ],
    );

    const record = await this.findArchitectById(res.rows[0].id);

    await this.auditService.log({
      userId,
      userName: 'User',
      action: 'ARCHITECT_CREATE',
      entityType: 'ARCHITECT',
      entityId: record.id,
      afterSnapshot: { ...dto },
      correlationId,
    });

    return record;
  }

  async updateArchitect(id: string, dto: UpdateArchitectDto, userId?: string, correlationId?: string): Promise<ArchitectRecord> {
    const existing = await this.findArchitectById(id);
    const updates: string[] = [];
    const values: unknown[] = [];
    let idx = 1;

    if (dto.name !== undefined) { updates.push(`name = $${idx++}`); values.push(dto.name.trim()); }
    if (dto.companyName !== undefined) { updates.push(`company_name = $${idx++}`); values.push(dto.companyName.trim()); }
    if (dto.mobile !== undefined) { updates.push(`mobile = $${idx++}`); values.push(dto.mobile.trim()); }
    if (dto.email !== undefined) { updates.push(`email = $${idx++}`); values.push(dto.email.trim().toLowerCase()); }
    if (dto.gstNumber !== undefined) { updates.push(`gst_number = $${idx++}`); values.push(dto.gstNumber.trim().toUpperCase()); }
    if (dto.address !== undefined) { updates.push(`address = $${idx++}`); values.push(dto.address.trim()); }
    if (dto.defaultCommissionRate !== undefined) { updates.push(`default_commission_rate = $${idx++}`); values.push(dto.defaultCommissionRate); }
    if (dto.linkedCustomerId !== undefined) { updates.push(`linked_customer_id = $${idx++}`); values.push(dto.linkedCustomerId); }
    if (dto.isAlsoCustomer !== undefined) { updates.push(`is_also_customer = $${idx++}`); values.push(dto.isAlsoCustomer); }

    if (updates.length > 0) {
      updates.push('updated_at = NOW()');
      values.push(id);
      await this.db.query(`UPDATE architects SET ${updates.join(', ')} WHERE id = $${idx}`, values);
    }

    await this.auditService.log({
      userId,
      userName: 'User',
      action: 'ARCHITECT_UPDATE',
      entityType: 'ARCHITECT',
      entityId: id,
      beforeSnapshot: existing as any,
      afterSnapshot: { ...existing, ...dto },
      correlationId,
    });

    return this.findArchitectById(id);
  }

  async deleteArchitect(id: string, userId?: string, correlationId?: string): Promise<{ success: boolean }> {
    await this.findArchitectById(id);
    await this.db.query('UPDATE architects SET is_deleted = true, updated_at = NOW() WHERE id = $1', [id]);
    await this.auditService.log({ userId, userName: 'User', action: 'ARCHITECT_DELETE', entityType: 'ARCHITECT', entityId: id, correlationId });
    return { success: true };
  }

  // -------------------------------------------------------------
  // DUAL IDENTITY LINKING
  // -------------------------------------------------------------
  async linkArchitectAndCustomer(dto: LinkArchitectCustomerDto, userId?: string, correlationId?: string): Promise<{ success: boolean }> {
    await this.findArchitectById(dto.architectId);
    await this.findCustomerById(dto.customerId);

    await this.uow.runInTransaction(async (client) => {
      await client.query(
        'UPDATE architects SET linked_customer_id = $1, is_also_customer = true, updated_at = NOW() WHERE id = $2',
        [dto.customerId, dto.architectId],
      );
      await client.query(
        'UPDATE customers SET linked_architect_id = $1, is_also_architect = true, updated_at = NOW() WHERE id = $2',
        [dto.architectId, dto.customerId],
      );

      await this.auditService.log({
        userId,
        userName: 'User',
        action: 'ARCHITECT_CUSTOMER_LINK',
        entityType: 'DUAL_IDENTITY',
        entityId: dto.architectId,
        afterSnapshot: { architectId: dto.architectId, customerId: dto.customerId },
        correlationId,
      });
    });

    return { success: true };
  }
}
