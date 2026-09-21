import { Controller, Get, Param, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiParam, ApiTags } from '@nestjs/swagger';
import { RequirePermission } from '../../../core/auth/require-permission.decorator';
import { ReportQueryDto } from '../dto/report-query.dto';
import { ReportsService } from '../services/reports.service';

@ApiTags('Reports & Business Intelligence')
@ApiBearerAuth('JWT-auth')
@Controller('reports')
export class ReportsController {
  constructor(private readonly reportsService: ReportsService) {}

  @Get(':reportType')
  @RequirePermission('reports.view')
  @ApiOperation({
    summary: 'Query live aggregated business & statutory report statements',
    description:
      'Supported report types: inventory, purchase, production, sales, project-costing, expenses, commissions, financial-balance',
  })
  @ApiParam({
    name: 'reportType',
    enum: [
      'inventory',
      'purchase',
      'production',
      'sales',
      'project-costing',
      'expenses',
      'commissions',
      'financial-balance',
    ],
  })
  getReport(
    @Param('reportType') reportType: string,
    @Query() query: ReportQueryDto,
  ) {
    return this.reportsService.getReport(reportType, query);
  }
}
