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
    this.gatewayUrl = (this.config.get<string>('WHATSAPP_GATEWAY_URL', '') || '').replace(/\/+$/, '');
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
    if (!this.gatewayUrl) {
      return '';
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
   * Generates a randomized, humanized delay (jitter) between messages
   * to protect against Meta/WhatsApp automated spam detection & rate-limit bans.
   * Default: random between minDelayMs (3,500ms) and maxDelayMs (6,500ms).
   */
  private async humanizedAntiBanDelay(currentIndex: number, totalCount: number): Promise<void> {
    // No delay needed after the final message
    if (currentIndex >= totalCount - 1) {
      return;
    }

    const minDelay = Number(this.config.get<number>('WHATSAPP_MIN_DELAY_MS', 3500));
    const maxDelay = Number(this.config.get<number>('WHATSAPP_MAX_DELAY_MS', 6500));
    const randomizedJitter = Math.floor(Math.random() * (maxDelay - minDelay + 1)) + minDelay;

    // Optional batch cooldown: every 10 messages, add an extra human pause of 8-12 seconds
    let totalDelay = randomizedJitter;
    if ((currentIndex + 1) % 10 === 0) {
      const batchCooldown = Math.floor(Math.random() * 4000) + 8000;
      this.logger.log(
        `Anti-spam batch cooldown after message ${currentIndex + 1}: pausing for ${batchCooldown}ms`,
      );
      totalDelay += batchCooldown;
    }

    this.logger.log(
      `Anti-ban pacing: waiting ${(totalDelay / 1000).toFixed(2)}s before recipient ${currentIndex + 2}/${totalCount}`,
    );
    await new Promise((resolve) => setTimeout(resolve, totalDelay));
  }

  /**
   * Cleans phone number to international format without + or spaces (e.g., 919876543210).
   * Safely returns empty string if phone is null, undefined, or not a string.
   */
  private cleanPhoneNumber(phone?: string | null): string {
    if (!phone || typeof phone !== 'string') {
      return '';
    }
    let clean = phone.replace(/\D/g, '');
    if (clean.length === 10) {
      clean = '91' + clean;
    }
    return clean;
  }

  async broadcastMessage(dto: BroadcastRequestDto, actorUserId: string): Promise<BroadcastResult> {
    const result: BroadcastResult = { sent: 0, failed: 0, inAppCreated: 0 };

    try {
      const subject = dto?.subject ? String(dto.subject).trim() : 'Notice';
      const body = dto?.message ? String(dto.message).trim() : '';
      const formattedMessage = `*${subject}*\n\n${body}`;
      const recipients = Array.isArray(dto?.recipients) ? dto.recipients : [];

      for (let i = 0; i < recipients.length; i++) {
        const recipient = recipients[i];
        if (!recipient) {
          continue;
        }

        // ── WhatsApp channel ──────────────────────────────────────────────────
        if (dto.sendWhatsApp !== false) {
          const cleanPhone = this.cleanPhoneNumber(recipient.phone);
          const idempotencyKey = `broadcast-${Date.now()}-${recipient.userId || i}`;

          if (!cleanPhone || cleanPhone.length < 10) {
            result.failed++;
            this.logger.warn(
              `WA skipped for ${recipient.name || 'unknown'}: missing or invalid phone number (${recipient.phone})`,
            );
          } else {
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
          }

          // Anti-ban humanized pacing (random jitter 3.5s - 6.5s + batch cooldown)
          try {
            await this.humanizedAntiBanDelay(i, recipients.length);
          } catch (_) {}
        }

        // ── In-App Notification channel ───────────────────────────────────────
        if (dto.sendInApp !== false) {
          try {
            let recipientUserId: string | undefined = undefined;
            if (
              recipient.userId &&
              /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(
                recipient.userId,
              )
            ) {
              recipientUserId = recipient.userId;
            }

            try {
              await this.notificationsService.createNotification(
                {
                  title: subject,
                  message: body,
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
                    title: subject,
                    message: body,
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
              `In-app notification failed for ${recipient?.userId}: ${err.message}`,
            );
          }
        }
      }
    } catch (topLevelError: any) {
      this.logger.error(`Critical broadcast failure: ${topLevelError.message}`, topLevelError.stack);
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
      // Zero-Session-ID Edition: GET /v1/sessions/pair?force=${force}
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
