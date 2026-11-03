import { Body, Controller, ForbiddenException, Get, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { AllowAuthenticated } from '../../core/auth/allow-authenticated.decorator';
import { Ctx } from '../../core/auth/ctx.decorator';
import { RequestContext } from '../../core/auth/request-context';
import { BroadcastRequestDto } from './dto/broadcast-request.dto';
import { ChatService } from './chat.service';

@ApiTags('Chat')
@ApiBearerAuth()
@Controller('chat')
export class ChatController {
  constructor(private readonly chatService: ChatService) {}

  @Get('session/status')
  @AllowAuthenticated()
  @ApiOperation({ summary: 'Get current WhatsApp Gateway session status and details' })
  async getSessionStatus() {
    return this.chatService.getSessionStatus();
  }

  @Post('session/connect')
  @AllowAuthenticated()
  @ApiOperation({ summary: 'Trigger connection / QR generation for WhatsApp Gateway session' })
  async connectSession() {
    return this.chatService.connectSession(true);
  }

  @Get('session/qr')
  @AllowAuthenticated()
  @ApiOperation({ summary: 'Fetch live QR code data URL for WhatsApp Gateway session' })
  async getSessionQr() {
    return this.chatService.getSessionQr();
  }

  @Post('session/disconnect')
  @AllowAuthenticated()
  @ApiOperation({ summary: 'Unlink / disconnect current WhatsApp session' })
  async disconnectSession() {
    return this.chatService.disconnectSession();
  }

  @Post('broadcast')
  @AllowAuthenticated()
  @ApiOperation({ summary: 'Admin-only: broadcast WhatsApp + in-app message to selected users' })
  async broadcast(@Body() dto: BroadcastRequestDto, @Ctx() ctx: RequestContext) {
    const role = (ctx.roleId || '').toLowerCase();
    const isAdmin = role === 'admin' || role === 'super_admin';
    if (!isAdmin) {
      throw new ForbiddenException('Only administrators can send broadcast messages');
    }
    return this.chatService.broadcastMessage(dto, ctx.userId);
  }
}
