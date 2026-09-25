import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Post,
  Put,
  Query,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Ctx } from '../../../core/auth/ctx.decorator';
import { RequestContext } from '../../../core/auth/request-context';
import { RequirePermission } from '../../../core/auth/require-permission.decorator';
import {
  CreateProjectDto,
  DeleteProjectDto,
  ProjectQueryDto,
  UpdateProjectDto,
} from '../dto/projects.dto';
import { ProjectsService } from '../services/projects.service';

@ApiTags('Architectural Projects & Portfolio')
@ApiBearerAuth('JWT-auth')
@Controller('projects')
export class ProjectsController {
  constructor(private readonly projectsService: ProjectsService) {}

  @Get()
  @RequirePermission('projects.view')
  @ApiOperation({ summary: 'List architectural projects with KPI summaries' })
  findAll(@Query() query: ProjectQueryDto) {
    return this.projectsService.findAll(query);
  }

  @Get(':id/financials')
  @RequirePermission('projects.view')
  @ApiOperation({
    summary: 'Get project financial turnover, material costs, and margin analysis',
  })
  getFinancials(@Param('id') id: string) {
    return this.projectsService.getFinancials(id);
  }

  @Get(':id')
  @RequirePermission('projects.view')
  @ApiOperation({ summary: 'Get project details by ID' })
  findById(@Param('id') id: string) {
    return this.projectsService.findById(id);
  }

  @Post()
  @RequirePermission('projects.create')
  @ApiOperation({ summary: 'Create an architectural project' })
  create(@Body() dto: CreateProjectDto, @Ctx() ctx: RequestContext) {
    return this.projectsService.create(dto, ctx.userId, ctx.correlationId);
  }

  @Put(':id')
  @RequirePermission('projects.edit')
  @ApiOperation({ summary: 'Update an architectural project' })
  update(
    @Param('id') id: string,
    @Body() dto: UpdateProjectDto,
    @Ctx() ctx: RequestContext,
  ) {
    return this.projectsService.update(id, dto, ctx.userId, ctx.correlationId);
  }

  @Delete(':id')
  @RequirePermission('projects.delete')
  @ApiOperation({ summary: 'Soft-delete an architectural project with mandatory reason' })
  delete(
    @Param('id') id: string,
    @Body() dto: DeleteProjectDto,
    @Ctx() ctx: RequestContext,
  ) {
    return this.projectsService.delete(id, dto.reason, ctx.userId, ctx.correlationId);
  }
}
