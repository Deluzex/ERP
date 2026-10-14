import { BadRequestException, Injectable } from '@nestjs/common';
import { AuditService } from '../../../core/audit/audit.service';
import { DatabasePool } from '../../../core/database/connection';
import { UnitOfWork } from '../../../core/database/unit-of-work';
import { NotFoundError } from '../../../core/errors/not-found.error';
import { CreatePaymentDto } from '../dto/create-payment.dto';
import {
  CommissionQueryDto,
  DisburseCommissionDto,
  PaymentQueryDto,
  RejectCommissionDto,
} from '../dto/payment-query.dto';

@Injectable()
export class PaymentsService {
  constructor(
    private readonly db: DatabasePool,
    private readonly uow: UnitOfWork,
    private readonly auditService: AuditService,
  ) {}

  // --------------------------------------------------------------------------
  // 11.1 List Payments & Receipts
  // --------------------------------------------------------------------------
  async findAll(query: PaymentQueryDto) {
    const page = Math.max(1, query.page || 1);
    const limit = Math.max(1, query.limit || 50);
    const offset = (page - 1) * limit;

    const conditions: string[] = ['1=1'];
    const params: any[] = [];
    let pIdx = 1;

    if (query.paymentType) {
      conditions.push(`p.payment_type = $${pIdx}`);
      params.push(query.paymentType);
      pIdx++;
    }

    if (query.partyId) {
      conditions.push(`p.party_id = $${pIdx}`);
      params.push(query.partyId);
      pIdx++;
    }

    if (query.paymentMode) {
      conditions.push(`p.payment_mode = $${pIdx}`);
      params.push(query.paymentMode);
      pIdx++;
    }

    if (query.referenceDocumentId) {
      conditions.push(`p.reference_document_id = $${pIdx}`);
      params.push(query.referenceDocumentId);
      pIdx++;
    }

    if (query.projectId) {
      conditions.push(`p.project_id = $${pIdx}`);
      params.push(query.projectId);
      pIdx++;
    }

    if (query.startDate) {
      conditions.push(`p.payment_date >= $${pIdx}`);
      params.push(query.startDate);
      pIdx++;
    }

    if (query.endDate) {
      conditions.push(`p.payment_date <= $${pIdx}`);
      params.push(query.endDate);
      pIdx++;
    }

    if (query.search) {
      conditions.push(
        `(p.payment_number ILIKE $${pIdx} OR p.party_name ILIKE $${pIdx} OR p.notes ILIKE $${pIdx} OR p.transaction_reference ILIKE $${pIdx})`,
      );
      params.push(`%${query.search}%`);
      pIdx++;
    }

    const whereClause = conditions.join(' AND ');

    // Count query
    const countRes = await this.db.query<{ count: string }>(
      `SELECT COUNT(*) as count FROM payments p WHERE ${whereClause}`,
      params,
    );
    const total = parseInt(countRes.rows[0]?.count || '0', 10);

    // Summary statistics query
    const summaryRes = await this.db.query<{
      customer_total: string;
      dealer_total: string;
      vendor_total: string;
      commission_total: string;
    }>(
      `SELECT 
         COALESCE(SUM(CASE WHEN payment_type = 'customerPayment' THEN amount ELSE 0 END), 0) as customer_total,
         COALESCE(SUM(CASE WHEN payment_type = 'dealerPayment' THEN amount ELSE 0 END), 0) as dealer_total,
         COALESCE(SUM(CASE WHEN payment_type = 'vendorPayment' THEN amount ELSE 0 END), 0) as vendor_total,
         COALESCE(SUM(CASE WHEN payment_type = 'commissionPayment' THEN amount ELSE 0 END), 0) as commission_total
       FROM payments p
       WHERE ${whereClause}`,
      params,
    );

    // Data query
    const dataRes = await this.db.query<any>(
      `SELECT 
         p.id,
         p.payment_number,
         p.payment_type,
         p.party_id,
         p.party_name,
         p.reference_document_id,
         p.reference_document_number,
         p.amount,
         p.discount,
         p.payment_mode,
         p.payment_date,
         p.transaction_reference,
         p.notes,
         p.payment_status,
         p.attachment_url,
         p.is_full_payment,
         p.total_document_amount,
         p.remaining_amount,
         p.project_id,
         p.project_name,
         p.created_at,
         p.updated_at
       FROM payments p
       WHERE ${whereClause}
       ORDER BY p.payment_date DESC, p.created_at DESC
       LIMIT $${pIdx} OFFSET $${pIdx + 1}`,
      [...params, limit, offset],
    );

    return {
      data: dataRes.rows.map(this.mapPaymentRow),
      meta: {
        total,
        page,
        limit,
        totalPages: Math.ceil(total / limit),
        summary: {
          totalCustomerReceipts: summaryRes.rows[0]?.customer_total || '0.00',
          totalDealerCollections: summaryRes.rows[0]?.dealer_total || '0.00',
          totalVendorPayments: summaryRes.rows[0]?.vendor_total || '0.00',
          totalCommissionPayouts: summaryRes.rows[0]?.commission_total || '0.00',
        },
      },
    };
  }

  // --------------------------------------------------------------------------
  // Get Payment by ID
  // --------------------------------------------------------------------------
  async findById(id: string) {
    const res = await this.db.query<any>(
      `SELECT * FROM payments WHERE id = $1`,
      [id],
    );
    if (!res.rows.length) {
      throw new NotFoundError(`Payment with ID "${id}" was not found`);
    }
    return this.mapPaymentRow(res.rows[0]);
  }

  // --------------------------------------------------------------------------
  // 11.2 Record Payment Voucher with Atomic Rebalancing
  // --------------------------------------------------------------------------
  async recordPayment(dto: CreatePaymentDto, userId?: string, correlationId?: string) {
    const discount = dto.discount || 0;
    const totalDeduction = dto.amount + discount;
    if (totalDeduction <= 0) {
      throw new BadRequestException('Payment amount or discount must be greater than zero');
    }

    return this.uow.runInTransaction(async (client) => {
      // 1. Generate sequential payment number
      const seqRes = await client.query<{ nextval: string }>(
        `SELECT nextval('seq_payment_number') as nextval`,
      );
      const seq = seqRes.rows[0].nextval;
      const year = new Date().getFullYear();
      const paymentNumber = `PAY-${year}-${seq.padStart(4, '0')}`;

      // 2. Insert Payment Voucher
      const payRes = await client.query<any>(
        `INSERT INTO payments (
           payment_number,
           payment_type,
           party_id,
           party_name,
           reference_document_id,
           reference_document_number,
           amount,
           discount,
           payment_mode,
           payment_date,
           transaction_reference,
           notes,
           payment_status,
           is_full_payment,
           total_document_amount,
           remaining_amount,
           project_id,
           project_name,
           created_by
         )
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, COALESCE($10, now()), $11, $12, 'completed', $13, $14, $15, $16, $17, $18)
         RETURNING *`,
        [
          paymentNumber,
          dto.paymentType,
          dto.partyId,
          dto.partyName,
          dto.referenceDocumentId || null,
          dto.referenceDocumentNumber || null,
          dto.amount,
          discount,
          dto.paymentMode,
          dto.paymentDate || null,
          dto.transactionReference || null,
          dto.notes || null,
          dto.isFullPayment ?? false,
          dto.totalDocumentAmount ?? null,
          dto.remainingAmount ?? null,
          dto.projectId || null,
          dto.projectName || null,
          userId || null,
        ],
      );
      const paymentRecord = payRes.rows[0];

      // 3. Atomic Balancing by Payment Type
      if (dto.paymentType === 'customerPayment') {
        // Update Customer Ledger Outstanding
        await client.query(
          `UPDATE customers
           SET outstanding_amount = GREATEST(0.00, COALESCE(outstanding_amount, 0) - $1),
               updated_at = now()
           WHERE id = $2`,
          [totalDeduction, dto.partyId],
        );

        // If linked to a Tax Invoice / Sale, update invoice paid/pending balances
        if (dto.referenceDocumentId) {
          const invRes = await client.query<any>(
            `SELECT id, total_amount, paid_amount, pending_amount, discount_amount 
             FROM sales 
             WHERE id = $1 FOR UPDATE`,
            [dto.referenceDocumentId],
          );
          if (invRes.rows.length) {
            const currentPaid = parseFloat(invRes.rows[0].paid_amount || '0');
            const totalAmount = parseFloat(invRes.rows[0].total_amount || '0');
            const currentDiscount = parseFloat(invRes.rows[0].discount_amount || '0');
            const newPaid = currentPaid + dto.amount;
            const newDiscount = currentDiscount + discount;
            const newPending = Math.max(0, totalAmount - newPaid - newDiscount);
            const newStatus = newPending <= 0 ? 'paid' : 'partialPaid';

            await client.query(
              `UPDATE sales
               SET paid_amount = $1,
                   discount_amount = $2,
                   pending_amount = $3,
                   status = $4,
                   updated_at = now()
               WHERE id = $5`,
              [newPaid, newDiscount, newPending, newStatus, dto.referenceDocumentId],
            );
          }
        } else {
          // FIFO auto-reconciliation against unpaid sales invoices
          const unpaidSales = await client.query<any>(
            `SELECT id, total_amount, paid_amount, pending_amount, discount_amount 
             FROM sales 
             WHERE party_id = $1 AND pending_amount > 0 AND document_type IN ('invoice', 'salesOrder')
             ORDER BY sale_date ASC, created_at ASC 
             FOR UPDATE`,
            [dto.partyId],
          );
          let remAmt = dto.amount;
          let remDisc = discount;
          for (const inv of unpaidSales.rows) {
            if (remAmt <= 0 && remDisc <= 0) break;
            const curPaid = parseFloat(inv.paid_amount || '0');
            const totAmt = parseFloat(inv.total_amount || '0');
            const curDisc = parseFloat(inv.discount_amount || '0');
            const curPending = parseFloat(inv.pending_amount || '0');

            const applyDisc = Math.min(remDisc, curPending);
            const applyAmt = Math.min(remAmt, curPending - applyDisc);

            const newPaid = curPaid + applyAmt;
            const newDisc = curDisc + applyDisc;
            const newPending = Math.max(0, totAmt - newPaid - newDisc);
            const newStatus = newPending <= 0 ? 'paid' : 'partialPaid';

            await client.query(
              `UPDATE sales
               SET paid_amount = $1,
                   discount_amount = $2,
                   pending_amount = $3,
                   status = $4,
                   updated_at = now()
               WHERE id = $5`,
              [newPaid, newDisc, newPending, newStatus, inv.id],
            );

            remAmt -= applyAmt;
            remDisc -= applyDisc;
          }
        }
      } else if (dto.paymentType === 'dealerPayment') {
        // Update Dealer Ledger Outstanding
        await client.query(
          `UPDATE dealers
           SET outstanding_amount = GREATEST(0.00, COALESCE(outstanding_amount, 0) - $1),
               updated_at = now()
           WHERE id = $2`,
          [totalDeduction, dto.partyId],
        );

        // If linked to Sales Document
        if (dto.referenceDocumentId) {
          const invRes = await client.query<any>(
            `SELECT id, total_amount, paid_amount, pending_amount, discount_amount 
             FROM sales 
             WHERE id = $1 FOR UPDATE`,
            [dto.referenceDocumentId],
          );
          if (invRes.rows.length) {
            const currentPaid = parseFloat(invRes.rows[0].paid_amount || '0');
            const totalAmount = parseFloat(invRes.rows[0].total_amount || '0');
            const currentDiscount = parseFloat(invRes.rows[0].discount_amount || '0');
            const newPaid = currentPaid + dto.amount;
            const newDiscount = currentDiscount + discount;
            const newPending = Math.max(0, totalAmount - newPaid - newDiscount);
            const newStatus = newPending <= 0 ? 'paid' : 'partialPaid';

            await client.query(
              `UPDATE sales
               SET paid_amount = $1,
                   discount_amount = $2,
                   pending_amount = $3,
                   status = $4,
                   updated_at = now()
               WHERE id = $5`,
              [newPaid, newDiscount, newPending, newStatus, dto.referenceDocumentId],
            );
          }
        } else {
          // FIFO auto-reconciliation against unpaid sales invoices
          const unpaidSales = await client.query<any>(
            `SELECT id, total_amount, paid_amount, pending_amount, discount_amount 
             FROM sales 
             WHERE party_id = $1 AND pending_amount > 0 AND document_type IN ('invoice', 'salesOrder')
             ORDER BY sale_date ASC, created_at ASC 
             FOR UPDATE`,
            [dto.partyId],
          );
          let remAmt = dto.amount;
          let remDisc = discount;
          for (const inv of unpaidSales.rows) {
            if (remAmt <= 0 && remDisc <= 0) break;
            const curPaid = parseFloat(inv.paid_amount || '0');
            const totAmt = parseFloat(inv.total_amount || '0');
            const curDisc = parseFloat(inv.discount_amount || '0');
            const curPending = parseFloat(inv.pending_amount || '0');

            const applyDisc = Math.min(remDisc, curPending);
            const applyAmt = Math.min(remAmt, curPending - applyDisc);

            const newPaid = curPaid + applyAmt;
            const newDisc = curDisc + applyDisc;
            const newPending = Math.max(0, totAmt - newPaid - newDisc);
            const newStatus = newPending <= 0 ? 'paid' : 'partialPaid';

            await client.query(
              `UPDATE sales
               SET paid_amount = $1,
                   discount_amount = $2,
                   pending_amount = $3,
                   status = $4,
                   updated_at = now()
               WHERE id = $5`,
              [newPaid, newDisc, newPending, newStatus, inv.id],
            );

            remAmt -= applyAmt;
            remDisc -= applyDisc;
          }
        }
      } else if (dto.paymentType === 'vendorPayment') {
        // Update Vendor Ledger Outstanding
        await client.query(
          `UPDATE vendors
           SET outstanding_balance = GREATEST(0.00, COALESCE(outstanding_balance, 0) - $1),
               updated_at = now()
           WHERE id = $2`,
          [totalDeduction, dto.partyId],
        );

        // If linked to a Purchase Order / Inward Bill
        if (dto.referenceDocumentId) {
          const purRes = await client.query<any>(
            `SELECT id, total_amount, paid_amount, pending_amount, discount_amount 
             FROM purchases 
             WHERE id = $1 FOR UPDATE`,
            [dto.referenceDocumentId],
          );
          if (purRes.rows.length) {
            const currentPaid = parseFloat(purRes.rows[0].paid_amount || '0');
            const totalAmount = parseFloat(purRes.rows[0].total_amount || '0');
            const currentDiscount = parseFloat(purRes.rows[0].discount_amount || '0');
            const newPaid = currentPaid + dto.amount;
            const newDiscount = currentDiscount + discount;
            const newPending = Math.max(0, totalAmount - newPaid - newDiscount);
            const newStatus = newPending <= 0 ? 'paid' : 'partialPaid';

            await client.query(
              `UPDATE purchases
               SET paid_amount = $1,
                   discount_amount = $2,
                   pending_amount = $3,
                   status = $4,
                   updated_at = now()
               WHERE id = $5`,
              [newPaid, newDiscount, newPending, newStatus, dto.referenceDocumentId],
            );
          }
        } else {
          // FIFO auto-reconciliation against unpaid purchase bills
          const unpaidPurchases = await client.query<any>(
            `SELECT id, total_amount, paid_amount, pending_amount, discount_amount 
             FROM purchases 
             WHERE vendor_id = $1 AND pending_amount > 0 AND status != 'cancelled'
             ORDER BY purchase_date ASC, created_at ASC 
             FOR UPDATE`,
            [dto.partyId],
          );
          let remAmt = dto.amount;
          let remDisc = discount;
          for (const pur of unpaidPurchases.rows) {
            if (remAmt <= 0 && remDisc <= 0) break;
            const curPaid = parseFloat(pur.paid_amount || '0');
            const totAmt = parseFloat(pur.total_amount || '0');
            const curDisc = parseFloat(pur.discount_amount || '0');
            const curPending = parseFloat(pur.pending_amount || '0');

            const applyDisc = Math.min(remDisc, curPending);
            const applyAmt = Math.min(remAmt, curPending - applyDisc);

            const newPaid = curPaid + applyAmt;
            const newDisc = curDisc + applyDisc;
            const newPending = Math.max(0, totAmt - newPaid - newDisc);
            const newStatus = newPending <= 0 ? 'paid' : 'partialPaid';

            await client.query(
              `UPDATE purchases
               SET paid_amount = $1,
                   discount_amount = $2,
                   pending_amount = $3,
                   status = $4,
                   updated_at = now()
               WHERE id = $5`,
              [newPaid, newDisc, newPending, newStatus, pur.id],
            );

            remAmt -= applyAmt;
            remDisc -= applyDisc;
          }
        }
      } else if (dto.paymentType === 'commissionPayment') {
        // Disbursed Commission Payout
        if (dto.referenceDocumentId) {
          await client.query(
            `UPDATE architect_commissions
             SET status = 'paid',
                 paid_date = now(),
                 payment_id = $1,
                 payment_reference = $2,
                 updated_at = now()
             WHERE id = $3`,
            [paymentRecord.id, dto.transactionReference || paymentNumber, dto.referenceDocumentId],
          );
        }

        // Update Architect Ledger Balances
        await client.query(
          `UPDATE architects
           SET paid_commission = COALESCE(paid_commission, 0) + $1,
               approved_commission = GREATEST(0.00, COALESCE(approved_commission, 0) - $1),
               updated_at = now()
           WHERE id = $2`,
          [dto.amount, dto.partyId],
        );
      }

      // 4. Audit Trail
      await this.auditService.record(
        {
          userId,
          action: 'CREATE',
          entityType: 'payment',
          entityId: paymentRecord.id,
          afterSnapshot: paymentRecord,
          correlationId,
        },
        client,
      );

      return this.mapPaymentRow(paymentRecord);
    });
  }

  // --------------------------------------------------------------------------
  // 11.3 List Architect Commissions
  // --------------------------------------------------------------------------
  async listCommissions(query: CommissionQueryDto) {
    const page = Math.max(1, query.page || 1);
    const limit = Math.max(1, query.limit || 50);
    const offset = (page - 1) * limit;

    const conditions: string[] = ['1=1'];
    const params: any[] = [];
    let pIdx = 1;

    if (query.architectId) {
      conditions.push(`c.architect_id = $${pIdx}`);
      params.push(query.architectId);
      pIdx++;
    }

    if (query.status) {
      conditions.push(`c.status = $${pIdx}`);
      params.push(query.status);
      pIdx++;
    }

    if (query.search) {
      conditions.push(
        `(c.commission_number ILIKE $${pIdx} OR c.architect_name ILIKE $${pIdx} OR c.sale_invoice_number ILIKE $${pIdx} OR c.project_name ILIKE $${pIdx})`,
      );
      params.push(`%${query.search}%`);
      pIdx++;
    }

    const whereClause = conditions.join(' AND ');

    // Count
    const countRes = await this.db.query<{ count: string }>(
      `SELECT COUNT(*) as count FROM architect_commissions c WHERE ${whereClause}`,
      params,
    );
    const total = parseInt(countRes.rows[0]?.count || '0', 10);

    // Summary KPIs
    const summaryRes = await this.db.query<{
      total_earned: string;
      pending_total: string;
      approved_total: string;
      paid_total: string;
    }>(
      `SELECT 
         COALESCE(SUM(commission_amount), 0) as total_earned,
         COALESCE(SUM(CASE WHEN status = 'generated' THEN commission_amount ELSE 0 END), 0) as pending_total,
         COALESCE(SUM(CASE WHEN status = 'approved' THEN commission_amount ELSE 0 END), 0) as approved_total,
         COALESCE(SUM(CASE WHEN status = 'paid' THEN commission_amount ELSE 0 END), 0) as paid_total
       FROM architect_commissions c
       WHERE ${whereClause}`,
      params,
    );

    // Query rows
    const dataRes = await this.db.query<any>(
      `SELECT 
         c.id,
         c.commission_number,
         c.architect_id,
         c.architect_name,
         c.sale_invoice_id,
         c.sale_invoice_number,
         c.project_id,
         c.project_name,
         c.sale_amount,
         c.commission_rate,
         c.commission_amount,
         c.status,
         c.generated_date,
         c.approved_date,
         c.paid_date,
         c.payment_id,
         c.payment_reference,
         c.rejection_reason,
         c.notes,
         c.created_at,
         c.updated_at
       FROM architect_commissions c
       WHERE ${whereClause}
       ORDER BY c.generated_date DESC, c.created_at DESC
       LIMIT $${pIdx} OFFSET $${pIdx + 1}`,
      [...params, limit, offset],
    );

    return {
      data: dataRes.rows.map(this.mapCommissionRow),
      meta: {
        total,
        page,
        limit,
        totalPages: Math.ceil(total / limit),
        summary: {
          totalEarned: summaryRes.rows[0]?.total_earned || '0.00',
          pendingCommission: summaryRes.rows[0]?.pending_total || '0.00',
          approvedCommission: summaryRes.rows[0]?.approved_total || '0.00',
          paidCommission: summaryRes.rows[0]?.paid_total || '0.00',
        },
      },
    };
  }

  // --------------------------------------------------------------------------
  // 11.4 Approve Commission
  // --------------------------------------------------------------------------
  async approveCommission(id: string, userId?: string, correlationId?: string) {
    return this.uow.runInTransaction(async (client) => {
      const commRes = await client.query<any>(
        `SELECT * FROM architect_commissions WHERE id = $1 FOR UPDATE`,
        [id],
      );
      if (!commRes.rows.length) {
        throw new NotFoundError(`Commission with ID "${id}" was not found`);
      }
      const comm = commRes.rows[0];
      if (comm.status !== 'generated') {
        throw new BadRequestException(`Cannot approve commission with status "${comm.status}". Only "generated" commissions can be approved.`);
      }

      // Update Commission
      const updatedRes = await client.query<any>(
        `UPDATE architect_commissions
         SET status = 'approved',
             approved_date = now(),
             updated_at = now()
         WHERE id = $1
         RETURNING *`,
        [id],
      );
      const updated = updatedRes.rows[0];

      // Update Architect Balances: Move from pending to approved
      await client.query(
        `UPDATE architects
         SET approved_commission = COALESCE(approved_commission, 0) + $1,
             pending_commission = GREATEST(0.00, COALESCE(pending_commission, 0) - $1),
             updated_at = now()
         WHERE id = $2`,
        [comm.commission_amount, comm.architect_id],
      );

      // Audit Log
      await this.auditService.record(
        {
          userId,
          action: 'UPDATE',
          entityType: 'architect_commission',
          entityId: id,
          beforeSnapshot: comm,
          afterSnapshot: updated,
          correlationId,
        },
        client,
      );

      return this.mapCommissionRow(updated);
    });
  }

  // --------------------------------------------------------------------------
  // 11.5 Disburse / Pay Commission
  // --------------------------------------------------------------------------
  async disburseCommission(
    id: string,
    dto: DisburseCommissionDto,
    userId?: string,
    correlationId?: string,
  ) {
    const commRes = await this.db.query<any>(
      `SELECT * FROM architect_commissions WHERE id = $1`,
      [id],
    );
    if (!commRes.rows.length) {
      throw new NotFoundError(`Commission with ID "${id}" was not found`);
    }
    const comm = commRes.rows[0];
    if (comm.status !== 'approved' && comm.status !== 'generated') {
      throw new BadRequestException(`Cannot pay commission with status "${comm.status}". It must be approved before disbursal.`);
    }

    // Record formal payment voucher
    const payment = await this.recordPayment(
      {
        paymentType: 'commissionPayment',
        partyId: comm.architect_id,
        partyName: comm.architect_name,
        referenceDocumentId: comm.id,
        referenceDocumentNumber: comm.commission_number,
        amount: parseFloat(comm.commission_amount),
        paymentMode: dto.paymentMode || 'bankTransfer',
        transactionReference: dto.transactionReference,
        notes: dto.notes || `Commission payout for ${comm.sale_invoice_number}`,
        isFullPayment: true,
        projectId: comm.project_id,
        projectName: comm.project_name,
      },
      userId,
      correlationId,
    );

    // Fetch updated commission
    const updatedCommRes = await this.db.query<any>(
      `SELECT * FROM architect_commissions WHERE id = $1`,
      [id],
    );
    return {
      commission: this.mapCommissionRow(updatedCommRes.rows[0]),
      payment,
    };
  }

  // --------------------------------------------------------------------------
  // 11.6 Reject Commission
  // --------------------------------------------------------------------------
  async rejectCommission(
    id: string,
    dto: RejectCommissionDto,
    userId?: string,
    correlationId?: string,
  ) {
    return this.uow.runInTransaction(async (client) => {
      const commRes = await client.query<any>(
        `SELECT * FROM architect_commissions WHERE id = $1 FOR UPDATE`,
        [id],
      );
      if (!commRes.rows.length) {
        throw new NotFoundError(`Commission with ID "${id}" was not found`);
      }
      const comm = commRes.rows[0];
      if (comm.status === 'paid') {
        throw new BadRequestException('Cannot reject a commission that has already been paid.');
      }

      // Update status
      const updatedRes = await client.query<any>(
        `UPDATE architect_commissions
         SET status = 'rejected',
             rejection_reason = $1,
             updated_at = now()
         WHERE id = $2
         RETURNING *`,
        [dto.reason || 'Management rejected commission', id],
      );
      const updated = updatedRes.rows[0];

      // Rebalance Architect
      if (comm.status === 'generated') {
        await client.query(
          `UPDATE architects
           SET pending_commission = GREATEST(0.00, COALESCE(pending_commission, 0) - $1),
               updated_at = now()
           WHERE id = $2`,
          [comm.commission_amount, comm.architect_id],
        );
      } else if (comm.status === 'approved') {
        await client.query(
          `UPDATE architects
           SET approved_commission = GREATEST(0.00, COALESCE(approved_commission, 0) - $1),
               updated_at = now()
           WHERE id = $2`,
          [comm.commission_amount, comm.architect_id],
        );
      }

      // Audit Log
      await this.auditService.record(
        {
          userId,
          action: 'UPDATE',
          entityType: 'architect_commission',
          entityId: id,
          beforeSnapshot: comm,
          afterSnapshot: updated,
          correlationId,
        },
        client,
      );

      return this.mapCommissionRow(updated);
    });
  }

  // Helper mappings
  private mapPaymentRow(row: any) {
    return {
      id: row.id,
      paymentNumber: row.payment_number,
      paymentType: row.payment_type,
      partyId: row.party_id,
      partyName: row.party_name,
      referenceDocumentId: row.reference_document_id,
      referenceDocumentNumber: row.reference_document_number,
      amount: parseFloat(row.amount || '0'),
      discount: parseFloat(row.discount || '0'),
      paymentMode: row.payment_mode,
      paymentDate: row.payment_date,
      transactionReference: row.transaction_reference,
      notes: row.notes,
      paymentStatus: row.payment_status,
      attachmentUrl: row.attachment_url,
      isFullPayment: row.is_full_payment,
      totalDocumentAmount: row.total_document_amount ? parseFloat(row.total_document_amount) : null,
      remainingAmount: row.remaining_amount ? parseFloat(row.remaining_amount) : null,
      projectId: row.project_id,
      projectName: row.project_name,
      createdAt: row.created_at,
      updatedAt: row.updated_at,
    };
  }

  private mapCommissionRow(row: any) {
    return {
      id: row.id,
      commissionNumber: row.commission_number,
      architectId: row.architect_id,
      architectName: row.architect_name,
      saleInvoiceId: row.sale_invoice_id,
      saleInvoiceNumber: row.sale_invoice_number,
      projectId: row.project_id,
      projectName: row.project_name,
      saleAmount: parseFloat(row.sale_amount || '0'),
      commissionRate: parseFloat(row.commission_rate || '0'),
      commissionAmount: parseFloat(row.commission_amount || '0'),
      status: row.status,
      generatedDate: row.generated_date,
      approvedDate: row.approved_date,
      paidDate: row.paid_date,
      paymentId: row.payment_id,
      paymentReference: row.payment_reference,
      rejectionReason: row.rejection_reason,
      notes: row.notes,
      createdAt: row.created_at,
      updatedAt: row.updated_at,
    };
  }
}
