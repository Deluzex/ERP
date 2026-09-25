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

  describe('Production secret validation', () => {
    it('should throw if NODE_ENV is production and JWT_ACCESS_SECRET is missing or default', () => {
      const prodConfig = new ConfigService({
        NODE_ENV: 'production',
        JWT_ACCESS_SECRET: 'deluzex_dev_access_secret',
        JWT_REFRESH_SECRET: 'valid-secure-refresh-secret-1234567890',
      });
      expect(() => new TokenService(jwtService, prodConfig)).toThrow(
        /JWT_ACCESS_SECRET must be configured with a secure/i,
      );
    });

    it('should throw if NODE_ENV is production and JWT_REFRESH_SECRET is missing or default', () => {
      const prodConfig = new ConfigService({
        NODE_ENV: 'production',
        JWT_ACCESS_SECRET: 'valid-secure-access-secret-1234567890',
        JWT_REFRESH_SECRET: 'deluzex_dev_refresh_secret',
      });
      expect(() => new TokenService(jwtService, prodConfig)).toThrow(
        /JWT_REFRESH_SECRET must be configured with a secure/i,
      );
    });

    it('should initialize successfully in production with valid custom secrets', () => {
      const prodConfig = new ConfigService({
        NODE_ENV: 'production',
        JWT_ACCESS_SECRET: 'valid-secure-access-secret-1234567890',
        JWT_REFRESH_SECRET: 'valid-secure-refresh-secret-1234567890',
      });
      expect(() => new TokenService(jwtService, prodConfig)).not.toThrow();
    });
  });
});

