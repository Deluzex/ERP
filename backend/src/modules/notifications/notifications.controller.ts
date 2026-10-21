import { Body, Controller, Get, Param, Patch, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { AllowAuthenticated } from '../../core/auth/allow-authenticated.decorator';
import { Ctx } from '../../core/auth/ctx.decorator';
import { RequestContext } from '../../core/auth/request-context';
import { CreateNotificationDto } from './dto/create-notification.dto';
import { NotificationQueryDto } from './dto/notification-query.dto';
import { NotificationsService } from './notifications.service';

@ApiTags('Notifications')
@ApiBearerAuth()
@Controller('notifications')
export class NotificationsController {
  constructor(private readonly notificationsService: NotificationsService) {}

  @Get()
  @AllowAuthenticated()
  @ApiOperation({ summary: 'Get role-filtered and user-addressed notifications' })
  getNotifications(
    @Query() query: NotificationQueryDto,
    @Ctx() ctx: RequestContext,
  ) {
    return this.notificationsService.getNotifications(query, ctx);
  }

  @Post()
  @AllowAuthenticated()
  @ApiOperation({ summary: 'Create and persist an internal notification' })
  createNotification(
    @Body() dto: CreateNotificationDto,
    @Ctx() ctx: RequestContext,
  ) {
    return this.notificationsService.createNotification(dto, ctx.userId);
  }

  @Patch('mark-all-read')
  @AllowAuthenticated()
  @ApiOperation({ summary: 'Mark all visible notifications as read for current user' })
  markAllAsRead(@Ctx() ctx: RequestContext) {
    return this.notificationsService.markAllAsRead(ctx);
  }

  @Patch(':id/read')
  @AllowAuthenticated()
  @ApiOperation({ summary: 'Mark a specific notification as read' })
  markAsRead(
    @Param('id') id: string,
    @Ctx() ctx: RequestContext,
  ) {
    return this.notificationsService.markAsRead(id, ctx);
  }
}
