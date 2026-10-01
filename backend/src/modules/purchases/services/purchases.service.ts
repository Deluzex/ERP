import { Injectable } from '@nestjs/common';
import { AuditService } from '../../../core/audit/audit.service';
import { DatabasePool } from '../../../core/database/connection';
import { UnitOfWork } from '../../../core/database/unit-of-work';
import { NotFoundError } from '../../../core/errors/not-found.error';
import {
  CreatePurchaseDto,
  PaymentModeEnum,
  PurchaseStatusEnum,
} from '../dto/create-purchase.dto';
import { PurchaseItemTypeEnum } from '../dto/purchase-item.dto';
import {
  PurchaseQueryDto,
  UpdatePurchaseStatusDto,
} from '../dto/purchase-query.dto';

@Injectable()
export class PurchasesService {
  constructor(
    private readonly db: DatabasePool,
    private readonly uow: UnitOfWork,
    private readonly auditService: AuditService,
  ) {}

  // --------------------------------------------------------------------------
  // 7.1 List Purchases
  // --------------------------------------------------------------------------
  async findAll(query: PurchaseQueryDto) {
    const page = Math.max(1, query.page || 1);
    const limit = Math.max(1, query.limit || 50);
    const offset = (page - 1) * limit;

    const conditions: string[] = ['1=1'];
    const params: any[] = [];
    let pIdx = 1;

    if (query.status) {
      conditions.push(`p.status = $${pIdx}`);
      params.push(query.status);
      pIdx++;
    }

    if (query.purchaseType) {
      conditions.push(`p.purchase_type = $${pIdx}`);
      params.push(query.purchaseType);
      pIdx++;
    }

    if (query.vendorId) {
      conditions.push(`p.vendor_id = $${pIdx}`);
      params.push(query.vendorId);
      pIdx++;
    }

    if (query.startDate) {
      conditions.push(`p.purchase_date >= $${pIdx}`);
      params.push(query.startDate);
      pIdx++;
    }

    if (query.endDate) {
      conditions.push(`p.purchase_date <= $${pIdx}`);
      params.push(query.endDate);
      pIdx++;
    }

    if (query.search?.trim()) {
      conditions.push(
        `(p.purchase_number ILIKE $${pIdx} OR p.vendor_name ILIKE $${pIdx} OR p.vendor_invoice_number ILIKE $${pIdx})`,
      );
      params.push(`%${query.search.trim()}%`);
      pIdx++;
    }

    const whereClause = `WHERE ${conditions.join(' AND ')}`;

    // 1. Summary aggregations
    const summaryRes = await this.db.query<{
      total_purchases: string;
      total_paid: string;
      total_pending: string;
    }>(
      `SELECT
         COALESCE(SUM(CASE WHEN status != 'cancelled' THEN total_amount ELSE 0 END), 0)::numeric(18,2) as total_purchases,
         COALESCE(SUM(CASE WHEN status != 'cancelled' THEN paid_amount ELSE 0 END), 0)::numeric(18,2) as total_paid,
         COALESCE(SUM(CASE WHEN status != 'cancelled' THEN pending_amount ELSE 0 END), 0)::numeric(18,2) as total_pending
       FROM purchases`,
    );

    // 2. Total Count
    const countRes = await this.db.query<{ count: string }>(
      `SELECT COUNT(*)::int as count FROM purchases p ${whereClause}`,
      params,
    );
    const totalCount = parseInt(countRes.rows[0]?.count || '0', 10);

    // 3. Paginated list
    const purchasesRes = await this.db.query<any>(
      `SELECT
         p.*,
         COALESCE(u.name, 'System') as created_by_name
       FROM purchases p
       LEFT JOIN users u ON p.created_by = u.id
       ${whereClause}
       ORDER BY p.purchase_date DESC, p.created_at DESC
       LIMIT $${pIdx} OFFSET $${pIdx + 1}`,
      [...params, limit, offset],
    );

    const purchaseIds = purchasesRes.rows.map((r) => r.id);
    const itemsByPurchaseId = new Map<string, any[]>();

    if (purchaseIds.length > 0) {
      const placeholders = purchaseIds.map((_, i) => `$${i + 1}`).join(', ');
      const itemsRes = await this.db.query<any>(
        `SELECT * FROM purchase_items WHERE purchase_id IN (${placeholders}) ORDER BY created_at ASC`,
        purchaseIds,
      );
      for (const itemRow of itemsRes.rows) {
        const pId = itemRow.purchase_id;
        if (!itemsByPurchaseId.has(pId)) itemsByPurchaseId.set(pId, []);
        itemsByPurchaseId.get(pId)!.push(this.mapItemRow(itemRow));
      }
    }

    return {
      summary: {
        totalPurchases: Number(summaryRes.rows[0]?.total_purchases || 0),
        totalPaid: Number(summaryRes.rows[0]?.total_paid || 0),
        totalPending: Number(summaryRes.rows[0]?.total_pending || 0),
      },
      items: purchasesRes.rows.map((r) => this.mapPurchaseRow(r, itemsByPurchaseId.get(r.id) || [])),
      pagination: {
        totalItems: totalCount,
        currentPage: page,
        totalPages: Math.ceil(totalCount / limit) || 1,
        limit,
      },
    };
  }

  // --------------------------------------------------------------------------
  // 7.3 Get Purchase Details by ID
  // --------------------------------------------------------------------------
  async findById(id: string) {
    const purchaseRes = await this.db.query<any>(
      `SELECT p.*, COALESCE(u.name, 'System') as created_by_name
       FROM purchases p
       LEFT JOIN users u ON p.created_by = u.id
       WHERE p.id = $1`,
      [id],
    );

    if (purchaseRes.rows.length === 0) {
      throw new NotFoundError(`Purchase order with ID ${id} not found`);
    }

    const itemsRes = await this.db.query<any>(
      `SELECT * FROM purchase_items WHERE purchase_id = $1 ORDER BY created_at ASC`,
      [id],
    );

    const paymentsRes = await this.db.query<any>(
      `SELECT * FROM payments WHERE purchase_id = $1 ORDER BY payment_date DESC`,
      [id],
    );

    const items = itemsRes.rows.map((r) => this.mapItemRow(r));
    const payments = paymentsRes.rows.map((p) => ({
      id: p.id,
      paymentNumber: p.payment_number,
      paymentDate: p.payment_date,
      paymentType: p.payment_type,
      amount: Number(p.amount),
      paymentMode: p.payment_mode,
      referenceNumber: p.reference_number,
      notes: p.notes,
    }));

    return this.mapPurchaseRow(purchaseRes.rows[0], items, payments);
  }

  // --------------------------------------------------------------------------
  // 7.2 Create Purchase Order / Inward Bill (Transactional)
  // --------------------------------------------------------------------------
  async create(dto: CreatePurchaseDto, userId: string, correlationId?: string) {
    return this.uow.runInTransaction(async (client) => {
      const now = new Date();
      const countRes = await client.query<{ count: string }>(
        `SELECT COUNT(*)::int as count FROM purchases WHERE created_at >= date_trunc('year', now())`,
      );
      const seq = parseInt(countRes.rows[0]?.count || '0', 10) + 1;
      const purchaseNumber = `PO-${now.getFullYear()}-${String(seq).padStart(4, '0')}`;

      const totalAmount = Number(dto.totalAmount);
      const paidAmount = Number(dto.paidAmount || 0);
      const pendingAmount =
        dto.pendingAmount !== undefined
          ? Number(dto.pendingAmount)
          : Math.max(0, totalAmount - paidAmount);

      const status = dto.status || PurchaseStatusEnum.saved;
      const purchaseDate = dto.purchaseDate
        ? new Date(dto.purchaseDate)
        : now;
      const invoiceDate = dto.invoiceDate ? new Date(dto.invoiceDate) : null;

      // 1. Insert Purchase Header
      const pRes = await client.query<any>(
        `INSERT INTO purchases (
           purchase_number,
           vendor_id,
           vendor_name,
           vendor_invoice_number,
           purchase_date,
           invoice_date,
           purchase_type,
           project_id,
           project_name,
           subtotal_amount,
           discount_amount,
           taxable_amount,
           cgst_amount,
           sgst_amount,
           igst_amount,
           gst_amount,
           total_amount,
           paid_amount,
           pending_amount,
           payment_mode,
           status,
           notes,
           attachment_url,
           created_by
         )
         VALUES (
           $1, $2, $3, $4, $5, $6, $7, $8, $9, $10,
           $11, $12, $13, $14, $15, $16, $17, $18, $19, $20,
           $21, $22, $23, $24
         )
         RETURNING *`,
        [
          purchaseNumber,
          dto.vendorId,
          dto.vendorName,
          dto.vendorInvoiceNumber || null,
          purchaseDate,
          invoiceDate,
          dto.purchaseType,
          dto.projectId || null,
          dto.projectName || null,
          Number(dto.subtotalAmount || 0),
          Number(dto.discountAmount || 0),
          Number(dto.taxableAmount || 0),
          Number(dto.cgstAmount || 0),
          Number(dto.sgstAmount || 0),
          Number(dto.igstAmount || 0),
          Number(dto.gstAmount || 0),
          totalAmount,
          paidAmount,
          pendingAmount,
          dto.paymentMode || PaymentModeEnum.credit,
          status,
          dto.notes || null,
          dto.attachmentUrl || null,
          userId,
        ],
      );
      const purchaseRecord = pRes.rows[0];

      // 2. Insert Line Items & Inward Stock
      const insertedItems: any[] = [];

      for (const item of dto.items) {
        const itemRes = await client.query<any>(
          `INSERT INTO purchase_items (
             purchase_id,
             item_type,
             raw_material_id,
             raw_material_name,
             raw_material_code,
             finished_product_id,
             finished_product_name,
             finished_product_code,
             quantity,
             unit,
             rate,
             discount_amount,
             gst_percent,
             taxable_amount,
             cgst_amount,
             sgst_amount,
             igst_amount,
             line_total
           )
           VALUES (
             $1, $2, $3, $4, $5, $6, $7, $8, $9, $10,
             $11, $12, $13, $14, $15, $16, $17, $18
           )
           RETURNING *`,
          [
            purchaseRecord.id,
            item.itemType,
            item.rawMaterialId || null,
            item.rawMaterialName || null,
            item.rawMaterialCode || null,
            item.finishedProductId || null,
            item.finishedProductName || null,
            item.finishedProductCode || null,
            item.quantity,
            item.unit,
            item.rate,
            item.discountAmount || 0,
            item.gstPercent || 18,
            item.taxableAmount || 0,
            item.cgstAmount || 0,
            item.sgstAmount || 0,
            item.igstAmount || 0,
            item.lineTotal,
          ],
        );
        insertedItems.push(this.mapItemRow(itemRes.rows[0]));

        // Atomic Stock Inward & Ledger insertion (if not draft)
        if (status !== PurchaseStatusEnum.draft) {
          if (item.itemType === PurchaseItemTypeEnum.rawMaterial && item.rawMaterialId) {
            // Lock and update Raw Material
            const updRm = await client.query<{ current_stock: string }>(
              `UPDATE raw_materials
               SET current_stock = current_stock + $1, updated_at = now()
               WHERE id = $2 AND is_deleted = false
               RETURNING current_stock`,
              [item.quantity, item.rawMaterialId],
            );
            const newBal = Number(updRm.rows[0]?.current_stock || 0);

            // Record immutable stock movement
            await client.query(
              `INSERT INTO stock_movements (
                 date,
                 item_id,
                 item_type,
                 transaction_type,
                 reference_number,
                 stock_in,
                 stock_out,
                 current_balance,
                 unit,
                 notes,
                 performed_by
               )
               VALUES (now(), $1, 'rawMaterial', 'purchase', $2, $3, 0, $4, $5, $6, $7)`,
              [
                item.rawMaterialId,
                purchaseNumber,
                item.quantity,
                newBal,
                item.unit,
                `Purchase from ${dto.vendorName} (Bill: ${purchaseNumber})`,
                userId,
              ],
            );
          } else if (item.itemType === PurchaseItemTypeEnum.finishedProduct && item.finishedProductId) {
            // Lock and update Finished Product
            const updFp = await client.query<{ current_stock: string }>(
              `UPDATE finished_products
               SET current_stock = current_stock + $1,
                   purchased_stock = purchased_stock + $1,
                   updated_at = now()
               WHERE id = $2 AND is_deleted = false
               RETURNING current_stock`,
              [item.quantity, item.finishedProductId],
            );
            const newBal = Number(updFp.rows[0]?.current_stock || 0);

            // Record immutable stock movement
            await client.query(
              `INSERT INTO stock_movements (
                 date,
                 item_id,
                 item_type,
                 transaction_type,
                 reference_number,
                 stock_in,
                 stock_out,
                 current_balance,
                 unit,
                 notes,
                 performed_by
               )
               VALUES (now(), $1, 'finishedProduct', 'purchase', $2, $3, 0, $4, $5, $6, $7)`,
              [
                item.finishedProductId,
                purchaseNumber,
                item.quantity,
                newBal,
                item.unit,
                `Purchase from ${dto.vendorName} (Bill: ${purchaseNumber})`,
                userId,
              ],
            );
          }
        }
      }

      // 3. Update Vendor Outstanding Balance (if not draft)
      if (status !== PurchaseStatusEnum.draft && pendingAmount > 0) {
        await client.query(
          `UPDATE vendors
           SET outstanding_balance = outstanding_balance + $1, updated_at = now()
           WHERE id = $2`,
          [pendingAmount, dto.vendorId],
        );
      }

      // 4. Initial Payment Voucher if paidAmount > 0
      if (paidAmount > 0) {
        const paySeq = String(Date.now()).slice(-5);
        const paymentNumber = `VPV-${now.getFullYear()}-${paySeq}`;
        await client.query(
          `INSERT INTO payments (
             payment_number,
             payment_date,
             payment_type,
             vendor_id,
             purchase_id,
             amount,
             payment_mode,
             notes,
             created_by
           )
           VALUES ($1, now(), 'vendorPayment', $2, $3, $4, $5, $6, $7)`,
          [
            paymentNumber,
            dto.vendorId,
            purchaseRecord.id,
            paidAmount,
            dto.paymentMode || 'credit',
            `Initial payment for purchase bill ${purchaseNumber}`,
            userId,
          ],
        );
      }

      // Audit log
      await this.auditService.record(
        {
          userId,
          action: 'create_purchase',
          entityType: 'purchase',
          entityId: purchaseRecord.id,
          afterSnapshot: {
            purchaseNumber,
            totalAmount,
            paidAmount,
            pendingAmount,
            itemCount: dto.items.length,
          },
          correlationId,
        },
        client,
      );

      return this.mapPurchaseRow(purchaseRecord, insertedItems);
    });
  }

  // --------------------------------------------------------------------------
  // 7.4 Update Purchase Status & Cancellation Rollback
  // --------------------------------------------------------------------------
  async updateStatus(
    id: string,
    dto: UpdatePurchaseStatusDto,
    userId: string,
    correlationId?: string,
  ) {
    return this.uow.runInTransaction(async (client) => {
      const pRes = await client.query<any>(
        `SELECT * FROM purchases WHERE id = $1 FOR UPDATE`,
        [id],
      );

      if (pRes.rows.length === 0) {
        throw new NotFoundError(`Purchase with ID ${id} not found`);
      }
      const purchase = pRes.rows[0];

      // Handle Cancellation Rollback
      if (
        dto.status === PurchaseStatusEnum.cancelled &&
        purchase.status !== PurchaseStatusEnum.cancelled &&
        purchase.status !== PurchaseStatusEnum.draft
      ) {
        const itemsRes = await client.query<any>(
          `SELECT * FROM purchase_items WHERE purchase_id = $1`,
          [id],
        );

        for (const item of itemsRes.rows) {
          const qty = Number(item.quantity);
          if (item.item_type === 'rawMaterial' && item.raw_material_id) {
            const updRm = await client.query<{ current_stock: string }>(
              `UPDATE raw_materials
               SET current_stock = GREATEST(0, current_stock - $1), updated_at = now()
               WHERE id = $2
               RETURNING current_stock`,
              [qty, item.raw_material_id],
            );
            const newBal = Number(updRm.rows[0]?.current_stock || 0);

            await client.query(
              `INSERT INTO stock_movements (
                 date, item_id, item_type, transaction_type, reference_number,
                 stock_in, stock_out, current_balance, unit, notes, performed_by
               )
               VALUES (now(), $1, 'rawMaterial', 'purchaseReturn', $2, 0, $3, $4, $5, $6, $7)`,
              [
                item.raw_material_id,
                purchase.purchase_number,
                qty,
                newBal,
                item.unit,
                `Cancelled PO ${purchase.purchase_number}: ${dto.reason || 'No reason'}`,
                userId,
              ],
            );
          } else if (item.item_type === 'finishedProduct' && item.finished_product_id) {
            const updFp = await client.query<{ current_stock: string }>(
              `UPDATE finished_products
               SET current_stock = GREATEST(0, current_stock - $1),
                   purchased_stock = GREATEST(0, purchased_stock - $1),
                   updated_at = now()
               WHERE id = $2
               RETURNING current_stock`,
              [qty, item.finished_product_id],
            );
            const newBal = Number(updFp.rows[0]?.current_stock || 0);

            await client.query(
              `INSERT INTO stock_movements (
                 date, item_id, item_type, transaction_type, reference_number,
                 stock_in, stock_out, current_balance, unit, notes, performed_by
               )
               VALUES (now(), $1, 'finishedProduct', 'purchaseReturn', $2, 0, $3, $4, $5, $6, $7)`,
              [
                item.finished_product_id,
                purchase.purchase_number,
                qty,
                newBal,
                item.unit,
                `Cancelled PO ${purchase.purchase_number}: ${dto.cancelReason || dto.reason || 'No reason'}`,
                userId,
              ],
            );
          }
        }

        // Revert Vendor Outstanding Balance
        const pendingAmt = Number(purchase.pending_amount);
        if (pendingAmt > 0) {
          await client.query(
            `UPDATE vendors
             SET outstanding_balance = GREATEST(0, outstanding_balance - $1), updated_at = now()
             WHERE id = $2`,
            [pendingAmt, purchase.vendor_id],
          );
        }

        const updRes = await client.query<any>(
          `UPDATE purchases
           SET status = 'cancelled', cancel_reason = $1, cancelled_at = now(), updated_at = now()
           WHERE id = $2
           RETURNING *`,
          [dto.cancelReason || dto.reason || null, id],
        );
        return this.mapPurchaseRow(updRes.rows[0]);
      }

      // Standard Status Update
      const updRes = await client.query<any>(
        `UPDATE purchases SET status = $1, updated_at = now() WHERE id = $2 RETURNING *`,
        [dto.status, id],
      );

      await this.auditService.record(
        {
          userId,
          action: 'update_purchase_status',
          entityType: 'purchase',
          entityId: id,
          beforeSnapshot: { status: purchase.status },
          afterSnapshot: { status: dto.status, reason: dto.reason },
          correlationId,
        },
        client,
      );

      return this.mapPurchaseRow(updRes.rows[0]);
    });
  }

  // --------------------------------------------------------------------------
  // Row Mappers
  // --------------------------------------------------------------------------
  private mapPurchaseRow(r: any, items: any[] = [], payments: any[] = []) {
    return {
      id: r.id,
      purchaseNumber: r.purchase_number,
      vendorId: r.vendor_id,
      vendorName: r.vendor_name,
      vendorInvoiceNumber: r.vendor_invoice_number,
      purchaseDate: r.purchase_date,
      invoiceDate: r.invoice_date,
      purchaseType: r.purchase_type,
      projectId: r.project_id,
      projectName: r.project_name,
      subtotalAmount: Number(r.subtotal_amount),
      discountAmount: Number(r.discount_amount),
      taxableAmount: Number(r.taxable_amount),
      cgstAmount: Number(r.cgst_amount),
      sgstAmount: Number(r.sgst_amount),
      igstAmount: Number(r.igst_amount),
      gstAmount: Number(r.gst_amount),
      totalAmount: Number(r.total_amount),
      paidAmount: Number(r.paid_amount),
      pendingAmount: Number(r.pending_amount),
      paymentMode: r.payment_mode,
      status: r.status,
      notes: r.notes,
      attachmentUrl: r.attachment_url,
      cancelReason: r.cancel_reason,
      cancelledAt: r.cancelled_at,
      createdBy: r.created_by_name || 'System',
      createdAt: r.created_at,
      updatedAt: r.updated_at,
      items,
      payments,
    };
  }

  private mapItemRow(r: any) {
    return {
      id: r.id,
      purchaseId: r.purchase_id,
      itemType: r.item_type,
      rawMaterialId: r.raw_material_id,
      rawMaterialName: r.raw_material_name,
      rawMaterialCode: r.raw_material_code,
      finishedProductId: r.finished_product_id,
      finishedProductName: r.finished_product_name,
      finishedProductCode: r.finished_product_code,
      quantity: Number(r.quantity),
      unit: r.unit,
      rate: Number(r.rate),
      discountAmount: Number(r.discount_amount),
      gstPercent: Number(r.gst_percent),
      taxableAmount: Number(r.taxable_amount),
      cgstAmount: Number(r.cgst_amount),
      sgstAmount: Number(r.sgst_amount),
      igstAmount: Number(r.igst_amount),
      lineTotal: Number(r.line_total),
      createdAt: r.created_at,
    };
  }
}
