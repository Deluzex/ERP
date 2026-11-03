import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import axios from 'axios';
import { BroadcastRequestDto } from './dto/broadcast-request.dto';
import { NotificationsService } from '../notifications/notifications.service';

export interface BroadcastResult {
  sent: number;
  failed: number;
  inAppCreated: number;
}

@Injectable()
export class ChatService {
  private readonly logger = new Logger(ChatService.name);
  private readonly gatewayUrl: string;
  private readonly apiKey: string;
  private readonly configuredSessionId: string;
  private activeSessionId: string = '';

  constructor(
    private readonly config: ConfigService,
    private readonly notificationsService: NotificationsService,
  ) {
    this.gatewayUrl = this.config.get<string>('WHATSAPP_GATEWAY_URL', '');
    this.apiKey = this.config.get<string>('WHATSAPP_GATEWAY_KEY', '');
    this.configuredSessionId = this.config.get<string>('WHATSAPP_GATEWAY_SESSION_ID', '');
    this.activeSessionId = this.configuredSessionId;
  }

  /**
   * Resolves the active session ID: either cached in memory, from config, or dynamically discovered.
   */
  private async getEffectiveSessionId(): Promise<string> {
    if (this.activeSessionId) {
      return this.activeSessionId;
    }
    if (this.configuredSessionId) {
      this.activeSessionId = this.configuredSessionId;
      return this.activeSessionId;
    }
    try {
      const res = await axios.get(`${this.gatewayUrl}/v1/sessions/pair`, {
        headers: { 'X-API-Key': this.apiKey },
        timeout: 5000,
      });
      if (res.data?.data?.sessionId) {
        this.activeSessionId = res.data.data.sessionId;
        return this.activeSessionId;
      }
    } catch (_) {}
    return '';
  }

  /**
   * Cleans phone number to international format without + or spaces (e.g., 919876543210)
   */
  private cleanPhoneNumber(phone: string): string {
    let clean = phone.replace(/\D/g, '');
    if (clean.length === 10) {
      clean = '91' + clean;
    }
    return clean;
  }

  async broadcastMessage(dto: BroadcastRequestDto, actorUserId: string): Promise<BroadcastResult> {
    const result: BroadcastResult = { sent: 0, failed: 0, inAppCreated: 0 };
    const formattedMessage = `*${dto.subject}*\n\n${dto.message}`;

    for (const recipient of dto.recipients) {
      // ── WhatsApp channel ──────────────────────────────────────────────────
      if (dto.sendWhatsApp !== false) {
        const cleanPhone = this.cleanPhoneNumber(recipient.phone);
        const idempotencyKey = `broadcast-${Date.now()}-${recipient.userId}`;
        try {
          const activeSessionId = await this.getEffectiveSessionId();
          const sendPayload: Record<string, any> = {
            to: cleanPhone,
            message: formattedMessage,
          };
          if (activeSessionId) {
            sendPayload.sessionId = activeSessionId;
          }

          // Zero-Session-ID / Targeted Session POST /v1/messages/send
          await axios.post(
            `${this.gatewayUrl}/v1/messages/send`,
            sendPayload,
            {
              headers: {
                'X-API-Key': this.apiKey,
                'Idempotency-Key': idempotencyKey,
                'Content-Type': 'application/json',
              },
              timeout: 10_000,
            },
          );
          result.sent++;
          this.logger.log(`WA sent to ${recipient.name} (${cleanPhone})`);
        } catch (err: any) {
          result.failed++;
          this.logger.error(
            `WA failed for ${recipient.name} (${cleanPhone}): ${err?.response?.data ? JSON.stringify(err.response.data) : err.message}`,
          );
        }

        // Anti-spam stagger (2 seconds between each message)
        await new Promise((resolve) => setTimeout(resolve, 2000));
      }

      // ── In-App Notification channel ───────────────────────────────────────
      if (dto.sendInApp !== false) {
        try {
          let recipientUserId: string | undefined = undefined;
          if (
            /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(
              recipient.userId,
            )
          ) {
            recipientUserId = recipient.userId;
          }

          try {
            await this.notificationsService.createNotification(
              {
                title: dto.subject,
                message: dto.message,
                notificationType: 'team_broadcast',
                recipientUserId,
                recipientName: recipient.name,
                sourceModule: 'chat',
                relatedEntityType: 'broadcast',
                data: { broadcastedBy: actorUserId, recipientUserId: recipient.userId },
              },
              actorUserId,
            );
            result.inAppCreated++;
          } catch (fkError: any) {
            if (recipientUserId && fkError.message?.includes('foreign key constraint')) {
              await this.notificationsService.createNotification(
                {
                  title: dto.subject,
                  message: dto.message,
                  notificationType: 'team_broadcast',
                  recipientName: recipient.name,
                  sourceModule: 'chat',
                  relatedEntityType: 'broadcast',
                  data: { broadcastedBy: actorUserId, recipientUserId: recipient.userId },
                },
                actorUserId,
              );
              result.inAppCreated++;
            } else {
              throw fkError;
            }
          }
        } catch (err: any) {
          this.logger.error(
            `In-app notification failed for ${recipient.userId}: ${err.message}`,
          );
        }
      }
    }

    return result;
  }

  async getSessionStatus(): Promise<{
    sessionId: string;
    status: string;
    phoneNumber: string | null;
    qrDataUrl: string | null;
    message?: string;
  }> {
    try {
      // Zero-Session-ID Edition: GET /v1/sessions/pair
      const res = await axios.get(`${this.gatewayUrl}/v1/sessions/pair`, {
        headers: { 'X-API-Key': this.apiKey },
        timeout: 8000,
      });
      const data = res.data?.data || {};
      if (data.sessionId) {
        this.activeSessionId = data.sessionId;
      }
      return {
        sessionId: data.sessionId || this.activeSessionId || this.configuredSessionId,
        status: data.status || 'disconnected',
        phoneNumber: data.phone_number || null,
        qrDataUrl: data.qrDataUrl || null,
        message: data.message,
      };
    } catch (err: any) {
      this.logger.error(`Failed to fetch session status: ${err?.response?.data ?? err.message}`);
      return {
        sessionId: this.activeSessionId || this.configuredSessionId,
        status: 'disconnected',
        phoneNumber: null,
        qrDataUrl: null,
        message: err?.response?.data?.message || err.message,
      };
    }
  }

  async connectSession(force = true): Promise<{
    sessionId: string;
    status: string;
    qrDataUrl: string | null;
    phoneNumber: string | null;
    message?: string;
  }> {
    try {
      // Zero-Session-ID Edition: GET /v1/sessions/pair?force=true
      const res = await axios.get(`${this.gatewayUrl}/v1/sessions/pair?force=${force}`, {
        headers: { 'X-API-Key': this.apiKey },
        timeout: 10000,
      });
      const data = res.data?.data || {};
      if (data.sessionId) {
        this.activeSessionId = data.sessionId;
      }
      return {
        sessionId: data.sessionId || this.activeSessionId || this.configuredSessionId,
        status: data.status || 'connecting',
        qrDataUrl: data.qrDataUrl || null,
        phoneNumber: data.phone_number || null,
        message: data.message,
      };
    } catch (err: any) {
      this.logger.error(`Failed to connect session: ${err?.response?.data ?? err.message}`);
      return {
        sessionId: this.activeSessionId || this.configuredSessionId,
        status: 'error',
        qrDataUrl: null,
        phoneNumber: null,
        message: err?.response?.data?.message || err.message,
      };
    }
  }

  async getSessionQr(): Promise<{
    sessionId: string;
    status: string;
    qrDataUrl: string | null;
    phoneNumber: string | null;
    message?: string;
  }> {
    try {
      // Zero-Session-ID Edition: GET /v1/sessions/pair
      const res = await axios.get(`${this.gatewayUrl}/v1/sessions/pair`, {
        headers: { 'X-API-Key': this.apiKey },
        timeout: 8000,
      });
      const data = res.data?.data || {};
      if (data.sessionId) {
        this.activeSessionId = data.sessionId;
      }
      return {
        sessionId: data.sessionId || this.activeSessionId || this.configuredSessionId,
        status: data.status || 'disconnected',
        qrDataUrl: data.qrDataUrl || null,
        phoneNumber: data.phone_number || null,
        message: data.message,
      };
    } catch (err: any) {
      this.logger.error(`Failed to fetch QR: ${err?.response?.data ?? err.message}`);
      return {
        sessionId: this.activeSessionId || this.configuredSessionId,
        status: 'error',
        qrDataUrl: null,
        phoneNumber: null,
        message: err?.response?.data?.message || err.message,
      };
    }
  }

  async disconnectSession(): Promise<{
    success: boolean;
    message?: string;
  }> {
    try {
      const activeSessionId = await this.getEffectiveSessionId();

      // 1. Fully delete and purge credentials on the Gateway so Baileys does not auto-reconnect
      if (activeSessionId) {
        try {
          await axios.delete(`${this.gatewayUrl}/v1/sessions/${activeSessionId}`, {
            headers: { 'X-API-Key': this.apiKey },
            timeout: 8000,
          });
          this.logger.log(`Purged gateway session credentials for ${activeSessionId}`);
        } catch (delErr: any) {
          this.logger.warn(`Failed to delete session ${activeSessionId}: ${delErr.message}`);
        }
      }

      // 2. Also call /v1/sessions/disconnect for zero-session compatibility
      const res = await axios.post(
        `${this.gatewayUrl}/v1/sessions/disconnect`,
        activeSessionId ? { sessionId: activeSessionId } : {},
        {
          headers: { 'X-API-Key': this.apiKey },
          timeout: 8000,
        },
      );

      this.activeSessionId = '';
      return {
        success: res.data?.success !== false,
        message: res.data?.message || 'Disconnected and credentials purged successfully',
      };
    } catch (err: any) {
      this.logger.error(`Failed to disconnect session: ${err?.response?.data ?? err.message}`);
      return {
        success: false,
        message: err?.response?.data?.message || err.message,
      };
    }
  }
}
