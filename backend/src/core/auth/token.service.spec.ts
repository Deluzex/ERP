import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { UnauthorizedError } from '../errors/unauthorized.error';
import { TokenService } from './token.service';

describe('TokenService', () => {
  let tokenService: TokenService;
  let jwtService: JwtService;
  let configService: ConfigService;

  beforeEach(() => {
    jwtService = new JwtService({});
    configService = new ConfigService({
      JWT_ACCESS_SECRET: 'test-access-secret-12345678901234567890',
      JWT_REFRESH_SECRET: 'test-refresh-secret-12345678901234567890',
      JWT_ACCESS_EXPIRES_IN: '15m',
      JWT_REFRESH_EXPIRES_IN: '7d',
    });

    tokenService = new TokenService(jwtService, configService);
  });

  it('should generate valid access and refresh tokens', async () => {
    const payload = {
      sub: 'user-uuid-1',
      name: 'Kamal Patel',
      roleId: 'inventory_manager',
      branchIds: ['branch-1'],
      stockLocationIds: ['loc-1'],
      permissions: ['inventory.view', 'inventory.create'],
    };

    const tokens = await tokenService.generateTokens(payload);

    expect(tokens.accessToken).toBeDefined();
    expect(tokens.refreshToken).toBeDefined();
    expect(tokens.expiresIn).toBe(900);

    const verifiedAccess = await tokenService.verifyAccessToken(tokens.accessToken);
    expect(verifiedAccess.sub).toBe(payload.sub);
    expect(verifiedAccess.name).toBe(payload.name);
    expect(verifiedAccess.roleId).toBe(payload.roleId);
    expect(verifiedAccess.permissions).toEqual(payload.permissions);

    const verifiedRefresh = await tokenService.verifyRefreshToken(tokens.refreshToken);
    expect(verifiedRefresh.sub).toBe(payload.sub);
    expect(verifiedRefresh.jti).toBeDefined();
  });

  it('should throw UnauthorizedError when verifying an invalid access token', async () => {
    await expect(tokenService.verifyAccessToken('invalid.token.here')).rejects.toThrow(
      UnauthorizedError,
    );
  });

  it('should throw UnauthorizedError when verifying an invalid refresh token', async () => {
    await expect(tokenService.verifyRefreshToken('invalid.token.here')).rejects.toThrow(
      UnauthorizedError,
    );
  });
});
