import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { AuditService } from '../../../core/audit/audit.service';
import { DatabasePool } from '../../../core/database/connection';
import { UnitOfWork } from '../../../core/database/unit-of-work';
import { CreateBomDto } from '../dto/bom.dto';
import {
  CancelProductionOrderDto,
  CompleteProductionOrderDto,
  CreateProductionOrderDto,
  ProductionStatusEnum,
} from '../dto/production-order.dto';
import { ProductionQueryDto } from '../dto/production-query.dto';

@Injectable()
export class ProductionService {
  constructor(
    private readonly db: DatabasePool,
    private readonly uow: UnitOfWork,
    private readonly auditService: AuditService,
  ) {}

  // --------------------------------------------------------------------------
  // 8.1 List Production Orders with Summary Metrics
  // --------------------------------------------------------------------------
  async findAll(query: ProductionQueryDto) {
    const page = Math.max(1, query.page || 1);
    const limit = Math.max(1, query.limit || 50);
    const offset = (page - 1) * limit;

    const conditions: string[] = ['po.is_deleted = false'];
    const params: any[] = [];
    let pIdx = 1;

    if (query.status) {
      conditions.push(`po.status = $${pIdx}`);
      params.push(query.status);
      pIdx++;
    }

    if (query.finishedProductId) {
      conditions.push(`po.finished_product_id = $${pIdx}`);
      params.push(query.finishedProductId);
      pIdx++;
    }

    if (query.salesOrderId) {
      conditions.push(`po.sales_order_id = $${pIdx}`);
      params.push(query.salesOrderId);
      pIdx++;
    }

    if (query.projectId) {
      conditions.push(`po.project_id = $${pIdx}`);
      params.push(query.projectId);
      pIdx++;
    }

    if (query.fromDate) {
      conditions.push(`po.production_date >= $${pIdx}`);
      params.push(query.fromDate);
      pIdx++;
    }

    if (query.toDate) {
      conditions.push(`po.production_date <= $${pIdx}`);
      params.push(query.toDate);
      pIdx++;
    }

    if (query.search?.trim()) {
      conditions.push(
        `(po.production_number ILIKE $${pIdx} OR po.finished_product_name ILIKE $${pIdx} OR po.finished_product_code ILIKE $${pIdx})`,
      );
      params.push(`%${query.search.trim()}%`);
      pIdx++;
    }

    const whereClause = `WHERE ${conditions.join(' AND ')}`;

    // 1. Summary Metrics
    const summaryRes = await this.db.query<{
      total_orders: string;
      completed_batches: string;
      in_progress_batches: string;
      planned_batches: string;
      total_production_cost: string;
    }>(
      `SELECT
         COUNT(*)::int as total_orders,
         COALESCE(SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END), 0)::int as completed_batches,
         COALESCE(SUM(CASE WHEN status = 'inProgress' THEN 1 ELSE 0 END), 0)::int as in_progress_batches,
         COALESCE(SUM(CASE WHEN status = 'planned' THEN 1 ELSE 0 END), 0)::int as planned_batches,
         COALESCE(SUM(CASE WHEN status != 'cancelled' THEN total_production_cost ELSE 0 END), 0)::numeric(18,2) as total_production_cost
       FROM production_orders po
       WHERE po.is_deleted = false`,
    );

    // 2. Count for pagination
    const countRes = await this.db.query<{ count: string }>(
      `SELECT COUNT(*)::int as count FROM production_orders po ${whereClause}`,
      params,
    );
    const totalCount = parseInt(countRes.rows[0]?.count || '0', 10);

    // 3. Paginated Order List
    const ordersRes = await this.db.query<any>(
      `SELECT
         po.*,
         COALESCE(u.name, 'System') as created_by_name
       FROM production_orders po
       LEFT JOIN users u ON po.created_by = u.id
       ${whereClause}
       ORDER BY po.production_date DESC, po.created_at DESC
       LIMIT $${pIdx} OFFSET $${pIdx + 1}`,
      [...params, limit, offset],
    );

    return {
      summary: {
        totalOrders: Number(summaryRes.rows[0]?.total_orders || 0),
        completedBatches: Number(summaryRes.rows[0]?.completed_batches || 0),
        inProgressBatches: Number(summaryRes.rows[0]?.in_progress_batches || 0),
        plannedBatches: Number(summaryRes.rows[0]?.planned_batches || 0),
        totalProductionCost: Number(summaryRes.rows[0]?.total_production_cost || 0),
      },
      orders: ordersRes.rows.map((r) => this.mapOrderRow(r)),
      pagination: {
        totalItems: totalCount,
        currentPage: page,
        totalPages: Math.ceil(totalCount / limit) || 1,
        limit,
      },
    };
  }

  // --------------------------------------------------------------------------
  // 8.2 Get Production Order by ID (with rawMaterialsUsed)
  // --------------------------------------------------------------------------
  async findById(id: string) {
    const orderRes = await this.db.query<any>(
      `SELECT po.*, COALESCE(u.name, 'System') as created_by_name
       FROM production_orders po
       LEFT JOIN users u ON po.created_by = u.id
       WHERE po.id = $1`,
      [id],
    );

    if (orderRes.rows.length === 0) {
      throw new NotFoundException(`Production Order with ID ${id} not found`);
    }

    const itemsRes = await this.db.query<any>(
      `SELECT * FROM production_raw_materials WHERE production_order_id = $1 ORDER BY created_at ASC`,
      [id],
    );

    return this.mapOrderRow(
      orderRes.rows[0],
      itemsRes.rows.map((i) => this.mapUsageRow(i)),
    );
  }

  // --------------------------------------------------------------------------
  // 8.3 Create & Complete Production Order (Atomic Consumption & Output)
  // --------------------------------------------------------------------------
  async create(dto: CreateProductionOrderDto, userId: string, correlationId?: string) {
    return this.uow.runInTransaction(async (client) => {
      // 1. Generate unique production document sequence number
      const seqRes = await client.query<{ count: string }>(
        `SELECT COUNT(*)::int as count FROM production_orders`,
      );
      const nextSeq = parseInt(seqRes.rows[0]?.count || '0', 10) + 1;
      const currentYear = new Date().getFullYear();
      const productionNumber = `PRD-${currentYear}-${String(nextSeq).padStart(4, '0')}`;

      const status = dto.status || ProductionStatusEnum.completed;
      const plannedQty = Number(dto.plannedQuantity);
      const actualQty = Number(dto.actualQuantityProduced ?? plannedQty);
      const rawMaterials = (dto.rawMaterialsUsed && dto.rawMaterialsUsed.length > 0)
        ? dto.rawMaterialsUsed
        : (dto.rawMaterials || []);

      // Auto-resolve finished product metadata if not provided
      let finishedProductName = dto.finishedProductName;
      let finishedProductCode = dto.finishedProductCode;
      let unit = dto.unit;

      if (!finishedProductName || !unit) {
        const fpRes = await client.query<{ name: string; item_code: string; unit_symbol: string }>(
          `SELECT fp.name, fp.item_code, u.symbol as unit_symbol
           FROM finished_products fp
           JOIN measurement_units u ON fp.unit_id = u.id
           WHERE fp.id = $1`,
          [dto.finishedProductId],
        );
        if (fpRes.rows.length === 0) {
          throw new BadRequestException(`Finished Product ${dto.finishedProductId} not found`);
        }
        finishedProductName = finishedProductName || fpRes.rows[0].name;
        finishedProductCode = finishedProductCode || fpRes.rows[0].item_code;
        unit = unit || fpRes.rows[0].unit_symbol;
      }

      // Auto-resolve raw material names and units if not provided
      for (const rm of rawMaterials) {
        if (!rm.rawMaterialName || !rm.unit) {
          const rmInfo = await client.query<{ name: string; item_code: string; unit_symbol: string }>(
            `SELECT rm.name, rm.item_code, u.symbol as unit_symbol
             FROM raw_materials rm
             JOIN measurement_units u ON rm.unit_id = u.id
             WHERE rm.id = $1`,
            [rm.rawMaterialId],
          );
          if (rmInfo.rows.length > 0) {
            rm.rawMaterialName = rm.rawMaterialName || rmInfo.rows[0].name;
            rm.rawMaterialCode = rm.rawMaterialCode || rmInfo.rows[0].item_code;
            rm.unit = rm.unit || rmInfo.rows[0].unit_symbol;
          }
        }
      }

      // 2. Stock Validation (if completed)
      if (status === ProductionStatusEnum.completed && !dto.overrideStockValidation) {
        for (const rm of rawMaterials) {
          const checkRes = await client.query<{ current_stock: string; name: string; unit: string }>(
            `SELECT rm.current_stock, rm.name, u.symbol as unit
             FROM raw_materials rm
             JOIN measurement_units u ON rm.unit_id = u.id
             WHERE rm.id = $1 AND rm.is_deleted = false`,
            [rm.rawMaterialId],
          );
          if (checkRes.rows.length === 0) {
            throw new BadRequestException(`Raw Material ${rm.rawMaterialId} not found or inactive`);
          }
          const availableStock = Number(checkRes.rows[0].current_stock);
          if (availableStock < Number(rm.quantityUsed)) {
            throw new BadRequestException(
              `Insufficient stock for ${checkRes.rows[0].name}! Available: ${availableStock} ${checkRes.rows[0].unit}, Required: ${rm.quantityUsed} ${checkRes.rows[0].unit}`,
            );
          }
        }
      }

      const rawMaterialCost = Number(dto.rawMaterialCost || 0);
      const labourCost = Number(dto.labourCost || 0);
      const otherExpenses = Number(dto.otherExpenses || 0);
      const totalProductionCost = Number(dto.totalProductionCost ?? (rawMaterialCost + labourCost + otherExpenses));
      const costPerUnit = Number(dto.costPerUnit ?? (actualQty > 0 ? totalProductionCost / actualQty : 0));

      // 3. Insert Production Order Header
      const poRes = await client.query<any>(
        `INSERT INTO production_orders (
           production_number, finished_product_id, finished_product_name, finished_product_code,
           unit, planned_quantity, actual_quantity_produced, raw_material_cost, labour_cost,
           other_expenses, total_production_cost, cost_per_unit, production_date, status,
           sales_order_id, sales_order_number, project_id, project_name, notes, created_by
         )
         VALUES (
           $1, $2, $3, $4,
           $5, $6, $7, $8, $9,
           $10, $11, $12, $13, $14,
           $15, $16, $17, $18, $19, $20
         )
         RETURNING *`,
        [
          productionNumber,
          dto.finishedProductId,
          finishedProductName,
          finishedProductCode || '',
          unit,
          plannedQty,
          actualQty,
          rawMaterialCost,
          labourCost,
          otherExpenses,
          totalProductionCost,
          costPerUnit,
          dto.productionDate ? new Date(dto.productionDate) : new Date(),
          status,
          dto.salesOrderId || null,
          dto.salesOrderNumber || null,
          dto.projectId || null,
          dto.projectName || null,
          dto.notes || null,
          userId,
        ],
      );
      const orderRecord = poRes.rows[0];

      // 4. Insert Raw Materials Used & Deduct Stock (if completed)
      const insertedUsages: any[] = [];
      for (const rm of rawMaterials) {
        const usageRes = await client.query<any>(
          `INSERT INTO production_raw_materials (
             production_order_id, raw_material_id, raw_material_name, raw_material_code,
             quantity_used, unit, unit_cost, total_cost
           )
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
           RETURNING *`,
          [
            orderRecord.id,
            rm.rawMaterialId,
            rm.rawMaterialName,
            rm.rawMaterialCode || '',
            Number(rm.quantityUsed),
            rm.unit,
            Number(rm.unitCost || 0),
            Number(rm.totalCost || 0),
          ],
        );
        insertedUsages.push(this.mapUsageRow(usageRes.rows[0]));

        if (status === ProductionStatusEnum.completed) {
          // Decrement Raw Material Stock with Row Locking
          const updRm = await client.query<{ current_stock: string }>(
            `UPDATE raw_materials
             SET current_stock = GREATEST(0, current_stock - $1), updated_at = now()
             WHERE id = $2 AND is_deleted = false
             RETURNING current_stock`,
            [Number(rm.quantityUsed), rm.rawMaterialId],
          );
          const newBal = Number(updRm.rows[0]?.current_stock || 0);

          // Append to Immutable Stock Movement Ledger
          await client.query(
            `INSERT INTO stock_movements (
               date, item_id, item_type, transaction_type, reference_number,
               stock_in, stock_out, current_balance, unit, notes, performed_by
             )
             VALUES (now(), $1, 'rawMaterial', 'productionConsumption', $2, 0, $3, $4, $5, $6, $7)`,
            [
              rm.rawMaterialId,
              productionNumber,
              Number(rm.quantityUsed),
              newBal,
              rm.unit || unit || 'unit',
              `Consumed for production of ${finishedProductName} (${productionNumber})`,
              userId,
            ],
          );
        }
      }

      // 5. Inward Finished Goods Output (if completed)
      if (status === ProductionStatusEnum.completed && actualQty > 0) {
        const updFp = await client.query<{ current_stock: string }>(
          `UPDATE finished_products
           SET current_stock = current_stock + $1,
               produced_stock = produced_stock + $1,
               updated_at = now()
           WHERE id = $2 AND is_deleted = false
           RETURNING current_stock`,
          [actualQty, dto.finishedProductId],
        );
        const newFpBal = Number(updFp.rows[0]?.current_stock || 0);

        // Append to Immutable Stock Movement Ledger
        await client.query(
          `INSERT INTO stock_movements (
             date, item_id, item_type, transaction_type, reference_number,
             stock_in, stock_out, current_balance, unit, notes, performed_by
           )
           VALUES (now(), $1, 'finishedProduct', 'productionOutput', $2, $3, 0, $4, $5, $6, $7)`,
          [
            dto.finishedProductId,
            productionNumber,
            actualQty,
            newFpBal,
            unit || 'unit',
            `Produced manufacturing batch (${productionNumber})${dto.salesOrderNumber ? ' for SO ' + dto.salesOrderNumber : ''}`,
            userId,
          ],
        );

        // 6. If linked to a Sales Order shortage, reserve stock
        if (dto.salesOrderId) {
          await client.query(
            `UPDATE finished_products
             SET reserved_stock = reserved_stock + $1, updated_at = now()
             WHERE id = $2`,
            [actualQty, dto.finishedProductId],
          );
        }
      }

      // Record Audit
      await this.auditService.record(
        {
          userId,
          action: 'production.create',
          entityType: 'ProductionOrder',
          entityId: orderRecord.id,
          afterSnapshot: { ...orderRecord, rawMaterialsUsed: insertedUsages },
          reason: `Production Order ${productionNumber} created with status ${status}`,
          correlationId,
        },
        client,
      );

      return this.mapOrderRow(orderRecord, insertedUsages);
    });
  }

  // --------------------------------------------------------------------------
  // 8.4 Cancel / Soft Delete Production Order with Stock Rollback
  // --------------------------------------------------------------------------
  async cancel(id: string, dto: CancelProductionOrderDto, userId: string, correlationId?: string) {
    return this.uow.runInTransaction(async (client) => {
      const orderRes = await client.query<any>(
        `SELECT * FROM production_orders WHERE id = $1 FOR UPDATE`,
        [id],
      );

      if (orderRes.rows.length === 0) {
        throw new NotFoundException(`Production Order with ID ${id} not found`);
      }
      const order = orderRes.rows[0];

      if (order.status === ProductionStatusEnum.cancelled) {
        throw new BadRequestException(`Production Order ${order.production_number} is already cancelled`);
      }

      // If order was completed, roll back consumed raw materials and produced goods
      if (order.status === ProductionStatusEnum.completed) {
        const usagesRes = await client.query<any>(
          `SELECT * FROM production_raw_materials WHERE production_order_id = $1`,
          [id],
        );

        // Revert Raw Materials Stock
        for (const u of usagesRes.rows) {
          const qty = Number(u.quantity_used);
          const updRm = await client.query<{ current_stock: string }>(
            `UPDATE raw_materials
             SET current_stock = current_stock + $1, updated_at = now()
             WHERE id = $2
             RETURNING current_stock`,
            [qty, u.raw_material_id],
          );
          const newBal = Number(updRm.rows[0]?.current_stock || 0);

          await client.query(
            `INSERT INTO stock_movements (
               date, item_id, item_type, transaction_type, reference_number,
               stock_in, stock_out, current_balance, unit, notes, performed_by
             )
             VALUES (now(), $1, 'rawMaterial', 'adjustment', $2, $3, 0, $4, $5, $6, $7)`,
            [
              u.raw_material_id,
              order.production_number,
              qty,
              newBal,
              u.unit,
              `Reversed consumption: Cancelled production batch ${order.production_number}`,
              userId,
            ],
          );
        }

        // Revert Produced Finished Goods
        const producedQty = Number(order.actual_quantity_produced);
        if (producedQty > 0) {
          const updFp = await client.query<{ current_stock: string }>(
            `UPDATE finished_products
             SET current_stock = GREATEST(0, current_stock - $1),
                 produced_stock = GREATEST(0, produced_stock - $1),
                 updated_at = now()
             WHERE id = $2
             RETURNING current_stock`,
            [producedQty, order.finished_product_id],
          );
          const newFpBal = Number(updFp.rows[0]?.current_stock || 0);

          await client.query(
            `INSERT INTO stock_movements (
               date, item_id, item_type, transaction_type, reference_number,
               stock_in, stock_out, current_balance, unit, notes, performed_by
             )
             VALUES (now(), $1, 'finishedProduct', 'adjustment', $2, 0, $3, $4, $5, $6, $7)`,
            [
              order.finished_product_id,
              order.production_number,
              producedQty,
              newFpBal,
              order.unit,
              `Reversed production output: Cancelled production batch ${order.production_number}`,
              userId,
            ],
          );
        }
      }

      // Mark Order as Cancelled & Soft Deleted
      const updOrderRes = await client.query<any>(
        `UPDATE production_orders
         SET status = 'cancelled', is_deleted = true, deleted_reason = $1, deleted_at = now(), updated_at = now()
         WHERE id = $2
         RETURNING *`,
        [dto.reason, id],
      );

      // Record Audit
      await this.auditService.record(
        {
          userId,
          action: 'production.cancel',
          entityType: 'ProductionOrder',
          entityId: id,
          beforeSnapshot: order,
          afterSnapshot: updOrderRes.rows[0],
          reason: dto.reason,
          correlationId,
        },
        client,
      );

      return this.mapOrderRow(updOrderRes.rows[0]);
    });
  }

  // --------------------------------------------------------------------------
  // 8.5 Bill of Materials (BOM) Management
  // --------------------------------------------------------------------------
  async getBomByProductId(finishedProductId: string) {
    const bomRes = await this.db.query<any>(
      `SELECT * FROM bill_of_materials WHERE finished_product_id = $1 AND is_active = true ORDER BY created_at DESC LIMIT 1`,
      [finishedProductId],
    );

    if (bomRes.rows.length === 0) {
      return null;
    }

    const bom = bomRes.rows[0];
    const itemsRes = await this.db.query<any>(
      `SELECT * FROM bom_items WHERE bom_id = $1 ORDER BY created_at ASC`,
      [bom.id],
    );

    return {
      id: bom.id,
      finishedProductId: bom.finished_product_id,
      name: bom.name,
      description: bom.description,
      outputQuantity: Number(bom.output_quantity),
      isActive: bom.is_active,
      createdAt: bom.created_at,
      updatedAt: bom.updated_at,
      items: itemsRes.rows.map((i) => ({
        id: i.id,
        rawMaterialId: i.raw_material_id,
        rawMaterialName: i.raw_material_name,
        rawMaterialCode: i.raw_material_code,
        quantityPerUnit: Number(i.quantity_per_unit),
        unit: i.unit,
      })),
    };
  }

  async createOrUpdateBom(dto: CreateBomDto, userId: string) {
    return this.uow.runInTransaction(async (client) => {
      // Deactivate previous active BOMs for this product
      await client.query(
        `UPDATE bill_of_materials SET is_active = false, updated_at = now() WHERE finished_product_id = $1`,
        [dto.finishedProductId],
      );

      const bomRes = await client.query<any>(
        `INSERT INTO bill_of_materials (
           finished_product_id, name, description, output_quantity, is_active
         )
         VALUES ($1, $2, $3, $4, $5)
         RETURNING *`,
        [
          dto.finishedProductId,
          dto.name,
          dto.description || null,
          Number(dto.outputQuantity || 1),
          dto.isActive ?? true,
        ],
      );
      const bom = bomRes.rows[0];

      const insertedItems: any[] = [];
      for (const item of dto.items) {
        const itemRes = await client.query<any>(
          `INSERT INTO bom_items (
             bom_id, raw_material_id, raw_material_name, raw_material_code,
             quantity_per_unit, unit
           )
           VALUES ($1, $2, $3, $4, $5, $6)
           RETURNING *`,
          [
            bom.id,
            item.rawMaterialId,
            item.rawMaterialName,
            item.rawMaterialCode || '',
            Number(item.quantityPerUnit),
            item.unit,
          ],
        );
        insertedItems.push({
          id: itemRes.rows[0].id,
          rawMaterialId: itemRes.rows[0].raw_material_id,
          rawMaterialName: itemRes.rows[0].raw_material_name,
          rawMaterialCode: itemRes.rows[0].raw_material_code,
          quantityPerUnit: Number(itemRes.rows[0].quantity_per_unit),
          unit: itemRes.rows[0].unit,
        });
      }

      return {
        id: bom.id,
        finishedProductId: bom.finished_product_id,
        name: bom.name,
        description: bom.description,
        outputQuantity: Number(bom.output_quantity),
        isActive: bom.is_active,
        createdAt: bom.created_at,
        updatedAt: bom.updated_at,
        items: insertedItems,
      };
    });
  }

  // --------------------------------------------------------------------------
  // Mappers
  // --------------------------------------------------------------------------
  private mapOrderRow(r: any, items: any[] = []) {
    return {
      id: r.id,
      productionNumber: r.production_number,
      finishedProductId: r.finished_product_id,
      finishedProductName: r.finished_product_name,
      finishedProductCode: r.finished_product_code,
      unit: r.unit,
      plannedQuantity: Number(r.planned_quantity),
      actualQuantityProduced: Number(r.actual_quantity_produced),
      rawMaterialCost: Number(r.raw_material_cost),
      labourCost: Number(r.labour_cost),
      otherExpenses: Number(r.other_expenses),
      totalProductionCost: Number(r.total_production_cost),
      costPerUnit: Number(r.cost_per_unit),
      productionDate: r.production_date,
      status: r.status,
      salesOrderId: r.sales_order_id,
      salesOrderNumber: r.sales_order_number,
      projectId: r.project_id,
      projectName: r.project_name,
      notes: r.notes,
      isDeleted: r.is_deleted,
      deletedReason: r.deleted_reason,
      deletedAt: r.deleted_at,
      createdBy: r.created_by_name || 'System',
      createdAt: r.created_at,
      updatedAt: r.updated_at,
      rawMaterialsUsed: items,
    };
  }

  private mapUsageRow(r: any) {
    return {
      id: r.id,
      productionOrderId: r.production_order_id,
      rawMaterialId: r.raw_material_id,
      rawMaterialName: r.raw_material_name,
      rawMaterialCode: r.raw_material_code,
      quantityUsed: Number(r.quantity_used),
      unit: r.unit,
      unitCost: Number(r.unit_cost),
      totalCost: Number(r.total_cost),
      createdAt: r.created_at,
    };
  }
}
