import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Post,
  Req,
} from '@nestjs/common';
import { Request } from 'express';
import { AllowAuthenticated } from '../../core/auth/allow-authenticated.decorator';
import { Ctx } from '../../core/auth/ctx.decorator';
import { RequestContext } from '../../core/auth/request-context';
import { Public } from '../../core/auth/public.decorator';
import { ApiTags } from '@nestjs/swagger';
import { AuthService } from './auth.service';
import { LoginDto } from './dto/login.dto';
import { RefreshTokenDto } from './dto/refresh-token.dto';

@ApiTags('Authentication')
@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Public()
  @Post('login')
  @HttpCode(HttpStatus.OK)
  async login(@Body() dto: LoginDto, @Req() req: Request) {
    const correlationId = (req.headers['x-correlation-id'] as string) || 'unknown';
    const ipAddress = req.ip || req.socket.remoteAddress;
    return this.authService.login(dto, ipAddress, correlationId);
  }

  @Public()
  @Post('refresh')
  @HttpCode(HttpStatus.OK)
  async refresh(@Body() dto: RefreshTokenDto, @Req() req: Request) {
    const correlationId = (req.headers['x-correlation-id'] as string) || 'unknown';
    const ipAddress = req.ip || req.socket.remoteAddress;
    return this.authService.refresh(dto, ipAddress, correlationId);
  }

  @AllowAuthenticated()
  @Post('logout')
  @HttpCode(HttpStatus.OK)
  async logout(
    @Ctx() ctx: RequestContext,
    @Body() body?: { refreshToken?: string },
  ) {
    return this.authService.logout(
      ctx.userId,
      body?.refreshToken,
      ctx.ipAddress,
      ctx.correlationId,
    );
  }

  @AllowAuthenticated()
  @Get('me')
  async getMe(@Ctx() ctx: RequestContext) {
    return this.authService.getMe(ctx.userId);
  }
}
