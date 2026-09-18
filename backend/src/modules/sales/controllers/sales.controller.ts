import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Patch,
  Post,
  Query,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Ctx } from '../../../core/auth/ctx.decorator';
import { RequestContext } from '../../../core/auth/request-context';
import { RequirePermission } from '../../../core/auth/require-permission.decorator';
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
import { SalesService } from '../services/sales.service';

@ApiTags('Sales & Commercial Lifecycle')
@ApiBearerAuth('JWT-auth')
@Controller('sales')
export class SalesController {
  constructor(private readonly salesService: SalesService) {}

  // ==========================================================================
  // DASHBOARD
  // ==========================================================================
  @Get('dashboard')
  @RequirePermission('sales.view')
  @ApiOperation({ summary: 'Get sales pipeline and commercial operations metrics' })
  getDashboardMetrics() {
    return this.salesService.getDashboardMetrics();
  }

  // ==========================================================================
  // QUOTATIONS
  // ==========================================================================
  @Post('quotations')
  @RequirePermission('sales.create')
  @ApiOperation({ summary: 'Create price quotation with zero stock effect' })
  createQuotation(@Body() dto: CreateQuotationDto, @Ctx() ctx: RequestContext) {
    return this.salesService.createQuotation(dto, ctx.userId, ctx.correlationId);
  }

  @Get('quotations')
  @RequirePermission('sales.view')
  @ApiOperation({ summary: 'List price quotations with filtering and pagination' })
  findQuotations(@Query() query: SalesQueryDto) {
    return this.salesService.findAll({ ...query, documentType: 'quotation' });
  }

  @Get('quotations/:id')
  @RequirePermission('sales.view')
  @ApiOperation({ summary: 'Get quotation details and line items' })
  findQuotationById(@Param('id') id: string) {
    return this.salesService.findById(id);
  }

  @Post('quotations/:id/revisions')
  @RequirePermission('sales.create')
  @ApiOperation({ summary: 'Create quotation revision, superseding previous quotation' })
  createQuotationRevision(
    @Param('id') id: string,
    @Body() dto: CreateQuotationRevisionDto,
    @Ctx() ctx: RequestContext,
  ) {
    return this.salesService.createQuotationRevision(id, dto, ctx.userId, ctx.correlationId);
  }

  @Patch('quotations/:id/status')
  @RequirePermission('sales.edit')
  @ApiOperation({ summary: 'Update quotation lifecycle status' })
  updateQuotationStatus(
    @Param('id') id: string,
    @Body() dto: UpdateQuotationStatusDto,
    @Ctx() ctx: RequestContext,
  ) {
    return this.salesService.updateQuotationStatus(id, dto, ctx.userId, ctx.correlationId);
  }

  @Post('quotations/:id/convert-to-proforma')
  @RequirePermission('sales.create')
  @ApiOperation({ summary: 'Convert accepted quotation into Proforma Invoice' })
  convertToProforma(@Param('id') id: string, @Ctx() ctx: RequestContext) {
    return this.salesService.convertToProforma(id, ctx.userId, ctx.correlationId);
  }

  // ==========================================================================
  // PROFORMA INVOICES
  // ==========================================================================
  @Get('proforma')
  @RequirePermission('sales.view')
  @ApiOperation({ summary: 'List proforma invoices' })
  findProformas(@Query() query: SalesQueryDto) {
    return this.salesService.findAll({ ...query, documentType: 'proformaInvoice' });
  }

  @Get('proforma/:id')
  @RequirePermission('sales.view')
  @ApiOperation({ summary: 'Get proforma invoice details' })
  findProformaById(@Param('id') id: string) {
    return this.salesService.findById(id);
  }

  @Post('proforma/:id/advance-payment')
  @HttpCode(HttpStatus.OK)
  @RequirePermission('sales.create')
  @ApiOperation({ summary: 'Record advance payment against Proforma Invoice' })
  recordAdvancePayment(
    @Param('id') id: string,
    @Body() dto: RecordAdvancePaymentDto,
    @Ctx() ctx: RequestContext,
  ) {
    return this.salesService.recordAdvancePayment(id, dto, ctx.userId, ctx.correlationId);
  }

  // ==========================================================================
  // SALES ORDERS
  // ==========================================================================
  @Post('orders')
  @RequirePermission('sales.create')
  @ApiOperation({
    summary: 'Create Sales Order with automatic stock allocation and production shortage orders',
  })
  createSalesOrder(@Body() dto: CreateSalesOrderDto, @Ctx() ctx: RequestContext) {
    return this.salesService.createSalesOrder(dto, ctx.userId, ctx.correlationId);
  }

  @Get('orders')
  @RequirePermission('sales.view')
  @ApiOperation({ summary: 'List sales orders with allocation and dispatch status' })
  findSalesOrders(@Query() query: SalesQueryDto) {
    return this.salesService.findAll({ ...query, documentType: 'salesOrder' });
  }

  @Get('orders/:id')
  @RequirePermission('sales.view')
  @ApiOperation({ summary: 'Get sales order details and allocated items' })
  findSalesOrderById(@Param('id') id: string) {
    return this.salesService.findById(id);
  }

  @Patch('orders/:id/status')
  @RequirePermission('sales.edit')
  @ApiOperation({ summary: 'Update sales order workflow status' })
  updateSalesOrderStatus(
    @Param('id') id: string,
    @Body() dto: UpdateSalesOrderStatusDto,
    @Ctx() ctx: RequestContext,
  ) {
    return this.salesService.updateSalesOrderStatus(id, dto, ctx.userId, ctx.correlationId);
  }

  // ==========================================================================
  // DELIVERY CHALLANS (PHYSICAL STOCK OUT)
  // ==========================================================================
  @Post('deliveries')
  @RequirePermission('sales.create')
  @ApiOperation({
    summary: 'Create Delivery Challan: deduct physical stock, release reservation, log StockMovement',
  })
  createDelivery(@Body() dto: CreateDeliveryDto, @Ctx() ctx: RequestContext) {
    return this.salesService.createDelivery(dto, ctx.userId, ctx.correlationId);
  }

  @Get('deliveries')
  @RequirePermission('sales.view')
  @ApiOperation({ summary: 'List delivery challans with tracking details' })
  findDeliveries(@Query() query: SalesQueryDto) {
    return this.salesService.findAll({ ...query, documentType: 'delivery' });
  }

  @Get('deliveries/:id')
  @RequirePermission('sales.view')
  @ApiOperation({ summary: 'Get delivery challan details and dispatched items' })
  findDeliveryById(@Param('id') id: string) {
    return this.salesService.findById(id);
  }

  @Patch('deliveries/:id/tracking')
  @RequirePermission('sales.edit')
  @ApiOperation({ summary: 'Update courier, tracking, and transit details' })
  updateDeliveryTracking(
    @Param('id') id: string,
    @Body() dto: UpdateDeliveryTrackingDto,
    @Ctx() ctx: RequestContext,
  ) {
    return this.salesService.updateDeliveryTracking(id, dto, ctx.userId, ctx.correlationId);
  }

  // ==========================================================================
  // TAX INVOICES & DIRECT POS COUNTER SALES
  // ==========================================================================
  @Post('invoices/from-delivery')
  @RequirePermission('sales.create')
  @ApiOperation({
    summary: 'Generate Tax Invoice from Delivery: debit Customer ledger & auto-calculate Architect Commission',
  })
  createInvoiceFromDelivery(@Body() dto: CreateInvoiceFromDeliveryDto, @Ctx() ctx: RequestContext) {
    return this.salesService.createInvoiceFromDelivery(dto, ctx.userId, ctx.correlationId);
  }

  @Post('direct-sale')
  @RequirePermission('sales.create')
  @ApiOperation({
    summary: '1-Click Direct Counter Sale: atomic invoice creation, physical stock deduction, and payment receipt',
  })
  createDirectSale(@Body() dto: CreateDirectSaleDto, @Ctx() ctx: RequestContext) {
    return this.salesService.createDirectSale(dto, ctx.userId, ctx.correlationId);
  }

  @Get('invoices')
  @RequirePermission('sales.view')
  @ApiOperation({ summary: 'List tax invoices with payment and aging status' })
  findInvoices(@Query() query: SalesQueryDto) {
    return this.salesService.findAll({ ...query, documentType: 'invoice' });
  }

  @Get('invoices/:id')
  @RequirePermission('sales.view')
  @ApiOperation({ summary: 'Get tax invoice details, GST breakdown, and commissions' })
  findInvoiceById(@Param('id') id: string) {
    return this.salesService.findById(id);
  }

  @Post('invoices/:id/payments')
  @HttpCode(HttpStatus.OK)
  @RequirePermission('sales.create')
  @ApiOperation({ summary: 'Record customer receipt against Tax Invoice' })
  recordInvoicePayment(
    @Param('id') id: string,
    @Body() dto: RecordInvoicePaymentDto,
    @Ctx() ctx: RequestContext,
  ) {
    return this.salesService.recordInvoicePayment(id, dto, ctx.userId, ctx.correlationId);
  }

  // ==========================================================================
  // SALES RETURNS (RMA) & REFUNDS
  // ==========================================================================
  @Post('returns')
  @RequirePermission('sales.create')
  @ApiOperation({ summary: 'Submit Sales Return (RMA) request linked to original Tax Invoice' })
  createSalesReturn(@Body() dto: CreateSalesReturnDto, @Ctx() ctx: RequestContext) {
    return this.salesService.createSalesReturn(dto, ctx.userId, ctx.correlationId);
  }

  @Get('returns')
  @RequirePermission('sales.view')
  @ApiOperation({ summary: 'List sales return requests' })
  findSalesReturns(@Query() query: SalesQueryDto) {
    return this.salesService.findAll({ ...query, documentType: 'salesReturn' });
  }

  @Get('returns/:id')
  @RequirePermission('sales.view')
  @ApiOperation({ summary: 'Get sales return details and inspection results' })
  findSalesReturnById(@Param('id') id: string) {
    return this.salesService.findById(id);
  }

  @Post('returns/:id/approve')
  @HttpCode(HttpStatus.OK)
  @RequirePermission('sales.approve')
  @ApiOperation({
    summary: 'Approve & Process RMA: restock good goods or scrap adjust, update customer ledger, reverse commission',
  })
  approveSalesReturn(@Param('id') id: string, @Ctx() ctx: RequestContext) {
    return this.salesService.approveSalesReturn(id, ctx.userId, ctx.correlationId);
  }

  @Post('returns/:id/refund')
  @HttpCode(HttpStatus.OK)
  @RequirePermission('sales.create')
  @ApiOperation({ summary: 'Disburse refund or issue store credit for approved sales return' })
  disburseRefund(
    @Param('id') id: string,
    @Body() dto: DisburseRefundDto,
    @Ctx() ctx: RequestContext,
  ) {
    return this.salesService.disburseRefund(id, dto, ctx.userId, ctx.correlationId);
  }

  // ==========================================================================
  // GENERIC SALES GETTERS
  // ==========================================================================
  @Get()
  @RequirePermission('sales.view')
  @ApiOperation({ summary: 'List all sales documents' })
  findAll(@Query() query: SalesQueryDto) {
    return this.salesService.findAll(query);
  }

  @Get(':id')
  @RequirePermission('sales.view')
  @ApiOperation({ summary: 'Get sales document by ID' })
  findById(@Param('id') id: string) {
    return this.salesService.findById(id);
  }
}
