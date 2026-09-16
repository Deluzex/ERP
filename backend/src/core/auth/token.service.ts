import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { v4 as uuidv4 } from 'uuid';
import { UnauthorizedError } from '../errors/unauthorized.error';

export interface JwtPayload {
  sub: string; // userId
  name: string;
  roleId: string;
  branchIds: string[];
  stockLocationIds: string[];
  permissions: string[];
  jti?: string;
}

export interface GeneratedTokens {
  accessToken: string;
  refreshToken: string;
  expiresIn: number;
}

@Injectable()
export class TokenService {
  private readonly accessSecret: string;
  private readonly refreshSecret: string;
  private readonly accessExpiresIn: string;
  private readonly refreshExpiresIn: string;

  constructor(
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
  ) {
    this.accessSecret = this.config.get<string>('JWT_ACCESS_SECRET') || 'deluzex_dev_access_secret';
    this.refreshSecret = this.config.get<string>('JWT_REFRESH_SECRET') || 'deluzex_dev_refresh_secret';
    this.accessExpiresIn = this.config.get<string>('JWT_ACCESS_EXPIRES_IN') || '15m';
    this.refreshExpiresIn = this.config.get<string>('JWT_REFRESH_EXPIRES_IN') || '7d';
  }

  async generateTokens(payload: Omit<JwtPayload, 'jti'>): Promise<GeneratedTokens> {
    const tokenId = uuidv4();
    const accessToken = await this.jwt.signAsync(
      { ...payload, jti: tokenId },
      {
        secret: this.accessSecret,
        expiresIn: this.accessExpiresIn as any,
      },
    );

    const refreshToken = await this.jwt.signAsync(
      { sub: payload.sub, jti: uuidv4() },
      {
        secret: this.refreshSecret,
        expiresIn: this.refreshExpiresIn as any,
      },
    );

    return {
      accessToken,
      refreshToken,
      expiresIn: 900, // 15 minutes in seconds
    };
  }

  async verifyAccessToken(token: string): Promise<JwtPayload> {
    try {
      return await this.jwt.verifyAsync<JwtPayload>(token, {
        secret: this.accessSecret,
      });
    } catch {
      throw new UnauthorizedError('Invalid or expired access token');
    }
  }

  async verifyRefreshToken(token: string): Promise<{ sub: string; jti: string }> {
    try {
      return await this.jwt.verifyAsync<{ sub: string; jti: string }>(token, {
        secret: this.refreshSecret,
      });
    } catch {
      throw new UnauthorizedError('Invalid or expired refresh token');
    }
  }
}
