import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { DatabasePool } from '../../../core/database/connection';
import { AppLogger } from '../../../core/logging/logger.service';
import {
  CreateDeliveryDto,
  CreateDirectSaleDto,
  CreateInvoiceFromDeliveryDto,
  CreateQuotationDto,
  CreateQuotationRevisionDto,
  CreateSalesOrderDto,
  CreateSalesReturnDto,
  DisburseRefundDto,
  RecordAdvancePaymentDto,
  RecordInvoicePaymentDto,
  SalesQueryDto,
  UpdateDeliveryTrackingDto,
  UpdateQuotationStatusDto,
  UpdateSalesOrderStatusDto,
} from '../dto/sales.dto';

@Injectable()
export class SalesService {
  constructor(
    private readonly db: DatabasePool,
    private readonly logger: AppLogger,
  ) {}

  // ==========================================================================
  // HELPER METHODS
  // ==========================================================================
  private async getNextSequenceNumber(prefix: string): Promise<string> {
    const year = new Date().getFullYear();
    const countRes = await this.db.query<{ count: string }>(
      `SELECT count(*)::text as count FROM sales WHERE invoice_number LIKE $1`,
      [`%${prefix}/${year}/%`],
    );
    const seq = parseInt(countRes.rows[0].count, 10) + 1;
    return `DLZ/${prefix}/${year}/${seq.toString().padStart(4, '0')}`;
  }

  private async getPartyDetails(partyType: string, partyId: string) {
    if (partyType === 'customer') {
      const res = await this.db.query<{ name: string; mobile: string; email: string; gst_number: string; address: string }>(
        `SELECT name, mobile, email, gst_number, address FROM customers WHERE id = $1`,
        [partyId],
      );
      if (res.rows.length === 0) throw new NotFoundException(`Customer ${partyId} not found`);
      return res.rows[0];
    } else if (partyType === 'dealer') {
      const res = await this.db.query<{ name: string; contact_person: string; mobile: string; email: string; gst_number: string; address: string }>(
        `SELECT name, contact_person, mobile, email, gst_number, address FROM dealers WHERE id = $1`,
        [partyId],
      );
      if (res.rows.length === 0) throw new NotFoundException(`Dealer ${partyId} not found`);
      return res.rows[0];
    } else {
      const res = await this.db.query<{ name: string; company_name: string; mobile: string; email: string; gst_number: string; address: string; default_commission_rate: string }>(
        `SELECT name, company_name, mobile, email, gst_number, address, default_commission_rate FROM architects WHERE id = $1`,
        [partyId],
      );
      if (res.rows.length === 0) throw new NotFoundException(`Architect ${partyId} not found`);
      return res.rows[0];
    }
  }

  // ==========================================================================
  // 1. QUOTATIONS
  // ==========================================================================
  async createQuotation(dto: CreateQuotationDto, userId?: string, correlationId?: string) {
    const party = await this.getPartyDetails(dto.partyType, dto.partyId);
    let archName: string | null = null;
    if (dto.architectId) {
      const archRes = await this.db.query<{ name: string }>(`SELECT name FROM architects WHERE id = $1`, [dto.architectId]);
      if (archRes.rows.length > 0) archName = archRes.rows[0].name;
    }

    const invoiceNumber = await this.getNextSequenceNumber('QT');
    const validUntil = new Date(Date.now() + (dto.validDays ?? 30) * 86400000);

    // Compute line items
    let subtotal = 0;
    let totalDiscount = 0;
    let totalGst = 0;

    const computedItems: any[] = [];
    for (const item of dto.items) {
      const fpRes = await this.db.query<{ name: string; item_code: string; unit: string; customer_selling_price: string; gst_percent: string }>(
        `SELECT fp.name, fp.item_code, mu.symbol as unit, fp.customer_selling_price, fp.gst_percent
         FROM finished_products fp
         JOIN measurement_units mu ON mu.id = fp.unit_id
         WHERE fp.id = $1`,
        [item.finishedProductId],
      );
      if (fpRes.rows.length === 0) {
        throw new NotFoundException(`Finished product ${item.finishedProductId} not found`);
      }
      const fp = fpRes.rows[0];
      const rate = item.rate ?? parseFloat(fp.customer_selling_price);
      const discount = item.discountAmount ?? 0;
      const gstPercent = item.gstPercent ?? parseFloat(fp.gst_percent);
      const taxable = Math.max(0, item.quantity * rate - discount);
      const gst = taxable * (gstPercent / 100);
      const lineTotal = taxable + gst;

      subtotal += item.quantity * rate;
      totalDiscount += discount;
      totalGst += gst;

      computedItems.push({
        finishedProductId: item.finishedProductId,
        finishedProductName: fp.name,
        finishedProductCode: fp.item_code,
        productDescription: item.productDescription ?? '',
        quantity: item.quantity,
        unit: fp.unit,
        rate,
        discountAmount: discount,
        gstPercent,
        taxableAmount: taxable,
        cgstAmount: dto.isInterStateTax ? 0 : gst / 2,
        sgstAmount: dto.isInterStateTax ? 0 : gst / 2,
        igstAmount: dto.isInterStateTax ? gst : 0,
        lineTotal,
      });
    }

    const taxableAmount = Math.max(0, subtotal - totalDiscount);
    const grandTotal = taxableAmount + totalGst;

    let projName: string | null = null;
    if (dto.projectId) {
      const pRes = await this.db.query<{ name: string }>(`SELECT name FROM projects WHERE id = $1`, [dto.projectId]);
      if (pRes.rows.length > 0) projName = pRes.rows[0].name;
    }

    const saleRes = await this.db.query<{ id: string }>(
      `INSERT INTO sales (
        invoice_number, document_type, party_type, party_id, party_name,
        customer_contact_person, customer_mobile, customer_email, customer_gst_number,
        billing_address, shipping_address, project_id, project_name, architect_id, architect_name,
        sales_executive, valid_until, subtotal_amount, discount_amount, taxable_amount,
        cgst_amount, sgst_amount, igst_amount, gst_amount, total_amount, pending_amount,
        is_inter_state_tax, quotation_status, status, notes, terms_and_conditions, created_by
      ) VALUES (
        $1, 'quotation', $2, $3, $4,
        $5, $6, $7, $8,
        $9, $10, $11, $12, $13, $14,
        $15, $16, $17, $18, $19,
        $20, $21, $22, $23, $24, $25,
        $26, $27, 'draft', $28, $29, $30
      ) RETURNING id`,
      [
        invoiceNumber, dto.partyType, dto.partyId, party.name,
        (party as any).contact_person ?? null, party.mobile, party.email, party.gst_number,
        party.address, party.address, dto.projectId ?? null, projName, dto.architectId ?? null, archName,
        dto.salesExecutive ?? null, validUntil, subtotal, totalDiscount, taxableAmount,
        dto.isInterStateTax ? 0 : totalGst / 2, dto.isInterStateTax ? 0 : totalGst / 2, dto.isInterStateTax ? totalGst : 0, totalGst, grandTotal, grandTotal,
        dto.isInterStateTax ?? false, dto.isDraft ? 'draft' : 'sent', dto.notes ?? null, dto.termsAndConditions ?? null, userId ?? null,
      ],
    );
    const saleId = saleRes.rows[0].id;

    for (const i of computedItems) {
      await this.db.query(
        `INSERT INTO sale_items (
          sale_id, finished_product_id, finished_product_name, finished_product_code,
          product_description, quantity, unit, rate, discount_amount, gst_percent,
          taxable_amount, cgst_amount, sgst_amount, igst_amount, line_total
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)`,
        [
          saleId, i.finishedProductId, i.finishedProductName, i.finishedProductCode,
          i.productDescription, i.quantity, i.unit, i.rate, i.discountAmount, i.gstPercent,
          i.taxableAmount, i.cgstAmount, i.sgstAmount, i.igstAmount, i.lineTotal,
        ],
      );
    }

    return this.findById(saleId);
  }

  async createQuotationRevision(quotationId: string, dto: CreateQuotationRevisionDto, userId?: string, correlationId?: string) {
    const parent = await this.findById(quotationId);
    if (!parent) throw new NotFoundException(`Quotation ${quotationId} not found`);

    const newRevNumber = (parent.revisionNumber ?? 0) + 1;
    const baseNumber = parent.invoiceNumber.split('-R')[0];
    const newInvoiceNumber = `${baseNumber}-R${newRevNumber}`;

    // Mark parent as superseded
    await this.db.query(`UPDATE sales SET quotation_status = 'superseded', updated_at = now() WHERE id = $1`, [quotationId]);

    // Calculate items
    let subtotal = 0;
    let totalDiscount = dto.discountAmount ?? parent.discountAmount ?? 0;
    let totalGst = 0;

    const computedItems: any[] = [];
    const itemsToProcess = dto.items && dto.items.length > 0 ? dto.items : parent.items;

    for (const item of itemsToProcess) {
      const fpRes = await this.db.query<{ name: string; item_code: string; unit: string; customer_selling_price: string; gst_percent: string }>(
        `SELECT fp.name, fp.item_code, mu.symbol as unit, fp.customer_selling_price, fp.gst_percent
         FROM finished_products fp
         JOIN measurement_units mu ON mu.id = fp.unit_id
         WHERE fp.id = $1`,
        [item.finishedProductId],
      );
      const fp = fpRes.rows[0];
      const rate = item.rate ?? parseFloat(fp.customer_selling_price);
      const discount = item.discountAmount ?? 0;
      const gstPercent = item.gstPercent ?? parseFloat(fp.gst_percent);
      const taxable = Math.max(0, item.quantity * rate - discount);
      const gst = taxable * (gstPercent / 100);
      const lineTotal = taxable + gst;

      subtotal += item.quantity * rate;
      totalDiscount += discount;
      totalGst += gst;

      computedItems.push({
        finishedProductId: item.finishedProductId,
        finishedProductName: fp.name,
        finishedProductCode: fp.item_code,
        productDescription: item.productDescription ?? '',
        quantity: item.quantity,
        unit: fp.unit,
        rate,
        discountAmount: discount,
        gstPercent,
        taxableAmount: taxable,
        cgstAmount: parent.isInterStateTax ? 0 : gst / 2,
        sgstAmount: parent.isInterStateTax ? 0 : gst / 2,
        igstAmount: parent.isInterStateTax ? gst : 0,
        lineTotal,
      });
    }

    const taxableAmount = Math.max(0, subtotal - totalDiscount);
    const grandTotal = taxableAmount + totalGst;

    const saleRes = await this.db.query<{ id: string }>(
      `INSERT INTO sales (
        invoice_number, document_type, party_type, party_id, party_name,
        customer_contact_person, customer_mobile, customer_email, customer_gst_number,
        billing_address, shipping_address, architect_id, architect_name,
        sales_executive, valid_until, subtotal_amount, discount_amount, taxable_amount,
        cgst_amount, sgst_amount, igst_amount, gst_amount, total_amount, pending_amount,
        is_inter_state_tax, quotation_status, status, notes, terms_and_conditions,
        revision_number, original_quotation_id, parent_quotation_id, parent_quotation_number, created_by
      ) VALUES (
        $1, 'quotation', $2, $3, $4,
        $5, $6, $7, $8,
        $9, $10, $11, $12,
        $13, $14, $15, $16, $17,
        $18, $19, $20, $21, $22, $23,
        $24, $25, 'draft', $26, $27,
        $28, $29, $30, $31, $32
      ) RETURNING id`,
      [
        newInvoiceNumber, parent.partyType, parent.partyId, parent.partyName,
        parent.customerContactPerson, parent.customerMobile, parent.customerEmail, parent.customerGstNumber,
        parent.billingAddress, parent.shippingAddress, parent.architectId, parent.architectName,
        parent.salesExecutive, parent.validUntil, subtotal, totalDiscount, taxableAmount,
        parent.isInterStateTax ? 0 : totalGst / 2, parent.isInterStateTax ? 0 : totalGst / 2, parent.isInterStateTax ? totalGst : 0, totalGst, grandTotal, grandTotal,
        parent.isInterStateTax, dto.isDraft ? 'draft' : 'sent', dto.notes ?? parent.notes, dto.termsAndConditions ?? parent.termsAndConditions,
        newRevNumber, parent.originalQuotationId ?? parent.id, parent.id, parent.invoiceNumber, userId ?? null,
      ],
    );
    const revisionId = saleRes.rows[0].id;

    for (const i of computedItems) {
      await this.db.query(
        `INSERT INTO sale_items (
          sale_id, finished_product_id, finished_product_name, finished_product_code,
          product_description, quantity, unit, rate, discount_amount, gst_percent,
          taxable_amount, cgst_amount, sgst_amount, igst_amount, line_total
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)`,
        [
          revisionId, i.finishedProductId, i.finishedProductName, i.finishedProductCode,
          i.productDescription, i.quantity, i.unit, i.rate, i.discountAmount, i.gstPercent,
          i.taxableAmount, i.cgstAmount, i.sgstAmount, i.igstAmount, i.lineTotal,
        ],
      );
    }

    return this.findById(revisionId);
  }

  async updateQuotationStatus(id: string, dto: UpdateQuotationStatusDto, userId?: string, correlationId?: string) {
    const quote = await this.findById(id);
    if (!quote) throw new NotFoundException(`Quotation ${id} not found`);

    await this.db.query(
      `UPDATE sales SET quotation_status = $1, updated_at = now() WHERE id = $2`,
      [dto.status, id],
    );
    return this.findById(id);
  }

  // ==========================================================================
  // 2. PROFORMA INVOICES
  // ==========================================================================
  async convertToProforma(quotationId: string, userId?: string, correlationId?: string) {
    const q = await this.findById(quotationId);
    if (!q) throw new NotFoundException(`Quotation ${quotationId} not found`);
    if (q.quotationStatus === 'converted') {
      throw new BadRequestException('Quotation has already been converted');
    }

    const piNumber = await this.getNextSequenceNumber('PI');

    const proformaRes = await this.db.query<{ id: string }>(
      `INSERT INTO sales (
        invoice_number, document_type, party_type, party_id, party_name,
        customer_contact_person, customer_mobile, customer_email, customer_gst_number,
        billing_address, shipping_address, project_id, project_name, architect_id, architect_name,
        sales_executive, subtotal_amount, discount_amount, taxable_amount,
        cgst_amount, sgst_amount, igst_amount, gst_amount, total_amount, pending_amount,
        is_inter_state_tax, proforma_status, status, quotation_reference_id, parent_quotation_number,
        terms_and_conditions, notes, created_by
      ) VALUES (
        $1, 'proformaInvoice', $2, $3, $4,
        $5, $6, $7, $8,
        $9, $10, $11, $12, $13, $14,
        $15, $16, $17, $18,
        $19, $20, $21, $22, $23, $24,
        $25, 'issued', 'active', $26, $27,
        $28, $29, $30
      ) RETURNING id`,
      [
        piNumber, q.partyType, q.partyId, q.partyName,
        q.customerContactPerson, q.customerMobile, q.customerEmail, q.customerGstNumber,
        q.billingAddress, q.shippingAddress, q.projectId ?? null, q.projectName ?? null, q.architectId, q.architectName,
        q.salesExecutive, q.subtotalAmount, q.discountAmount, q.taxableAmount,
        q.cgstAmount, q.sgstAmount, q.igstAmount, q.gstAmount, q.totalAmount, q.totalAmount,
        q.isInterStateTax, q.id, q.invoiceNumber,
        `PROFORMA INVOICE (Advance Payment Requirement)\n${q.termsAndConditions ?? ''}`, q.notes, userId ?? null,
      ],
    );
    const piId = proformaRes.rows[0].id;

    for (const item of q.items) {
      await this.db.query(
        `INSERT INTO sale_items (
          sale_id, finished_product_id, finished_product_name, finished_product_code,
          product_description, quantity, unit, rate, discount_amount, gst_percent,
          taxable_amount, cgst_amount, sgst_amount, igst_amount, line_total
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)`,
        [
          piId, item.finishedProductId, item.finishedProductName, item.finishedProductCode,
          item.productDescription, item.quantity, item.unit, item.rate, item.discountAmount, item.gstPercent,
          item.taxableAmount, item.cgstAmount, item.sgstAmount, item.igstAmount, item.lineTotal,
        ],
      );
    }

    // Update Quotation status to converted
    await this.db.query(
      `UPDATE sales SET quotation_status = 'converted', proforma_reference_id = $1, proforma_number = $2, updated_at = now() WHERE id = $3`,
      [piId, piNumber, quotationId],
    );

    return this.findById(piId);
  }

  async recordAdvancePayment(proformaId: string, dto: RecordAdvancePaymentDto, userId?: string, correlationId?: string) {
    const pi = await this.findById(proformaId);
    if (!pi) throw new NotFoundException(`Proforma invoice ${proformaId} not found`);

    const newPaid = (pi.paidAmount ?? 0) + dto.amount;
    const newPending = Math.max(0, (pi.totalAmount ?? 0) - newPaid);
    const newStatus = newPending <= 0.01 ? 'paid' : 'partialPaid';

    await this.db.query(
      `UPDATE sales SET paid_amount = $1, pending_amount = $2, proforma_status = $3, status = $4, updated_at = now() WHERE id = $5`,
      [newPaid, newPending, newStatus, newStatus === 'paid' ? 'paid' : 'partialPaid', proformaId],
    );

    // Record in payments table
    const year = new Date().getFullYear();
    const countRes = await this.db.query<{ count: string }>(`SELECT count(*)::text as count FROM payments WHERE payment_number LIKE $1`, [`%PAY/${year}/%`]);
    const payNum = `DLZ/PAY/${year}/${(parseInt(countRes.rows[0].count, 10) + 1).toString().padStart(4, '0')}`;

    await this.db.query(
      `INSERT INTO payments (
        payment_number, payment_type, amount, payment_mode, reference_number, notes, created_at
      ) VALUES ($1, 'customerReceipt', $2, $3, $4, $5, now())`,
      [payNum, dto.amount, dto.paymentMode, pi.invoiceNumber, dto.notes ?? `Advance payment for ${pi.invoiceNumber}`],
    );

    return this.findById(proformaId);
  }

  // ==========================================================================
  // 3. SALES ORDERS & STOCK RESERVATION
  // ==========================================================================
  async createSalesOrder(dto: CreateSalesOrderDto, userId?: string, correlationId?: string) {
    const party = await this.getPartyDetails(dto.partyType, dto.partyId);
    let archName: string | null = null;
    if (dto.architectId) {
      const archRes = await this.db.query<{ name: string }>(`SELECT name FROM architects WHERE id = $1`, [dto.architectId]);
      if (archRes.rows.length > 0) archName = archRes.rows[0].name;
    }

    const soNumber = await this.getNextSequenceNumber('SO');

    let hasShortage = false;
    let subtotal = 0;
    let totalDiscount = 0;
    let totalGst = 0;

    const lineItemsComputed: any[] = [];
    const shortagesToProduce: any[] = [];

    // Process each item with FOR UPDATE stock locking
    for (const item of dto.items) {
      const fpRes = await this.db.query<{
        id: string;
        name: string;
        item_code: string;
        unit: string;
        current_stock: string;
        reserved_stock: string;
        customer_selling_price: string;
        gst_percent: string;
      }>(
        `SELECT fp.id, fp.name, fp.item_code, mu.symbol as unit, fp.current_stock, fp.reserved_stock, fp.customer_selling_price, fp.gst_percent
         FROM finished_products fp
         JOIN measurement_units mu ON mu.id = fp.unit_id
         WHERE fp.id = $1 FOR UPDATE`,
        [item.finishedProductId],
      );

      if (fpRes.rows.length === 0) {
        throw new NotFoundException(`Finished product ${item.finishedProductId} not found`);
      }

      const fp = fpRes.rows[0];
      const currentStock = parseFloat(fp.current_stock);
      const reservedStock = parseFloat(fp.reserved_stock);
      const availableStock = Math.max(0, currentStock - reservedStock);

      let reservedQty = 0;
      let shortageQty = 0;

      if (availableStock >= item.quantity) {
        reservedQty = item.quantity;
      } else {
        reservedQty = availableStock;
        shortageQty = item.quantity - availableStock;
        hasShortage = true;
        shortagesToProduce.push({
          finishedProductId: fp.id,
          finishedProductName: fp.name,
          finishedProductCode: fp.item_code,
          unit: fp.unit,
          shortageQuantity: shortageQty,
        });
      }

      // Update reserved stock in DB
      if (reservedQty > 0) {
        await this.db.query(
          `UPDATE finished_products SET reserved_stock = reserved_stock + $1, updated_at = now() WHERE id = $2`,
          [reservedQty, fp.id],
        );
      }

      const rate = item.rate ?? parseFloat(fp.customer_selling_price);
      const discount = item.discountAmount ?? 0;
      const gstPercent = item.gstPercent ?? parseFloat(fp.gst_percent);
      const taxable = Math.max(0, item.quantity * rate - discount);
      const gst = taxable * (gstPercent / 100);
      const lineTotal = taxable + gst;

      subtotal += item.quantity * rate;
      totalDiscount += discount;
      totalGst += gst;

      lineItemsComputed.push({
        finishedProductId: fp.id,
        finishedProductName: fp.name,
        finishedProductCode: fp.item_code,
        quantity: item.quantity,
        reservedQuantity: reservedQty,
        unit: fp.unit,
        rate,
        discountAmount: discount,
        gstPercent,
        taxableAmount: taxable,
        cgstAmount: dto.isInterStateTax ? 0 : gst / 2,
        sgstAmount: dto.isInterStateTax ? 0 : gst / 2,
        igstAmount: dto.isInterStateTax ? gst : 0,
        lineTotal,
      });
    }

    const finalStatus = hasShortage ? 'productionPending' : 'readyForDispatch';
    const taxableAmount = Math.max(0, subtotal - totalDiscount);
    const grandTotal = taxableAmount + totalGst;

    const soRes = await this.db.query<{ id: string }>(
      `INSERT INTO sales (
        invoice_number, document_type, party_type, party_id, party_name,
        customer_contact_person, customer_mobile, customer_email, customer_gst_number,
        billing_address, shipping_address, architect_id, architect_name,
        sales_order_number, sales_order_status, status, delivery_date,
        subtotal_amount, discount_amount, taxable_amount, cgst_amount, sgst_amount, igst_amount,
        gst_amount, total_amount, pending_amount, is_inter_state_tax, payment_mode, notes, created_by
      ) VALUES (
        $1, 'salesOrder', $2, $3, $4,
        $5, $6, $7, $8,
        $9, $10, $11, $12,
        $1, $13, 'active', $14,
        $15, $16, $17, $18, $19, $20,
        $21, $22, $23, $24, $25, $26, $27
      ) RETURNING id`,
      [
        soNumber, dto.partyType, dto.partyId, party.name,
        (party as any).contact_person ?? null, party.mobile, party.email, party.gst_number,
        party.address, party.address, dto.architectId ?? null, archName,
        finalStatus, dto.deliveryDate ? new Date(dto.deliveryDate) : null,
        subtotal, totalDiscount, taxableAmount,
        dto.isInterStateTax ? 0 : totalGst / 2, dto.isInterStateTax ? 0 : totalGst / 2, dto.isInterStateTax ? totalGst : 0,
        totalGst, grandTotal, grandTotal, dto.isInterStateTax ?? false, dto.paymentMode ?? 'bankTransfer', dto.notes ?? null, userId ?? null,
      ],
    );
    const soId = soRes.rows[0].id;

    for (const i of lineItemsComputed) {
      await this.db.query(
        `INSERT INTO sale_items (
          sale_id, finished_product_id, finished_product_name, finished_product_code,
          quantity, reserved_quantity, unit, rate, discount_amount, gst_percent,
          taxable_amount, cgst_amount, sgst_amount, igst_amount, line_total
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)`,
        [
          soId, i.finishedProductId, i.finishedProductName, i.finishedProductCode,
          i.quantity, i.reservedQuantity, i.unit, i.rate, i.discountAmount, i.gstPercent,
          i.taxableAmount, i.cgstAmount, i.sgstAmount, i.igstAmount, i.lineTotal,
        ],
      );
    }

    // Auto-create Production Orders for shortages
    for (const shortage of shortagesToProduce) {
      const year = new Date().getFullYear();
      const prdCount = await this.db.query<{ count: string }>(`SELECT count(*)::text as count FROM production_orders WHERE production_number LIKE $1`, [`%PRD-${year}-%`]);
      const prdNum = `PRD-${year}-${(parseInt(prdCount.rows[0].count, 10) + 1).toString().padStart(4, '0')}`;

      await this.db.query(
        `INSERT INTO production_orders (
          production_number, finished_product_id, finished_product_name, finished_product_code,
          unit, planned_quantity, status, sales_order_id, sales_order_number, notes, created_by
        ) VALUES ($1, $2, $3, $4, $5, $6, 'planned', $7, $8, $9, $10)`,
        [
          prdNum, shortage.finishedProductId, shortage.finishedProductName, shortage.finishedProductCode,
          shortage.unit, shortage.shortageQuantity, soId, soNumber,
          `Auto-generated for Sales Order ${soNumber} shortage (${shortage.shortageQuantity} ${shortage.unit})`, userId ?? null,
        ],
      );
    }

    return this.findById(soId);
  }

  async updateSalesOrderStatus(id: string, dto: UpdateSalesOrderStatusDto, userId?: string, correlationId?: string) {
    const so = await this.findById(id);
    if (!so) throw new NotFoundException(`Sales order ${id} not found`);

    await this.db.query(`UPDATE sales SET sales_order_status = $1, updated_at = now() WHERE id = $2`, [dto.status, id]);
    return this.findById(id);
  }

  // ==========================================================================
  // 4. DELIVERY CHALLANS (PHYSICAL STOCK OUT)
  // ==========================================================================
  async createDelivery(dto: CreateDeliveryDto, userId?: string, correlationId?: string) {
    const so = await this.findById(dto.salesOrderId);
    if (!so) throw new NotFoundException(`Sales Order ${dto.salesOrderId} not found`);

    const deliveryNumber = await this.getNextSequenceNumber('DLV');

    // Validate quantities & deduct physical + reserved stock
    const deliveryItemsComputed: any[] = [];
    let subtotal = 0;
    let totalDiscount = 0;
    let totalGst = 0;

    for (const item of dto.items) {
      const soItem = so.items.find((i: any) => i.finishedProductId === item.finishedProductId);
      if (!soItem) {
        throw new BadRequestException(`Product ${item.finishedProductId} not in Sales Order`);
      }

      const remainingOrdered = Math.max(0, (soItem.quantity ?? 0) - (soItem.deliveredQuantity ?? 0));
      if (item.quantity > remainingOrdered) {
        throw new BadRequestException(
          `Dispatch quantity (${item.quantity}) exceeds remaining order quantity (${remainingOrdered}) for ${soItem.finishedProductName}`,
        );
      }

      const fpRes = await this.db.query<{ current_stock: string; reserved_stock: string; name: string; item_code: string; unit: string }>(
        `SELECT fp.name, fp.item_code, mu.symbol as unit, fp.current_stock, fp.reserved_stock
         FROM finished_products fp
         JOIN measurement_units mu ON mu.id = fp.unit_id
         WHERE fp.id = $1 FOR UPDATE`,
        [item.finishedProductId],
      );
      const fp = fpRes.rows[0];
      const currentStock = parseFloat(fp.current_stock);
      const reservedStock = parseFloat(fp.reserved_stock);

      if (item.quantity > currentStock) {
        throw new ConflictException(
          `Cannot dispatch ${item.quantity} units. Only ${currentStock} physically available in warehouse for ${fp.name}`,
        );
      }

      // Deduct physical and reserved stock
      const updatedCurrent = currentStock - item.quantity;
      const updatedReserved = Math.max(0, reservedStock - item.quantity);

      await this.db.query(
        `UPDATE finished_products SET current_stock = $1, reserved_stock = $2, updated_at = now() WHERE id = $3`,
        [updatedCurrent, updatedReserved, item.finishedProductId],
      );

      // Post outward StockMovement
      await this.db.query(
        `INSERT INTO stock_movements (
          date, item_id, item_type, transaction_type,
          reference_number, stock_in, stock_out, current_balance, unit, notes, performed_by
        ) VALUES (now(), $1, 'finishedProduct', 'sale', $2, 0, $3, $4, $5, $6, $7)`,
        [
          item.finishedProductId, deliveryNumber,
          item.quantity, updatedCurrent, fp.unit, `Dispatched against Sales Order ${so.invoiceNumber}`,
          userId ?? null,
        ],
      );

      // Update SO line item delivered quantity
      await this.db.query(
        `UPDATE sale_items SET delivered_quantity = delivered_quantity + $1, reserved_quantity = GREATEST(0, reserved_quantity - $1)
         WHERE sale_id = $2 AND finished_product_id = $3`,
        [item.quantity, so.id, item.finishedProductId],
      );

      const rate = soItem.rate ?? 0;
      const discount = (soItem.discountAmount / (soItem.quantity > 0 ? soItem.quantity : 1)) * item.quantity;
      const gstPercent = soItem.gstPercent ?? 18;
      const taxable = Math.max(0, item.quantity * rate - discount);
      const gst = taxable * (gstPercent / 100);
      const lineTotal = taxable + gst;

      subtotal += item.quantity * rate;
      totalDiscount += discount;
      totalGst += gst;

      deliveryItemsComputed.push({
        finishedProductId: item.finishedProductId,
        finishedProductName: fp.name,
        finishedProductCode: fp.item_code,
        quantity: item.quantity,
        unit: fp.unit,
        rate,
        discountAmount: discount,
        gstPercent,
        taxableAmount: taxable,
        lineTotal,
      });
    }

    const taxableAmount = Math.max(0, subtotal - totalDiscount);
    const grandTotal = taxableAmount + totalGst;

    // Check if SO is now fully delivered
    const updatedSoItems = await this.db.query<{ quantity: string; delivered_quantity: string }>(
      `SELECT quantity, delivered_quantity FROM sale_items WHERE sale_id = $1`,
      [so.id],
    );
    const isAllDelivered = updatedSoItems.rows.every(
      (r) => parseFloat(r.delivered_quantity) >= parseFloat(r.quantity),
    );
    const newSoStatus = isAllDelivered ? 'delivered' : 'partiallyDelivered';
    await this.db.query(`UPDATE sales SET sales_order_status = $1, updated_at = now() WHERE id = $2`, [newSoStatus, so.id]);

    const dlvRes = await this.db.query<{ id: string }>(
      `INSERT INTO sales (
        invoice_number, document_type, party_type, party_id, party_name,
        customer_contact_person, customer_mobile, customer_email, customer_gst_number,
        billing_address, shipping_address, architect_id, architect_name,
        sales_order_reference_id, sales_order_number, delivery_status, delivery_number,
        vehicle_number, driver_contact, courier_name, tracking_number, expected_delivery_date,
        dispatch_notes, subtotal_amount, discount_amount, taxable_amount, cgst_amount, sgst_amount,
        igst_amount, gst_amount, total_amount, pending_amount, is_inter_state_tax, status, created_by
      ) VALUES (
        $1, 'delivery', $2, $3, $4,
        $5, $6, $7, $8,
        $9, $10, $11, $12,
        $13, $14, 'dispatched', $1,
        $15, $16, $17, $18, $19,
        $20, $21, $22, $23, $24, $25,
        $26, $27, $28, $29, $30, 'completed', $31
      ) RETURNING id`,
      [
        deliveryNumber, so.partyType, so.partyId, so.partyName,
        so.customerContactPerson, so.customerMobile, so.customerEmail, so.customerGstNumber,
        so.billingAddress, so.shippingAddress, so.architectId, so.architectName,
        so.id, so.invoiceNumber,
        dto.vehicleNumber ?? null, dto.driverContact ?? null, dto.courierName ?? null, dto.trackingNumber ?? null,
        dto.expectedDeliveryDate ? new Date(dto.expectedDeliveryDate) : null, dto.dispatchNotes ?? null,
        subtotal, totalDiscount, taxableAmount, so.isInterStateTax ? 0 : totalGst / 2, so.isInterStateTax ? 0 : totalGst / 2,
        so.isInterStateTax ? totalGst : 0, totalGst, grandTotal, grandTotal, so.isInterStateTax, userId ?? null,
      ],
    );
    const dlvId = dlvRes.rows[0].id;

    for (const i of deliveryItemsComputed) {
      await this.db.query(
        `INSERT INTO sale_items (
          sale_id, finished_product_id, finished_product_name, finished_product_code,
          quantity, delivered_quantity, unit, rate, discount_amount, gst_percent,
          taxable_amount, cgst_amount, sgst_amount, igst_amount, line_total
        ) VALUES ($1, $2, $3, $4, $5, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)`,
        [
          dlvId, i.finishedProductId, i.finishedProductName, i.finishedProductCode,
          i.quantity, i.unit, i.rate, i.discountAmount, i.gstPercent,
          i.taxableAmount, so.isInterStateTax ? 0 : (i.lineTotal - i.taxableAmount) / 2,
          so.isInterStateTax ? 0 : (i.lineTotal - i.taxableAmount) / 2,
          so.isInterStateTax ? (i.lineTotal - i.taxableAmount) : 0, i.lineTotal,
        ],
      );
    }

    return this.findById(dlvId);
  }

  async updateDeliveryTracking(deliveryId: string, dto: UpdateDeliveryTrackingDto, userId?: string, correlationId?: string) {
    const dlv = await this.findById(deliveryId);
    if (!dlv) throw new NotFoundException(`Delivery ${deliveryId} not found`);

    await this.db.query(
      `UPDATE sales SET
        courier_name = COALESCE($1, courier_name),
        tracking_number = COALESCE($2, tracking_number),
        vehicle_number = COALESCE($3, vehicle_number),
        driver_contact = COALESCE($4, driver_contact),
        dispatch_notes = COALESCE($5, dispatch_notes),
        updated_at = now()
       WHERE id = $6`,
      [dto.courierName, dto.trackingNumber, dto.vehicleNumber, dto.driverContact, dto.dispatchNotes, deliveryId],
    );
    return this.findById(deliveryId);
  }

  // ==========================================================================
  // 5. TAX INVOICES & DIRECT POS COUNTER SALES
  // ==========================================================================
  async createInvoiceFromDelivery(dto: CreateInvoiceFromDeliveryDto, userId?: string, correlationId?: string) {
    const dlv = await this.findById(dto.deliveryId);
    if (!dlv) throw new NotFoundException(`Delivery ${dto.deliveryId} not found`);

    const invNumber = await this.getNextSequenceNumber('INV');
    const discount = dto.discountAmount ?? 0;
    const initialPaid = dto.initialPaidAmount ?? 0;

    const subtotal = dlv.subtotalAmount;
    const taxable = Math.max(0, subtotal - discount);
    const gst = dlv.gstAmount;
    const total = taxable + gst;
    const pending = Math.max(0, total - initialPaid);
    const status = pending <= 0.01 ? 'paid' : initialPaid > 0 ? 'partialPaid' : 'active';

    // Auto-calculate Architect Commission if linked
    let commissionAmount = 0;
    if (dlv.architectId) {
      const archRes = await this.db.query<{ default_commission_rate: string; name: string }>(
        `SELECT default_commission_rate, name FROM architects WHERE id = $1`,
        [dlv.architectId],
      );
      if (archRes.rows.length > 0) {
        const rate = parseFloat(archRes.rows[0].default_commission_rate);
        commissionAmount = (taxable * rate) / 100;
      }
    }

    const invRes = await this.db.query<{ id: string }>(
      `INSERT INTO sales (
        invoice_number, document_type, party_type, party_id, party_name,
        customer_contact_person, customer_mobile, customer_email, customer_gst_number,
        billing_address, shipping_address, architect_id, architect_name,
        sales_order_reference_id, sales_order_number, subtotal_amount, discount_amount,
        taxable_amount, cgst_amount, sgst_amount, igst_amount, gst_amount, total_amount,
        paid_amount, pending_amount, is_inter_state_tax, payment_mode, status,
        architect_commission_amount, notes, created_by
      ) VALUES (
        $1, 'invoice', $2, $3, $4,
        $5, $6, $7, $8,
        $9, $10, $11, $12,
        $13, $14, $15, $16,
        $17, $18, $19, $20, $21, $22,
        $23, $24, $25, $26, $27,
        $28, $29, $30
      ) RETURNING id`,
      [
        invNumber, dlv.partyType, dlv.partyId, dlv.partyName,
        dlv.customerContactPerson, dlv.customerMobile, dlv.customerEmail, dlv.customerGstNumber,
        dlv.billingAddress, dlv.shippingAddress, dlv.architectId, dlv.architectName,
        dlv.salesOrderReferenceId, dlv.salesOrderNumber, subtotal, discount,
        taxable, dlv.isInterStateTax ? 0 : gst / 2, dlv.isInterStateTax ? 0 : gst / 2, dlv.isInterStateTax ? gst : 0,
        gst, total, initialPaid, pending, dlv.isInterStateTax, dto.paymentMode ?? 'bankTransfer', status,
        commissionAmount, dto.notes ?? null, userId ?? null,
      ],
    );
    const invId = invRes.rows[0].id;

    for (const item of dlv.items) {
      await this.db.query(
        `INSERT INTO sale_items (
          sale_id, finished_product_id, finished_product_name, finished_product_code,
          quantity, invoiced_quantity, unit, rate, discount_amount, gst_percent,
          taxable_amount, cgst_amount, sgst_amount, igst_amount, line_total
        ) VALUES ($1, $2, $3, $4, $5, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)`,
        [
          invId, item.finishedProductId, item.finishedProductName, item.finishedProductCode,
          item.quantity, item.unit, item.rate, item.discountAmount, item.gstPercent,
          item.taxableAmount, item.cgstAmount, item.sgstAmount, item.igstAmount, item.lineTotal,
        ],
      );
    }

    // 1. Update Customer or Dealer balance
    if (dlv.partyType === 'customer') {
      await this.db.query(
        `UPDATE customers SET outstanding_amount = outstanding_amount + $1, updated_at = now() WHERE id = $2`,
        [pending, dlv.partyId],
      );
    } else if (dlv.partyType === 'dealer') {
      await this.db.query(
        `UPDATE dealers SET outstanding_amount = outstanding_amount + $1, updated_at = now() WHERE id = $2`,
        [pending, dlv.partyId],
      );
    }

    // 2. Register Architect Commission if applicable
    if (dlv.architectId && commissionAmount > 0) {
      const year = new Date().getFullYear();
      const countRes = await this.db.query<{ count: string }>(`SELECT count(*)::text as count FROM architect_commissions WHERE commission_number LIKE $1`, [`%COM/${year}/%`]);
      const comNum = `DLZ/COM/${year}/${(parseInt(countRes.rows[0].count, 10) + 1).toString().padStart(4, '0')}`;
      const archRes = await this.db.query<{ default_commission_rate: string; name: string }>(`SELECT default_commission_rate, name FROM architects WHERE id = $1`, [dlv.architectId]);

      await this.db.query(
        `INSERT INTO architect_commissions (
          commission_number, architect_id, architect_name, sale_invoice_id, sale_invoice_number,
          sale_amount, commission_rate, commission_amount, status, generated_date
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'generated', now())`,
        [
          comNum, dlv.architectId, archRes.rows[0].name, invId, invNumber,
          taxable, parseFloat(archRes.rows[0].default_commission_rate), commissionAmount,
        ],
      );
    }

    // 3. Record initial payment receipt if provided
    if (initialPaid > 0) {
      const year = new Date().getFullYear();
      const countRes = await this.db.query<{ count: string }>(`SELECT count(*)::text as count FROM payments WHERE payment_number LIKE $1`, [`%PAY/${year}/%`]);
      const payNum = `DLZ/PAY/${year}/${(parseInt(countRes.rows[0].count, 10) + 1).toString().padStart(4, '0')}`;

      await this.db.query(
        `INSERT INTO payments (
          payment_number, payment_type, amount, payment_mode, reference_number, notes, created_at
        ) VALUES ($1, 'customerReceipt', $2, $3, $4, $5, now())`,
        [payNum, initialPaid, dto.paymentMode ?? 'bankTransfer', invNumber, `Initial receipt for invoice ${invNumber}`],
      );
    }

    return this.findById(invId);
  }

  async createDirectSale(dto: CreateDirectSaleDto, userId?: string, correlationId?: string) {
    const party = await this.getPartyDetails(dto.partyType, dto.partyId);
    let archName: string | null = null;
    let commissionRate = 0;
    if (dto.architectId) {
      const archRes = await this.db.query<{ name: string; default_commission_rate: string }>(
        `SELECT name, default_commission_rate FROM architects WHERE id = $1`,
        [dto.architectId],
      );
      if (archRes.rows.length > 0) {
        archName = archRes.rows[0].name;
        commissionRate = parseFloat(archRes.rows[0].default_commission_rate);
      }
    }

    const invNumber = await this.getNextSequenceNumber('INV');

    // Deduct stock immediately
    let subtotal = 0;
    let totalDiscount = 0;
    let totalGst = 0;

    const computedItems: any[] = [];
    for (const item of dto.items) {
      const fpRes = await this.db.query<{ current_stock: string; name: string; item_code: string; unit: string; customer_selling_price: string; gst_percent: string }>(
        `SELECT fp.name, fp.item_code, mu.symbol as unit, fp.current_stock, fp.customer_selling_price, fp.gst_percent
         FROM finished_products fp
         JOIN measurement_units mu ON mu.id = fp.unit_id
         WHERE fp.id = $1 FOR UPDATE`,
        [item.finishedProductId],
      );
      if (fpRes.rows.length === 0) throw new NotFoundException(`Product ${item.finishedProductId} not found`);
      const fp = fpRes.rows[0];
      const currentStock = parseFloat(fp.current_stock);
      if (item.quantity > currentStock) {
        throw new ConflictException(`Insufficient stock for ${fp.name}. Available: ${currentStock}, Invoiced: ${item.quantity}`);
      }

      // Deduct stock
      const updatedStock = currentStock - item.quantity;
      await this.db.query(`UPDATE finished_products SET current_stock = $1, updated_at = now() WHERE id = $2`, [updatedStock, item.finishedProductId]);

      // Record StockMovement
      await this.db.query(
        `INSERT INTO stock_movements (
          date, item_id, item_type, transaction_type,
          reference_number, stock_in, stock_out, current_balance, unit, notes, performed_by
        ) VALUES (now(), $1, 'finishedProduct', 'sale', $2, 0, $3, $4, $5, 'Direct Counter Sale', $6)`,
        [item.finishedProductId, invNumber, item.quantity, updatedStock, fp.unit, userId ?? null],
      );

      const rate = item.rate ?? parseFloat(fp.customer_selling_price);
      const discount = item.discountAmount ?? 0;
      const gstPercent = item.gstPercent ?? parseFloat(fp.gst_percent);
      const taxable = Math.max(0, item.quantity * rate - discount);
      const gst = taxable * (gstPercent / 100);
      const lineTotal = taxable + gst;

      subtotal += item.quantity * rate;
      totalDiscount += discount;
      totalGst += gst;

      computedItems.push({
        finishedProductId: item.finishedProductId,
        finishedProductName: fp.name,
        finishedProductCode: fp.item_code,
        quantity: item.quantity,
        unit: fp.unit,
        rate,
        discountAmount: discount,
        gstPercent,
        taxableAmount: taxable,
        cgstAmount: dto.isInterStateTax ? 0 : gst / 2,
        sgstAmount: dto.isInterStateTax ? 0 : gst / 2,
        igstAmount: dto.isInterStateTax ? gst : 0,
        lineTotal,
      });
    }

    const taxableAmount = Math.max(0, subtotal - totalDiscount);
    const grandTotal = taxableAmount + totalGst;
    const paidAmount = dto.paidAmount ?? grandTotal;
    const pendingAmount = Math.max(0, grandTotal - paidAmount);
    const status = pendingAmount <= 0.01 ? 'paid' : paidAmount > 0 ? 'partialPaid' : 'active';
    const commissionAmount = (taxableAmount * commissionRate) / 100;

    const invRes = await this.db.query<{ id: string }>(
      `INSERT INTO sales (
        invoice_number, document_type, party_type, party_id, party_name,
        customer_contact_person, customer_mobile, customer_email, customer_gst_number,
        billing_address, shipping_address, architect_id, architect_name,
        subtotal_amount, discount_amount, taxable_amount, cgst_amount, sgst_amount, igst_amount,
        gst_amount, total_amount, paid_amount, pending_amount, is_inter_state_tax, payment_mode, status,
        architect_commission_amount, notes, created_by
      ) VALUES (
        $1, 'invoice', $2, $3, $4,
        $5, $6, $7, $8,
        $9, $10, $11, $12,
        $13, $14, $15, $16, $17, $18,
        $19, $20, $21, $22, $23, $24, $25,
        $26, $27, $28
      ) RETURNING id`,
      [
        invNumber, dto.partyType, dto.partyId, party.name,
        (party as any).contact_person ?? null, party.mobile, party.email, party.gst_number,
        party.address, party.address, dto.architectId ?? null, archName,
        subtotal, totalDiscount, taxableAmount,
        dto.isInterStateTax ? 0 : totalGst / 2, dto.isInterStateTax ? 0 : totalGst / 2, dto.isInterStateTax ? totalGst : 0,
        totalGst, grandTotal, paidAmount, pendingAmount, dto.isInterStateTax ?? false, dto.paymentMode ?? 'upi', status,
        commissionAmount, dto.notes ?? 'Direct Counter POS Sale', userId ?? null,
      ],
    );
    const invId = invRes.rows[0].id;

    for (const i of computedItems) {
      await this.db.query(
        `INSERT INTO sale_items (
          sale_id, finished_product_id, finished_product_name, finished_product_code,
          quantity, delivered_quantity, invoiced_quantity, unit, rate, discount_amount, gst_percent,
          taxable_amount, cgst_amount, sgst_amount, igst_amount, line_total
        ) VALUES ($1, $2, $3, $4, $5, $5, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)`,
        [
          invId, i.finishedProductId, i.finishedProductName, i.finishedProductCode,
          i.quantity, i.unit, i.rate, i.discountAmount, i.gstPercent,
          i.taxableAmount, i.cgstAmount, i.sgstAmount, i.igstAmount, i.lineTotal,
        ],
      );
    }

    if (pendingAmount > 0) {
      if (dto.partyType === 'customer') {
        await this.db.query(`UPDATE customers SET outstanding_amount = outstanding_amount + $1 WHERE id = $2`, [pendingAmount, dto.partyId]);
      } else if (dto.partyType === 'dealer') {
        await this.db.query(`UPDATE dealers SET outstanding_amount = outstanding_amount + $1 WHERE id = $2`, [pendingAmount, dto.partyId]);
      }
    }

    if (paidAmount > 0) {
      const year = new Date().getFullYear();
      const countRes = await this.db.query<{ count: string }>(`SELECT count(*)::text as count FROM payments WHERE payment_number LIKE $1`, [`%PAY/${year}/%`]);
      const payNum = `DLZ/PAY/${year}/${(parseInt(countRes.rows[0].count, 10) + 1).toString().padStart(4, '0')}`;
      await this.db.query(
        `INSERT INTO payments (payment_number, payment_type, amount, payment_mode, reference_number, notes, created_at)
         VALUES ($1, 'customerReceipt', $2, $3, $4, 'Direct Counter Sale Receipt', now())`,
        [payNum, paidAmount, dto.paymentMode ?? 'upi', invNumber],
      );
    }

    if (dto.architectId && commissionAmount > 0) {
      const year = new Date().getFullYear();
      const countRes = await this.db.query<{ count: string }>(`SELECT count(*)::text as count FROM architect_commissions WHERE commission_number LIKE $1`, [`%COM/${year}/%`]);
      const comNum = `DLZ/COM/${year}/${(parseInt(countRes.rows[0].count, 10) + 1).toString().padStart(4, '0')}`;
      await this.db.query(
        `INSERT INTO architect_commissions (
          commission_number, architect_id, architect_name, sale_invoice_id, sale_invoice_number,
          sale_amount, commission_rate, commission_amount, status, generated_date
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'generated', now())`,
        [comNum, dto.architectId, archName, invId, invNumber, taxableAmount, commissionRate, commissionAmount],
      );
    }

    return this.findById(invId);
  }

  async recordInvoicePayment(invoiceId: string, dto: RecordInvoicePaymentDto, userId?: string, correlationId?: string) {
    const inv = await this.findById(invoiceId);
    if (!inv) throw new NotFoundException(`Invoice ${invoiceId} not found`);

    const newPaid = (inv.paidAmount ?? 0) + dto.amount;
    const newPending = Math.max(0, (inv.totalAmount ?? 0) - newPaid);
    const newStatus = newPending <= 0.01 ? 'paid' : 'partialPaid';

    await this.db.query(
      `UPDATE sales SET paid_amount = $1, pending_amount = $2, status = $3, updated_at = now() WHERE id = $4`,
      [newPaid, newPending, newStatus, invoiceId],
    );

    // Reduce Customer / Dealer Outstanding
    if (inv.partyType === 'customer') {
      await this.db.query(
        `UPDATE customers SET outstanding_amount = GREATEST(0, outstanding_amount - $1), updated_at = now() WHERE id = $2`,
        [dto.amount, inv.partyId],
      );
    } else if (inv.partyType === 'dealer') {
      await this.db.query(
        `UPDATE dealers SET outstanding_amount = GREATEST(0, outstanding_amount - $1), updated_at = now() WHERE id = $2`,
        [dto.amount, inv.partyId],
      );
    }

    // Record in payments table
    const year = new Date().getFullYear();
    const countRes = await this.db.query<{ count: string }>(`SELECT count(*)::text as count FROM payments WHERE payment_number LIKE $1`, [`%PAY/${year}/%`]);
    const payNum = `DLZ/PAY/${year}/${(parseInt(countRes.rows[0].count, 10) + 1).toString().padStart(4, '0')}`;

    await this.db.query(
      `INSERT INTO payments (
        payment_number, payment_type, amount, payment_mode, reference_number, notes, created_at
      ) VALUES ($1, 'customerReceipt', $2, $3, $4, $5, now())`,
      [payNum, dto.amount, dto.paymentMode, inv.invoiceNumber, dto.notes ?? `Payment for invoice ${inv.invoiceNumber}`],
    );

    return this.findById(invoiceId);
  }

  // ==========================================================================
  // 6. SALES RETURNS (RMA) & REFUNDS
  // ==========================================================================
  async createSalesReturn(dto: CreateSalesReturnDto, userId?: string, correlationId?: string) {
    const origInv = await this.findById(dto.originalInvoiceId);
    if (!origInv) throw new NotFoundException(`Original invoice ${dto.originalInvoiceId} not found`);

    const returnNumber = await this.getNextSequenceNumber('RET');

    // Validate return quantities
    let subtotal = 0;
    let totalDiscount = 0;
    let totalGst = 0;

    const returnItemsComputed: any[] = [];
    for (const item of dto.items) {
      const origItem = origInv.items.find((i: any) => i.finishedProductId === item.finishedProductId);
      if (!origItem) {
        throw new BadRequestException(`Product ${item.finishedProductId} not found on original invoice`);
      }

      const availableToReturn = Math.max(0, origItem.quantity - (origItem.returnedQuantity ?? 0));
      if (item.quantity > availableToReturn) {
        throw new BadRequestException(
          `Return quantity (${item.quantity}) exceeds available return quantity (${availableToReturn}) for ${origItem.finishedProductName}`,
        );
      }

      const rate = origItem.rate;
      const discount = (origItem.discountAmount / (origItem.quantity > 0 ? origItem.quantity : 1)) * item.quantity;
      const gstPercent = origItem.gstPercent;
      const taxable = Math.max(0, item.quantity * rate - discount);
      const gst = taxable * (gstPercent / 100);
      const lineTotal = taxable + gst;

      subtotal += item.quantity * rate;
      totalDiscount += discount;
      totalGst += gst;

      returnItemsComputed.push({
        finishedProductId: item.finishedProductId,
        finishedProductName: origItem.finishedProductName,
        finishedProductCode: origItem.finishedProductCode,
        quantity: item.quantity,
        unit: origItem.unit,
        rate,
        discountAmount: discount,
        gstPercent,
        taxableAmount: taxable,
        lineTotal,
        returnCondition: item.returnCondition ?? dto.condition ?? 'resalable',
      });
    }

    const taxableAmount = Math.max(0, subtotal - totalDiscount);
    const grandTotal = taxableAmount + totalGst;

    const retRes = await this.db.query<{ id: string }>(
      `INSERT INTO sales (
        invoice_number, document_type, party_type, party_id, party_name,
        customer_contact_person, customer_mobile, customer_email, customer_gst_number,
        billing_address, shipping_address, architect_id, architect_name,
        original_invoice_id, original_invoice_number, sales_return_status,
        return_condition, return_financial_action, return_reason,
        subtotal_amount, discount_amount, taxable_amount, cgst_amount, sgst_amount, igst_amount,
        gst_amount, total_amount, pending_amount, is_inter_state_tax, status, notes, created_by
      ) VALUES (
        $1, 'salesReturn', $2, $3, $4,
        $5, $6, $7, $8,
        $9, $10, $11, $12,
        $13, $14, 'submitted',
        $15, $16, $17,
        $18, $19, $20, $21, $22, $23,
        $24, $25, 0, $26, 'draft', $27, $28
      ) RETURNING id`,
      [
        returnNumber, origInv.partyType, origInv.partyId, origInv.partyName,
        origInv.customerContactPerson, origInv.customerMobile, origInv.customerEmail, origInv.customerGstNumber,
        origInv.billingAddress, origInv.shippingAddress, origInv.architectId, origInv.architectName,
        origInv.id, origInv.invoiceNumber,
        dto.condition ?? 'resalable', dto.financialAction ?? 'adjustOutstanding', dto.returnReason,
        subtotal, totalDiscount, taxableAmount, origInv.isInterStateTax ? 0 : totalGst / 2, origInv.isInterStateTax ? 0 : totalGst / 2,
        origInv.isInterStateTax ? totalGst : 0, totalGst, grandTotal, origInv.isInterStateTax, dto.notes ?? null, userId ?? null,
      ],
    );
    const retId = retRes.rows[0].id;

    for (const i of returnItemsComputed) {
      await this.db.query(
        `INSERT INTO sale_items (
          sale_id, finished_product_id, finished_product_name, finished_product_code,
          quantity, returned_quantity, unit, rate, discount_amount, gst_percent,
          taxable_amount, cgst_amount, sgst_amount, igst_amount, line_total, return_condition
        ) VALUES ($1, $2, $3, $4, $5, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)`,
        [
          retId, i.finishedProductId, i.finishedProductName, i.finishedProductCode,
          i.quantity, i.unit, i.rate, i.discountAmount, i.gstPercent,
          i.taxableAmount, origInv.isInterStateTax ? 0 : (i.lineTotal - i.taxableAmount) / 2,
          origInv.isInterStateTax ? 0 : (i.lineTotal - i.taxableAmount) / 2,
          origInv.isInterStateTax ? (i.lineTotal - i.taxableAmount) : 0, i.lineTotal, i.returnCondition,
        ],
      );
    }

    return this.findById(retId);
  }

  async approveSalesReturn(returnId: string, userId?: string, correlationId?: string) {
    const ret = await this.findById(returnId);
    if (!ret) throw new NotFoundException(`Sales return ${returnId} not found`);
    if (ret.isProcessed) {
      throw new BadRequestException('Sales return has already been processed');
    }

    for (const item of ret.items) {
      const condition = item.returnCondition ?? ret.returnCondition ?? 'resalable';
      if (condition === 'resalable' || condition === 'goodCondition') {
        // Restock finished product
        await this.db.query(
          `UPDATE finished_products SET current_stock = current_stock + $1, updated_at = now() WHERE id = $2`,
          [item.quantity, item.finishedProductId],
        );

        const fpRes = await this.db.query<{ current_stock: string }>(`SELECT current_stock FROM finished_products WHERE id = $1`, [item.finishedProductId]);

        // Log StockMovement
        await this.db.query(
          `INSERT INTO stock_movements (
            date, item_id, item_type, transaction_type,
            reference_number, stock_in, stock_out, current_balance, unit, notes, performed_by
          ) VALUES (now(), $1, 'finishedProduct', 'saleReturn', $2, $3, 0, $4, $5, 'Sales Return Restock', $6)`,
          [
            item.finishedProductId, ret.invoiceNumber, item.quantity,
            parseFloat(fpRes.rows[0].current_stock), item.unit, userId ?? null,
          ],
        );
      } else {
        // Damaged / Scrap: log StockAdjustment without incrementing salable stock
        const fpRes = await this.db.query<{ current_stock: string }>(`SELECT current_stock FROM finished_products WHERE id = $1`, [item.finishedProductId]);
        const currStock = parseFloat(fpRes.rows[0]?.current_stock ?? '0');
        const year = new Date().getFullYear();
        const adjCount = await this.db.query<{ count: string }>(`SELECT count(*)::text as count FROM stock_adjustments WHERE adjustment_number LIKE $1`, [`%ADJ/${year}/%`]);
        const adjNum = `DLZ/ADJ/${year}/${(parseInt(adjCount.rows[0].count, 10) + 1).toString().padStart(4, '0')}`;

        await this.db.query(
          `INSERT INTO stock_adjustments (
            adjustment_number, adjustment_date, item_id, item_type,
            item_name, item_code, current_stock_before, adjusted_stock_after,
            adjustment_quantity, unit, reason, remarks, performed_by
          ) VALUES ($1, now(), $2, 'finishedProduct', $3, $4, $5, $5, $6, $7, 'damagedGoods', $8, $9)`,
          [
            adjNum, item.finishedProductId, item.finishedProductName, item.finishedProductCode,
            currStock, item.quantity, item.unit, `Damaged goods return against ${ret.invoiceNumber}`, userId ?? null,
          ],
        );
      }

      // Update original invoice item returned quantity
      if (ret.originalInvoiceId) {
        await this.db.query(
          `UPDATE sale_items SET returned_quantity = returned_quantity + $1 WHERE sale_id = $2 AND finished_product_id = $3`,
          [item.quantity, ret.originalInvoiceId, item.finishedProductId],
        );
      }
    }

    // Adjust Customer Ledger
    if (ret.partyType === 'customer') {
      await this.db.query(
        `UPDATE customers SET outstanding_amount = GREATEST(0, outstanding_amount - $1), updated_at = now() WHERE id = $2`,
        [ret.totalAmount, ret.partyId],
      );
    } else if (ret.partyType === 'dealer') {
      await this.db.query(
        `UPDATE dealers SET outstanding_amount = GREATEST(0, outstanding_amount - $1), updated_at = now() WHERE id = $2`,
        [ret.totalAmount, ret.partyId],
      );
    }

    // Reverse Architect Commission
    if (ret.originalInvoiceId) {
      await this.db.query(
        `UPDATE architect_commissions SET status = 'reversed', updated_at = now() WHERE sale_invoice_id = $1`,
        [ret.originalInvoiceId],
      );
    }

    // Determine whether a cash refund is owed: only when the customer explicitly asked for a
    // refund (not a credit note or ledger adjustment) and had paid more than what they now owe
    // on the original invoice after this return is netted off.
    let refundStatus: string | null = null;
    let refundAmount = 0;
    if (ret.returnFinancialAction === 'refund' && ret.originalInvoiceId) {
      const origInv = await this.findById(ret.originalInvoiceId);
      if (origInv && origInv.paidAmount > 0) {
        const netInvoiceAfterReturn = Math.max(0, origInv.totalAmount - ret.totalAmount);
        if (origInv.paidAmount > netInvoiceAfterReturn) {
          refundStatus = 'pending';
          refundAmount = Math.min(origInv.paidAmount - netInvoiceAfterReturn, ret.totalAmount);
        }
      }
    }

    // Mark return as approved and processed
    await this.db.query(
      `UPDATE sales SET sales_return_status = 'approved', is_processed = true, status = 'completed',
       refund_status = COALESCE($2, refund_status), refund_amount = CASE WHEN $2 IS NOT NULL THEN $3 ELSE refund_amount END,
       updated_at = now() WHERE id = $1`,
      [returnId, refundStatus, refundAmount],
    );

    return this.findById(returnId);
  }

  async disburseRefund(returnId: string, dto: DisburseRefundDto, userId?: string, correlationId?: string) {
    const ret = await this.findById(returnId);
    if (!ret) throw new NotFoundException(`Sales return ${returnId} not found`);

    await this.db.query(
      `UPDATE sales SET refund_status = 'processed', refund_amount = $1, refund_payment_mode = $2, refund_transaction_ref = $3, refund_date = now(), updated_at = now() WHERE id = $4`,
      [dto.amount, dto.paymentMode, dto.transactionReference ?? null, returnId],
    );

    // Record disbursement in payments
    const year = new Date().getFullYear();
    const countRes = await this.db.query<{ count: string }>(`SELECT count(*)::text as count FROM payments WHERE payment_number LIKE $1`, [`%PAY/${year}/%`]);
    const payNum = `DLZ/PAY/${year}/${(parseInt(countRes.rows[0].count, 10) + 1).toString().padStart(4, '0')}`;

    await this.db.query(
      `INSERT INTO payments (payment_number, payment_type, amount, payment_mode, reference_number, notes, created_at)
       VALUES ($1, 'customerReceipt', $2, $3, $4, $5, now())`,
      [payNum, -dto.amount, dto.paymentMode, ret.invoiceNumber, dto.notes ?? `Refund for return ${ret.invoiceNumber}`],
    );

    return this.findById(returnId);
  }

  // ==========================================================================
  // 7. QUERIES & DASHBOARD METRICS
  // ==========================================================================
  async findAll(query: SalesQueryDto) {
    const conditions: string[] = [];
    const params: any[] = [];
    let idx = 1;

    if (query.documentType) {
      conditions.push(`s.document_type = $${idx++}`);
      params.push(query.documentType);
    }

    if (query.status) {
      conditions.push(`s.status = $${idx++}`);
      params.push(query.status);
    }

    if (query.partyId) {
      conditions.push(`s.party_id = $${idx++}`);
      params.push(query.partyId);
    }

    if (query.search) {
      conditions.push(`(s.invoice_number ILIKE $${idx} OR s.party_name ILIKE $${idx})`);
      params.push(`%${query.search}%`);
      idx++;
    }

    const whereClause = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';
    const page = query.page ?? 1;
    const limit = query.limit ?? 50;
    const offset = (page - 1) * limit;

    const countRes = await this.db.query<{ count: string }>(
      `SELECT count(*)::text as count FROM sales s ${whereClause}`,
      params,
    );
    const total = parseInt(countRes.rows[0].count, 10);

    const listRes = await this.db.query(
      `SELECT s.* FROM sales s ${whereClause} ORDER BY s.sale_date DESC, s.created_at DESC LIMIT $${idx++} OFFSET $${idx++}`,
      [...params, limit, offset],
    );

    return {
      items: listRes.rows.map(this.mapSaleRow),
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
    };
  }

  async findById(id: string) {
    const saleRes = await this.db.query(`SELECT * FROM sales WHERE id = $1`, [id]);
    if (saleRes.rows.length === 0) throw new NotFoundException(`Sales document ${id} not found`);

    const itemsRes = await this.db.query(
      `SELECT * FROM sale_items WHERE sale_id = $1 ORDER BY created_at ASC`,
      [id],
    );

    return {
      ...this.mapSaleRow(saleRes.rows[0]),
      items: itemsRes.rows.map(this.mapItemRow),
    };
  }

  async getDashboardMetrics() {
    const quotes = await this.db.query<{ count: string; pending: string }>(
      `SELECT
         count(*)::text as count,
         count(*) FILTER (WHERE quotation_status IN ('draft', 'sent'))::text as pending
       FROM sales WHERE document_type = 'quotation'`,
    );

    const orders = await this.db.query<{ count: string; production_pending: string; ready: string; partially_delivered: string }>(
      `SELECT
         count(*)::text as count,
         count(*) FILTER (WHERE sales_order_status IN ('productionPending', 'inProduction'))::text as production_pending,
         count(*) FILTER (WHERE sales_order_status = 'readyForDispatch')::text as ready,
         count(*) FILTER (WHERE sales_order_status = 'partiallyDelivered')::text as partially_delivered
       FROM sales WHERE document_type = 'salesOrder'`,
    );

    const invoices = await this.db.query<{ total: string; pending: string }>(
      `SELECT
         COALESCE(sum(total_amount), 0)::text as total,
         COALESCE(sum(pending_amount), 0)::text as pending
       FROM sales WHERE document_type = 'invoice'`,
    );

    const returns = await this.db.query<{ total: string; pending_refunds: string }>(
      `SELECT
         COALESCE(sum(total_amount), 0)::text as total,
         count(*) FILTER (WHERE refund_status = 'pending')::text as pending_refunds
       FROM sales WHERE document_type = 'salesReturn' AND sales_return_status IN ('approved', 'completed')`,
    );

    const invoicedRevenue = parseFloat(invoices.rows[0].total);
    const returnAmount = parseFloat(returns.rows[0].total);
    const netRevenue = Math.max(0, invoicedRevenue - returnAmount);

    return {
      totalQuotationsCount: parseInt(quotes.rows[0].count, 10),
      pendingQuotationsCount: parseInt(quotes.rows[0].pending, 10),
      totalSalesOrdersCount: parseInt(orders.rows[0].count, 10),
      ordersPendingProductionCount: parseInt(orders.rows[0].production_pending, 10),
      ordersReadyForDispatchCount: parseInt(orders.rows[0].ready, 10),
      ordersPartiallyDeliveredCount: parseInt(orders.rows[0].partially_delivered, 10),
      totalInvoicedRevenue: invoicedRevenue,
      totalSalesReturnsAmount: returnAmount,
      netSalesRevenue: netRevenue,
      salesReturnRatePercentage: invoicedRevenue > 0 ? (returnAmount / invoicedRevenue) * 100 : 0,
      pendingRefundsCount: parseInt(returns.rows[0].pending_refunds, 10),
      pendingInvoiceAmount: parseFloat(invoices.rows[0].pending),
    };
  }

  private mapSaleRow(row: any) {
    return {
      id: row.id,
      invoiceNumber: row.invoice_number,
      documentType: row.document_type,
      partyType: row.party_type,
      partyId: row.party_id,
      partyName: row.party_name,
      customerContactPerson: row.customer_contact_person,
      customerMobile: row.customer_mobile,
      customerEmail: row.customer_email,
      customerGstNumber: row.customer_gst_number,
      billingAddress: row.billing_address,
      shippingAddress: row.shipping_address,
      projectId: row.project_id,
      projectName: row.project_name,
      architectId: row.architect_id,
      architectName: row.architect_name,
      salesExecutive: row.sales_executive,
      saleDate: row.sale_date,
      deliveryDate: row.delivery_date,
      validUntil: row.valid_until,
      subtotalAmount: parseFloat(row.subtotal_amount ?? 0),
      discountAmount: parseFloat(row.discount_amount ?? 0),
      taxableAmount: parseFloat(row.taxable_amount ?? 0),
      cgstAmount: parseFloat(row.cgst_amount ?? 0),
      sgstAmount: parseFloat(row.sgst_amount ?? 0),
      igstAmount: parseFloat(row.igst_amount ?? 0),
      gstAmount: parseFloat(row.gst_amount ?? 0),
      totalAmount: parseFloat(row.total_amount ?? 0),
      paidAmount: parseFloat(row.paid_amount ?? 0),
      pendingAmount: parseFloat(row.pending_amount ?? 0),
      paymentMode: row.payment_mode,
      status: row.status,
      architectCommissionAmount: parseFloat(row.architect_commission_amount ?? 0),
      isInterStateTax: row.is_inter_state_tax,
      notes: row.notes,
      termsAndConditions: row.terms_and_conditions,
      bankDetails: row.bank_details,
      revisionNumber: row.revision_number,
      originalQuotationId: row.original_quotation_id,
      parentQuotationId: row.parent_quotation_id,
      parentQuotationNumber: row.parent_quotation_number,
      quotationStatus: row.quotation_status,
      proformaStatus: row.proforma_status,
      proformaReferenceId: row.proforma_reference_id,
      proformaNumber: row.proforma_number,
      salesOrderNumber: row.sales_order_number,
      salesOrderReferenceId: row.sales_order_reference_id,
      salesOrderStatus: row.sales_order_status,
      deliveryStatus: row.delivery_status,
      deliveryNumber: row.delivery_number,
      vehicleNumber: row.vehicle_number,
      driverContact: row.driver_contact,
      courierName: row.courier_name,
      trackingNumber: row.tracking_number,
      expectedDeliveryDate: row.expected_delivery_date,
      courierContact: row.courier_contact,
      dispatchNotes: row.dispatch_notes,
      salesReturnStatus: row.sales_return_status,
      returnCondition: row.return_condition,
      returnFinancialAction: row.return_financial_action,
      returnType: row.return_type,
      refundStatus: row.refund_status,
      refundAmount: parseFloat(row.refund_amount ?? 0),
      refundPaymentMode: row.refund_payment_mode,
      refundTransactionRef: row.refund_transaction_ref,
      refundDate: row.refund_date,
      isProcessed: row.is_processed,
      originalInvoiceId: row.original_invoice_id,
      originalInvoiceNumber: row.original_invoice_number,
      returnReason: row.return_reason,
      quotationReferenceId: row.quotation_reference_id,
      attachmentUrl: row.attachment_url,
      createdBy: row.created_by,
      createdAt: row.created_at,
      updatedAt: row.updated_at,
    };
  }

  private mapItemRow(row: any) {
    return {
      id: row.id,
      saleId: row.sale_id,
      finishedProductId: row.finished_product_id,
      finishedProductName: row.finished_product_name,
      finishedProductCode: row.finished_product_code,
      productDescription: row.product_description,
      quantity: parseFloat(row.quantity ?? 0),
      reservedQuantity: parseFloat(row.reserved_quantity ?? 0),
      producedQuantity: parseFloat(row.produced_quantity ?? 0),
      deliveredQuantity: parseFloat(row.delivered_quantity ?? 0),
      invoicedQuantity: parseFloat(row.invoiced_quantity ?? 0),
      returnedQuantity: parseFloat(row.returned_quantity ?? 0),
      unit: row.unit,
      rate: parseFloat(row.rate ?? 0),
      discountAmount: parseFloat(row.discount_amount ?? 0),
      gstPercent: parseFloat(row.gst_percent ?? 0),
      taxableAmount: parseFloat(row.taxable_amount ?? 0),
      cgstAmount: parseFloat(row.cgst_amount ?? 0),
      sgstAmount: parseFloat(row.sgst_amount ?? 0),
      igstAmount: parseFloat(row.igst_amount ?? 0),
      lineTotal: parseFloat(row.line_total ?? 0),
      productCondition: row.product_condition,
      returnCondition: row.return_condition,
      createdAt: row.created_at,
    };
  }
}
