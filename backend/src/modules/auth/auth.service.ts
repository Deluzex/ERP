import { Injectable } from '@nestjs/common';
import { AuditService } from '../../core/audit/audit.service';
import { Argon2Service } from '../../core/auth/argon2.service';
import { TokenService } from '../../core/auth/token.service';
import { DatabasePool } from '../../core/database/connection';
import { NotFoundError } from '../../core/errors/not-found.error';
import { UnauthorizedError } from '../../core/errors/unauthorized.error';
import { LoginDto } from './dto/login.dto';
import { RefreshTokenDto } from './dto/refresh-token.dto';

export interface AuthUserData {
  id: string;
  name: string;
  email: string;
  mobile: string;
  avatarUrl: string | null;
  roleId: string;
  roles: Array<{ id: string; name: string }>;
  branchIds: string[];
  stockLocationIds: string[];
  permissions: string[];
}

export interface AuthResponse {
  accessToken: string;
  refreshToken: string;
  expiresIn: number;
  user: AuthUserData;
}

@Injectable()
export class AuthService {
  constructor(
    private readonly db: DatabasePool,
    private readonly argon2: Argon2Service,
    private readonly tokenService: TokenService,
    private readonly auditService: AuditService,
  ) {}

  async login(
    dto: LoginDto,
    ipAddress?: string,
    correlationId?: string,
  ): Promise<AuthResponse> {
    const userRes = await this.db.query<{
      id: string;
      name: string;
      email: string;
      mobile: string;
      password_hash: string;
      avatar_url: string | null;
      is_active: boolean;
    }>(
      `SELECT id, name, email, mobile, password_hash, avatar_url, is_active
       FROM users
       WHERE LOWER(email) = LOWER($1)`,
      [dto.email.trim()],
    );

    const user = userRes.rows[0];
    if (!user || !user.is_active) {
      throw new UnauthorizedError('Invalid email or password');
    }

    const isPasswordValid = await this.argon2.verify(
      user.password_hash,
      dto.password,
    );
    if (!isPasswordValid) {
      throw new UnauthorizedError('Invalid email or password');
    }

    // Load roles, permissions, scopes
    const userData = await this.getUserAuthData(user.id);

    // Update last login
    await this.db.query('UPDATE users SET last_login_at = NOW() WHERE id = $1', [
      user.id,
    ]);

    // Issue tokens
    const tokens = await this.tokenService.generateTokens({
      sub: user.id,
      name: user.name,
      roleId: userData.roleId,
      branchIds: userData.branchIds,
      stockLocationIds: userData.stockLocationIds,
      permissions: userData.permissions,
    });

    // Extract refresh token jti
    const refreshPayload = await this.tokenService.verifyRefreshToken(
      tokens.refreshToken,
    );

    // Save refresh token record
    await this.db.query(
      `INSERT INTO refresh_tokens (user_id, token_id, expires_at)
       VALUES ($1, $2, NOW() + INTERVAL '7 days')`,
      [user.id, refreshPayload.jti],
    );

    // Audit log login event
    await this.auditService.log({
      userId: user.id,
      userName: user.name,
      action: 'USER_LOGIN',
      entityType: 'USER',
      entityId: user.id,
      ipAddress,
      correlationId,
    });

    return {
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      expiresIn: tokens.expiresIn,
      user: userData,
    };
  }

  async refresh(
    dto: RefreshTokenDto,
    ipAddress?: string,
    correlationId?: string,
  ): Promise<{ accessToken: string; refreshToken: string; expiresIn: number }> {
    const verified = await this.tokenService.verifyRefreshToken(dto.refreshToken);

    const tokenRes = await this.db.query<{
      id: string;
      user_id: string;
      token_id: string;
      is_revoked: boolean;
      expires_at: Date;
    }>(
      `SELECT id, user_id, token_id, is_revoked, expires_at
       FROM refresh_tokens
       WHERE token_id = $1`,
      [verified.jti],
    );

    const record = tokenRes.rows[0];
    if (!record || record.is_revoked || new Date(record.expires_at) < new Date()) {
      throw new UnauthorizedError('Invalid or expired refresh token');
    }

    // Revoke old refresh token (Token rotation)
    await this.db.query(
      'UPDATE refresh_tokens SET is_revoked = true WHERE token_id = $1',
      [verified.jti],
    );

    const userData = await this.getUserAuthData(record.user_id);

    // Generate new token pair
    const tokens = await this.tokenService.generateTokens({
      sub: userData.id,
      name: userData.name,
      roleId: userData.roleId,
      branchIds: userData.branchIds,
      stockLocationIds: userData.stockLocationIds,
      permissions: userData.permissions,
    });

    const newRefreshPayload = await this.tokenService.verifyRefreshToken(
      tokens.refreshToken,
    );

    await this.db.query(
      `INSERT INTO refresh_tokens (user_id, token_id, expires_at)
       VALUES ($1, $2, NOW() + INTERVAL '7 days')`,
      [userData.id, newRefreshPayload.jti],
    );

    await this.auditService.log({
      userId: userData.id,
      userName: userData.name,
      action: 'TOKEN_REFRESH',
      entityType: 'USER',
      entityId: userData.id,
      ipAddress,
      correlationId,
    });

    return {
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      expiresIn: tokens.expiresIn,
    };
  }

  async logout(
    userId: string,
    refreshToken?: string,
    ipAddress?: string,
    correlationId?: string,
  ): Promise<{ success: boolean }> {
    if (refreshToken) {
      try {
        const payload = await this.tokenService.verifyRefreshToken(refreshToken);
        await this.db.query(
          'UPDATE refresh_tokens SET is_revoked = true WHERE token_id = $1',
          [payload.jti],
        );
      } catch {
        // Continue even if token is already expired
      }
    }

    await this.auditService.log({
      userId,
      userName: 'User',
      action: 'USER_LOGOUT',
      entityType: 'USER',
      entityId: userId,
      ipAddress,
      correlationId,
    });

    return { success: true };
  }

  async getMe(userId: string): Promise<AuthUserData> {
    return this.getUserAuthData(userId);
  }

  private async getUserAuthData(userId: string): Promise<AuthUserData> {
    const userRes = await this.db.query<{
      id: string;
      name: string;
      email: string;
      mobile: string;
      avatar_url: string | null;
      is_active: boolean;
    }>(
      `SELECT id, name, email, mobile, avatar_url, is_active
       FROM users
       WHERE id = $1`,
      [userId],
    );

    const user = userRes.rows[0];
    if (!user || !user.is_active) {
      throw new NotFoundError('User', userId);
    }

    // Roles
    const rolesRes = await this.db.query<{
      id: string;
      name: string;
      is_primary: boolean;
    }>(
      `SELECT r.id, r.name, ur.is_primary
       FROM user_roles ur
       JOIN roles r ON r.id = ur.role_id
       WHERE ur.user_id = $1 AND r.is_active = true`,
      [userId],
    );

    const primaryRole =
      rolesRes.rows.find((r) => r.is_primary) || rolesRes.rows[0] || {
        id: 'viewer',
        name: 'Viewer',
      };

    // Permissions
    const permRes = await this.db.query<{ id: string }>(
      `SELECT DISTINCT p.id
       FROM role_permissions rp
       JOIN permissions p ON p.id = rp.permission_id
       WHERE rp.role_id IN (
         SELECT role_id FROM user_roles WHERE user_id = $1
       )`,
      [userId],
    );
    const permissions = permRes.rows.map((p) => p.id);

    // Branch scopes
    const branchRes = await this.db.query<{ branch_id: string }>(
      'SELECT branch_id FROM user_branch_access WHERE user_id = $1',
      [userId],
    );

    // Stock location scopes
    const locationRes = await this.db.query<{ stock_location_id: string }>(
      'SELECT stock_location_id FROM user_stock_location_access WHERE user_id = $1',
      [userId],
    );

    return {
      id: user.id,
      name: user.name,
      email: user.email,
      mobile: user.mobile,
      avatarUrl: user.avatar_url,
      roleId: primaryRole.id,
      roles: rolesRes.rows.map((r) => ({ id: r.id, name: r.name })),
      branchIds: branchRes.rows.map((b) => b.branch_id),
      stockLocationIds: locationRes.rows.map((l) => l.stock_location_id),
      permissions,
    };
  }
}
