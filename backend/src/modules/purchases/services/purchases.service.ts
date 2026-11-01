import { Injectable } from '@nestjs/common';
import { AuditService } from '../../../core/audit/audit.service';
import { DatabasePool } from '../../../core/database/connection';
import { UnitOfWork } from '../../../core/database/unit-of-work';
import { ConflictError } from '../../../core/errors/conflict.error';
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
import { UpdatePurchaseDto } from '../dto/update-purchase.dto';

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
       ORDER BY COALESCE(p.updated_at, p.purchase_date) DESC, p.created_at DESC
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

      // 1. Calculate Landed Cost & Transportation Allocation per Line
      const transportationCharges = Number(dto.transportationCharges || 0);
      const lineValues = this.computeLineValues(dto.items);
      const allocatedCosts = this.buildTransportationAllocation(
        lineValues,
        transportationCharges,
      );

      // 2. Insert Purchase Header
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
           transportation_charges,
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
           $21, $22, $23, $24, $25
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
          transportationCharges,
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

      // 3. Insert Line Items & Inward Stock
      const insertedItems: any[] = [];

      for (let i = 0; i < dto.items.length; i++) {
        const item = dto.items[i];
        const transCost = allocatedCosts[i];
        const lineVal = lineValues[i];
        const qty = Number(item.quantity || 0);
        const landedRate =
          qty > 0
            ? Math.round(((lineVal + transCost) / qty) * 100) / 100
            : Number(item.rate || 0);

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
             line_total,
             transportation_cost,
             landed_rate
           )
           VALUES (
             $1, $2, $3, $4, $5, $6, $7, $8, $9, $10,
             $11, $12, $13, $14, $15, $16, $17, $18, $19, $20
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
            transCost,
            landedRate,
          ],
        );
        insertedItems.push(this.mapItemRow(itemRes.rows[0]));

        // Atomic Stock Inward & Ledger insertion (if not draft)
        if (status !== PurchaseStatusEnum.draft) {
          if (item.itemType === PurchaseItemTypeEnum.rawMaterial && item.rawMaterialId) {
            // Lock and update Raw Material with landed cost (including transportation)
            const unitCost = Number(landedRate || item.landedRate || item.rate || 0);
            const transAmount = Number(transCost || 0);
            const updRm = await client.query<{ current_stock: string }>(
              `UPDATE raw_materials
               SET current_stock = current_stock + $1::numeric,
                   default_purchase_price = CASE WHEN $3::numeric > 0 THEN $3::numeric ELSE default_purchase_price END,
                   transportation_charge = $4::numeric,
                   updated_at = now()
               WHERE id = $2 AND is_deleted = false
               RETURNING current_stock`,
              [item.quantity, item.rawMaterialId, unitCost, transAmount],
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
            // Lock and update Finished Product with landed cost (including transportation)
            const unitCost = Number(landedRate || item.landedRate || item.rate || 0);
            const unitTrans = Number(item.quantity) > 0 ? Number(transCost) / Number(item.quantity) : 0;
            const updFp = await client.query<{ current_stock: string }>(
              `UPDATE finished_products
               SET current_stock = current_stock + $1,
                   purchased_stock = purchased_stock + $1::numeric,
                   cost_price = CASE WHEN $3::numeric > 0 THEN $3::numeric ELSE cost_price END,
                   transportation_charge = $4::numeric,
                   updated_at = now()
               WHERE id = $2 AND is_deleted = false
               RETURNING current_stock`,
              [item.quantity, item.finishedProductId, unitCost, unitTrans],
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
            transportationCharges,
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
  // 7.5 Update Purchase (Edit) — header amendment, line replacement with net
  // stock deltas, vendor payable rebalance, and audit trail, all transactional.
  // --------------------------------------------------------------------------
  async update(
    id: string,
    dto: UpdatePurchaseDto,
    userId: string,
    correlationId?: string,
  ) {
    return this.uow.runInTransaction(async (client) => {
      const pRes = await client.query<any>(
        `SELECT * FROM purchases WHERE id = $1 FOR UPDATE`,
        [id],
      );

      if (pRes.rows.length === 0) {
        throw new NotFoundError(`Purchase order with ID ${id} not found`);
      }
      const current = pRes.rows[0];

      // ------------------ Guard rails ------------------
      if (current.status === PurchaseStatusEnum.cancelled) {
        throw new ConflictError(
          'Cancelled purchase bills cannot be edited. Cancel is final.',
        );
      }
      if (dto.status === PurchaseStatusEnum.cancelled) {
        throw new ConflictError(
          'Cancellation must use the dedicated status endpoint so stock and vendor balances roll back correctly',
        );
      }
      if (
        dto.status === PurchaseStatusEnum.draft &&
        current.status !== PurchaseStatusEnum.draft
      ) {
        throw new ConflictError(
          'A posted purchase bill cannot be reverted to draft',
        );
      }

      const currentPosted = current.status !== PurchaseStatusEnum.draft;
      const finalStatus = dto.status ?? current.status;
      const finalPosted = finalStatus !== PurchaseStatusEnum.draft;

      // ------------------ Vendor resolution ------------------
      // The vendor master is authoritative for the display name, mirroring
      // create() where the header vendors.* values feed from master data.
      let vendorId: string = current.vendor_id;
      let vendorName: string = current.vendor_name;
      if (dto.vendorId) {
        const vRes = await client.query<any>(
          `SELECT id, name, is_deleted FROM vendors WHERE id = $1 FOR UPDATE`,
          [dto.vendorId],
        );
        if (vRes.rows.length === 0 || vRes.rows[0].is_deleted) {
          throw new ConflictError(
            `Vendor ${dto.vendorId} does not exist or is inactive`,
          );
        }
        vendorId = vRes.rows[0].id;
        vendorName = dto.vendorName ?? vRes.rows[0].name;
      } else if (dto.vendorName !== undefined) {
        vendorName = dto.vendorName;
      }

      // ------------------ Financial merge ------------------
      const currentTotal = Number(current.total_amount);
      const currentPaid = Number(current.paid_amount);
      const currentPending = Number(current.pending_amount);
      const newTotal =
        dto.totalAmount !== undefined ? Number(dto.totalAmount) : currentTotal;
      const newPaid =
        dto.paidAmount !== undefined ? Number(dto.paidAmount) : currentPaid;
      const newPending =
        dto.pendingAmount !== undefined
          ? Number(dto.pendingAmount)
          : Math.max(0, newTotal - newPaid);

      let outStatus = finalStatus;
      if (dto.status === undefined && finalPosted) {
        // Keep paid/pending ledger semantics consistent with the payments module
        if (newPending <= 0 && newTotal > 0) {
          outStatus = PurchaseStatusEnum.paid;
        } else if (newPaid > 0) {
          outStatus = PurchaseStatusEnum.partialPaid;
        }
      }

      const merged = {
        vendor_id: vendorId,
        vendor_name: vendorName,
        vendor_invoice_number:
          dto.vendorInvoiceNumber !== undefined
            ? dto.vendorInvoiceNumber || null
            : current.vendor_invoice_number,
        purchase_date: dto.purchaseDate
          ? new Date(dto.purchaseDate)
          : current.purchase_date,
        invoice_date:
          dto.invoiceDate !== undefined
            ? dto.invoiceDate
              ? new Date(dto.invoiceDate)
              : null
            : current.invoice_date,
        purchase_type: dto.purchaseType ?? current.purchase_type,
        project_id:
          dto.projectId !== undefined ? dto.projectId : current.project_id,
        project_name:
          dto.projectName !== undefined ? dto.projectName : current.project_name,
        subtotal_amount:
          dto.subtotalAmount !== undefined
            ? Number(dto.subtotalAmount)
            : Number(current.subtotal_amount),
        discount_amount:
          dto.discountAmount !== undefined
            ? Number(dto.discountAmount)
            : Number(current.discount_amount),
        taxable_amount:
          dto.taxableAmount !== undefined
            ? Number(dto.taxableAmount)
            : Number(current.taxable_amount),
        cgst_amount:
          dto.cgstAmount !== undefined
            ? Number(dto.cgstAmount)
            : Number(current.cgst_amount),
        sgst_amount:
          dto.sgstAmount !== undefined
            ? Number(dto.sgstAmount)
            : Number(current.sgst_amount),
        igst_amount:
          dto.igstAmount !== undefined
            ? Number(dto.igstAmount)
            : Number(current.igst_amount),
        gst_amount:
          dto.gstAmount !== undefined
            ? Number(dto.gstAmount)
            : Number(current.gst_amount),
        transportation_charges:
          dto.transportationCharges !== undefined
            ? Number(dto.transportationCharges)
            : Number(current.transportation_charges),
        total_amount: newTotal,
        paid_amount: newPaid,
        pending_amount: newPending,
        payment_mode: dto.paymentMode ?? current.payment_mode,
        status: outStatus,
        notes: dto.notes !== undefined ? dto.notes || null : current.notes,
        attachment_url:
          dto.attachmentUrl !== undefined
            ? dto.attachmentUrl || null
            : current.attachment_url,
      };

      // ------------------ Line items ------------------
      const oldItemsRes = await client.query<any>(
        `SELECT * FROM purchase_items WHERE purchase_id = $1 ORDER BY created_at ASC`,
        [id],
      );

      let replacedItems: any[] | null = null;
      if (dto.items && dto.items.length > 0) {
        // Full replacement with server-side transportation allocation and
        // landed-cost computation (identical rules to create()).
        const lineValues = this.computeLineValues(dto.items);
        const allocatedCosts = this.buildTransportationAllocation(
          lineValues,
          merged.transportation_charges,
        );

        await client.query(
          `DELETE FROM purchase_items WHERE purchase_id = $1`,
          [id],
        );

        replacedItems = [];
        for (let i = 0; i < dto.items.length; i++) {
          const item = dto.items[i];
          const transCost = allocatedCosts[i];
          const lineVal = lineValues[i];
          const qty = Number(item.quantity || 0);
          const landedRate =
            qty > 0
              ? Math.round(((lineVal + transCost) / qty) * 100) / 100
              : Number(item.rate || 0);

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
               line_total,
               transportation_cost,
               landed_rate
             )
             VALUES (
               $1, $2, $3, $4, $5, $6, $7, $8, $9, $10,
               $11, $12, $13, $14, $15, $16, $17, $18, $19, $20
             )
             RETURNING *`,
            [
              id,
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
              transCost,
              landedRate,
            ],
          );
          replacedItems.push(this.mapItemRow(itemRes.rows[0]));
        }
      }

      // ------------------ Net stock delta ledger ------------------
      // Aggregates old posted quantities vs new quantities per master item so a
      // pure header edit (date/notes/vendor invoice number) touches zero stock
      // and writes no movement, while quantity edits produce one consolidated
      // movement per affected item.
      if (currentPosted || finalPosted) {
        const deltas = new Map<
          string,
          {
            itemType: string;
            itemId: string;
            unit: string;
            delta: number;
            landedRate: number;
          }
        >();

        const applyDelta = (
          itemType: string,
          itemId: string | null,
          unit: string,
          amount: number,
          landedRate: number,
        ) => {
          if (!itemId) return;
          const key = `${itemType}|${itemId}`;
          const entry = deltas.get(key);
          if (entry) {
            entry.delta += amount;
            if (unit) entry.unit = unit;
            if (landedRate > 0) entry.landedRate = landedRate;
          } else {
            deltas.set(key, { itemType, itemId, unit, delta: amount, landedRate });
          }
        };

        // Revert the stock previously applied for posted bills
        if (currentPosted) {
          for (const it of oldItemsRes.rows) {
            const itemId =
              it.item_type === PurchaseItemTypeEnum.rawMaterial
                ? it.raw_material_id
                : it.finished_product_id;
            applyDelta(it.item_type, itemId, it.unit, -Number(it.quantity), 0);
          }
        }

        // Apply the stock due after the amendment
        if (finalPosted) {
          if (replacedItems) {
            for (let i = 0; i < dto.items!.length; i++) {
              const it = dto.items![i];
              const itemId =
                it.itemType === PurchaseItemTypeEnum.rawMaterial
                  ? it.rawMaterialId
                  : it.finishedProductId;
              const landed =
                replacedItems[i]?.landedRate ?? Number(it.rate || 0);
              applyDelta(
                it.itemType,
                itemId ?? null,
                it.unit,
                Number(it.quantity || 0),
                landed,
              );
            }
          } else {
            for (const it of oldItemsRes.rows) {
              const itemId =
                it.item_type === PurchaseItemTypeEnum.rawMaterial
                  ? it.raw_material_id
                  : it.finished_product_id;
              applyDelta(
                it.item_type,
                itemId,
                it.unit,
                Number(it.quantity),
                Number(it.landed_rate || 0),
              );
            }
          }
        }

        for (const entry of deltas.values()) {
          if (entry.delta === 0) continue;

          const isRaw = entry.itemType === PurchaseItemTypeEnum.rawMaterial;
          const table = isRaw ? 'raw_materials' : 'finished_products';
          const label = isRaw ? 'Raw material' : 'Finished product';
          const priceColumn = isRaw ? 'default_purchase_price' : 'cost_price';

          const updRes = await client.query<{ current_stock: string }>(
            `UPDATE ${table}
             SET current_stock = current_stock + $1::numeric,
                 ${isRaw ? '' : `purchased_stock = CASE WHEN $1::numeric > 0
                     THEN purchased_stock + $1::numeric
                     ELSE GREATEST(0, purchased_stock + $1::numeric) END,`}
                 ${priceColumn} = CASE WHEN $1::numeric > 0 AND $3::numeric > 0
                     THEN $3::numeric ELSE ${priceColumn} END,
                 updated_at = now()
             WHERE id = $2 AND current_stock + $1::numeric >= 0
             RETURNING current_stock`,
            [entry.delta, entry.itemId, entry.landedRate],
          );

          if (updRes.rows.length === 0) {
            throw new ConflictError(
              `${label} referenced by this purchase no longer has enough stock to absorb this edit, or no longer exists`,
            );
          }
          const newBal = Number(updRes.rows[0].current_stock);

          await client.query(
            `INSERT INTO stock_movements (
               date, item_id, item_type, transaction_type, reference_number,
               stock_in, stock_out, current_balance, unit, notes, performed_by
             )
             VALUES (now(), $1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
            [
              entry.itemId,
              entry.itemType,
              entry.delta > 0 ? 'purchase' : 'purchaseReturn',
              current.purchase_number,
              entry.delta > 0 ? entry.delta : 0,
              entry.delta < 0 ? Math.abs(entry.delta) : 0,
              newBal,
              entry.unit,
              `Purchase edited: net ${entry.delta > 0 ? '+' : ''}${entry.delta} ${entry.unit} on amendment`,
              userId,
            ],
          );
        }
      }

      // ------------------ Vendor payable rebalance ------------------
      const oldPostedPending = currentPosted ? currentPending : 0;
      const newPostedPending = finalPosted ? newPending : 0;
      if (oldPostedPending !== 0 || newPostedPending !== 0) {
        if (vendorId === current.vendor_id) {
          const outstandingDelta = newPostedPending - oldPostedPending;
          if (outstandingDelta !== 0) {
            await client.query(
              `UPDATE vendors
               SET outstanding_balance = GREATEST(0, outstanding_balance + $1), updated_at = now()
               WHERE id = $2`,
              [outstandingDelta, vendorId],
            );
          }
        } else {
          // Vendor switched: release the old ledger, charge the new one
          if (oldPostedPending > 0) {
            await client.query(
              `UPDATE vendors
               SET outstanding_balance = GREATEST(0, outstanding_balance - $1), updated_at = now()
               WHERE id = $2`,
              [oldPostedPending, current.vendor_id],
            );
          }
          if (newPostedPending > 0) {
            await client.query(
              `UPDATE vendors
               SET outstanding_balance = outstanding_balance + $1, updated_at = now()
               WHERE id = $2`,
              [newPostedPending, vendorId],
            );
          }
        }
      }

      // ------------------ Header update ------------------
      const updRes = await client.query<any>(
        `UPDATE purchases
         SET vendor_id = $1,
             vendor_name = $2,
             vendor_invoice_number = $3,
             purchase_date = $4,
             invoice_date = $5,
             purchase_type = $6,
             project_id = $7,
             project_name = $8,
             subtotal_amount = $9,
             discount_amount = $10,
             taxable_amount = $11,
             cgst_amount = $12,
             sgst_amount = $13,
             igst_amount = $14,
             gst_amount = $15,
             transportation_charges = $16,
             total_amount = $17,
             paid_amount = $18,
             pending_amount = $19,
             payment_mode = $20,
             status = $21,
             notes = $22,
             attachment_url = $23,
             updated_at = now()
         WHERE id = $24
         RETURNING *`,
        [
          merged.vendor_id,
          merged.vendor_name,
          merged.vendor_invoice_number,
          merged.purchase_date,
          merged.invoice_date,
          merged.purchase_type,
          merged.project_id,
          merged.project_name,
          merged.subtotal_amount,
          merged.discount_amount,
          merged.taxable_amount,
          merged.cgst_amount,
          merged.sgst_amount,
          merged.igst_amount,
          merged.gst_amount,
          merged.transportation_charges,
          merged.total_amount,
          merged.paid_amount,
          merged.pending_amount,
          merged.payment_mode,
          merged.status,
          merged.notes,
          merged.attachment_url,
          id,
        ],
      );

      await this.auditService.record(
        {
          userId,
          action: 'update_purchase',
          entityType: 'purchase',
          entityId: id,
          beforeSnapshot: {
            purchaseNumber: current.purchase_number,
            status: current.status,
            purchaseDate: current.purchase_date,
            totalAmount: currentTotal,
            pendingAmount: currentPending,
            vendorId: current.vendor_id,
          },
          afterSnapshot: {
            purchaseNumber: current.purchase_number,
            status: merged.status,
            purchaseDate: merged.purchase_date,
            totalAmount: merged.total_amount,
            pendingAmount: merged.pending_amount,
            vendorId: merged.vendor_id,
          },
          correlationId,
        },
        client,
      );

      const finalItems = replacedItems
        ? replacedItems
        : oldItemsRes.rows.map((r) => this.mapItemRow(r));
      return this.mapPurchaseRow(updRes.rows[0], finalItems);
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
  // Row Mappers & Shared Calculations
  // --------------------------------------------------------------------------
  /** Discounted net line value for each line item (transportation basis). */
  private computeLineValues(
    items: Array<{
      quantity?: number | string;
      rate?: number | string;
      discountAmount?: number | string;
    }>,
  ): number[] {
    return items.map((it) => {
      const qty = Number(it.quantity || 0);
      const rate = Number(it.rate || 0);
      const discount = Number(it.discountAmount || 0);
      return Math.max(0, qty * rate - discount);
    });
  }

  /**
   * Proportionally allocates transportation charges across discounted line
   * values, and distributes the nearest-paisa remainder to the largest line
   * item (shared by create & update paths).
   */
  private buildTransportationAllocation(
    lineValues: number[],
    transportationCharges: number,
  ): number[] {
    if (transportationCharges <= 0 || lineValues.length === 0) {
      return lineValues.map(() => 0);
    }

    const orderSubtotal = lineValues.reduce((acc, val) => acc + val, 0);

    if (orderSubtotal > 0) {
      // Proportional allocation to discounted line value
      const allocatedCosts = lineValues.map(
        (val) => (Math.round((val / orderSubtotal) * transportationCharges * 100) / 100),
      );
      // Distribute nearest-paisa remainder to largest line item
      const sumAllocated = allocatedCosts.reduce((acc, c) => acc + c, 0);
      const delta = Math.round((transportationCharges - sumAllocated) * 100) / 100;
      if (delta !== 0) {
        let maxIdx = 0;
        for (let i = 1; i < lineValues.length; i++) {
          if (lineValues[i] > lineValues[maxIdx]) {
            maxIdx = i;
          }
        }
        allocatedCosts[maxIdx] =
          Math.round((allocatedCosts[maxIdx] + delta) * 100) / 100;
      }
      return allocatedCosts;
    }

    // Fallback: Equal allocation if order subtotal is 0
    const share = Math.round((transportationCharges / lineValues.length) * 100) / 100;
    const allocatedCosts = lineValues.map(() => share);
    const sumAllocated = allocatedCosts.reduce((acc, c) => acc + c, 0);
    const delta = Math.round((transportationCharges - sumAllocated) * 100) / 100;
    allocatedCosts[0] = Math.round((allocatedCosts[0] + delta) * 100) / 100;
    return allocatedCosts;
  }

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
      transportationCharges: Number(r.transportation_charges || 0),
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
      transportationCost: Number(r.transportation_cost || 0),
      landedRate: Number(r.landed_rate || 0),
      createdAt: r.created_at,
    };
  }
}
