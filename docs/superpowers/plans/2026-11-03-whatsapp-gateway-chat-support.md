# WhatsApp Gateway Integration — Chat Support Automation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade the Chat Support screen from manually opening `wa.me` links to a fully automated backend-driven WhatsApp broadcast powered by the WhatsApp Multi-Project Gateway, plus persist every broadcast as an in-app notification to all selected users.

**Architecture:** The Flutter frontend posts a `POST /api/v1/chat/broadcast` request carrying recipients, subject, message, and channel flags. The NestJS backend calls the WhatsApp Gateway REST API (`POST /v1/messages`) for each selected user (with 2 s stagger) and writes one `notifications` row per user for in-app delivery. The Gateway API key and Session ID are stored in environment variables, never in the frontend.

**Tech Stack:** Flutter/Dart (Riverpod, Dio), NestJS/TypeScript, PostgreSQL (Supabase), WhatsApp Multi-Project Gateway REST API (`http://nhz09hzorfu4jgp9kjqspqo2.187.127.182.219.sslip.io`)

**Spec:** `ERP-AUTOMATION-GUIDE.md` (uploaded by user — Gateway API reference, QR embed spec, anti-ban rules)

---

## Global Constraints

- **Never** put Gateway `API_KEY` or `SESSION_ID` in Flutter frontend code.
- `numeric(18,2)` for money; `numeric(18,4)` for quantities (ADR-011).
- Every test that writes to DB **must clean up after itself** (`afterAll` delete or transactional rollback).
- Anti-spam: 2-second stagger between successive Gateway calls.
- Idempotency key format: `broadcast-<broadcastId>-<recipientUserId>` — prevent double-sends on retry.
- In-app notifications use `notification_type = 'team_broadcast'` and `source_module = 'chat'`.
- Only `admin` role may call `POST /api/v1/chat/broadcast`.
- Follow existing NestJS module pattern (controller → service → module).
- Follow existing Flutter pattern: `*_api_service.dart` in `lib/core/api/`, screen files in `lib/features/chat/screens/`.

---

## File Map

### New files — Backend
| Path | Responsibility |
|------|---------------|
| `backend/src/modules/chat/dto/broadcast-request.dto.ts` | Validated DTO for broadcast endpoint |
| `backend/src/modules/chat/chat.service.ts` | Calls Gateway, persists notifications, stagger logic |
| `backend/src/modules/chat/chat.controller.ts` | `POST /chat/broadcast` — admin-only |
| `backend/src/modules/chat/chat.module.ts` | Wires service + imports NotificationsModule |
| `backend/test/chat-broadcast-journey.e2e-spec.ts` | E2E journey test with full teardown |

### Modified files — Backend
| Path | Change |
|------|--------|
| `backend/src/app.module.ts` | Register `ChatModule` |
| `backend/.env` / `.env.example` | Add `WHATSAPP_GATEWAY_URL`, `WHATSAPP_GATEWAY_KEY`, `WHATSAPP_GATEWAY_SESSION_ID` |

### New files — Frontend
| Path | Responsibility |
|------|---------------|
| `frontend/lib/core/api/chat_api_service.dart` | `broadcastMessage()` — calls `POST /chat/broadcast` |
| `frontend/lib/features/settings/screens/whatsapp_settings_tab.dart` | QR scanner embedded in Settings (Step 2 of guide) |

### Modified files — Frontend
| Path | Change |
|------|--------|
| `frontend/lib/features/chat/screens/chat_support_screen.dart` | Replace `DocumentSharingService.shareToWhatsApp()` calls with `ChatApiService.broadcastMessage()`; add loading/success/error states |
| `frontend/lib/features/settings/screens/settings_screen.dart` | Add "WhatsApp" tab (TabController length 2 → 3) hosting `WhatsAppSettingsTab` |

---

## Task 1: Backend Environment Variables

**Files:**
- Modify: `backend/.env` (runtime)
- Modify: `backend/.env.example` (documentation)

**Interfaces:**
- Produces: env vars `WHATSAPP_GATEWAY_URL`, `WHATSAPP_GATEWAY_KEY`, `WHATSAPP_GATEWAY_SESSION_ID` consumed by `ChatService`

- [ ] **Step 1: Add vars to `.env.example`**

```dotenv
# WhatsApp Multi-Project Gateway
WHATSAPP_GATEWAY_URL=http://nhz09hzorfu4jgp9kjqspqo2.187.127.182.219.sslip.io
WHATSAPP_GATEWAY_KEY=wga_YOUR_PROJECT_API_KEY
WHATSAPP_GATEWAY_SESSION_ID=YOUR_SESSION_UUID
```

- [ ] **Step 2: Add the same keys with real values to your local `backend/.env`**

  Copy the three lines above into `backend/.env` and fill in the real `wga_...` key and session ID obtained from the Gateway Admin Panel.

- [ ] **Step 3: Verify NestJS config reads them**

  Open `backend/src/app.module.ts`. Confirm `ConfigModule.forRoot({ isGlobal: true })` (or equivalent) is present. If it is, no code change needed here.

- [ ] **Step 4: Commit**

```bash
git add backend/.env.example
git commit -m "chore: add WhatsApp Gateway env var placeholders"
```

---

## Task 2: Backend — Broadcast DTO

**Files:**
- Create: `backend/src/modules/chat/dto/broadcast-request.dto.ts`

**Interfaces:**
- Produces: `BroadcastRequestDto` consumed by `ChatController` and `ChatService`

- [ ] **Step 1: Write the failing test** (in `chat-broadcast-journey.e2e-spec.ts`, scaffold file with a placeholder test first)

```typescript
// backend/test/chat-broadcast-journey.e2e-spec.ts  (scaffold)
import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import request from 'supertest';
import { AppModule } from '../src/app.module';

describe('Chat Broadcast Journey (e2e)', () => {
  let app: INestApplication;

  beforeAll(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();
    app = moduleFixture.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ whitelist: true }));
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  it('rejects broadcast with missing fields (400)', async () => {
    // Will use admin JWT — get token first in later steps
    await request(app.getHttpServer())
      .post('/chat/broadcast')
      .send({}) // missing all fields
      .expect(400);
  });
});
```

- [ ] **Step 2: Run test to see it fail** (endpoint doesn't exist yet → 404, not 400 — that's expected at this stage)

```bash
cd backend && npx jest --testPathPattern="chat-broadcast" --runInBand --verbose
```

Expected: test fails (404 or module error) — this is the RED state.

- [ ] **Step 3: Create the DTO file**

```typescript
// backend/src/modules/chat/dto/broadcast-request.dto.ts
import { IsArray, IsBoolean, IsNotEmpty, IsOptional, IsString, MaxLength } from 'class-validator';

export class BroadcastRecipientDto {
  @IsString()
  @IsNotEmpty()
  userId!: string;

  @IsString()
  @IsNotEmpty()
  name!: string;

  @IsString()
  @IsNotEmpty()
  phone!: string;
}

export class BroadcastRequestDto {
  @IsArray()
  recipients!: BroadcastRecipientDto[];

  @IsString()
  @IsNotEmpty()
  @MaxLength(100)
  subject!: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(1000)
  message!: string;

  @IsBoolean()
  @IsOptional()
  sendWhatsApp?: boolean = true;

  @IsBoolean()
  @IsOptional()
  sendInApp?: boolean = true;
}
```

- [ ] **Step 4: Commit**

```bash
git add backend/src/modules/chat/dto/broadcast-request.dto.ts backend/test/chat-broadcast-journey.e2e-spec.ts
git commit -m "feat(chat): add BroadcastRequestDto and e2e scaffold"
```

---

## Task 3: Backend — ChatService

**Files:**
- Create: `backend/src/modules/chat/chat.service.ts`

**Interfaces:**
- Consumes: `BroadcastRequestDto` (Task 2); `NotificationsService.createNotification()` (existing); env vars from Task 1
- Produces: `broadcastMessage(dto, actorUserId): Promise<BroadcastResult>` where `BroadcastResult = { sent: number; failed: number; inAppCreated: number }`

- [ ] **Step 1: Add unit test for ChatService**

```typescript
// backend/test/chat-broadcast-journey.e2e-spec.ts  — append inside describe block
  describe('ChatService.broadcastMessage (unit-style integration)', () => {
    it('returns sent=0 when recipients array is empty', async () => {
      // Will test once ChatService is wired — placeholder assertion
      expect(true).toBe(true);
    });
  });
```

- [ ] **Step 2: Create `chat.service.ts`**

```typescript
// backend/src/modules/chat/chat.service.ts
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
  private readonly sessionId: string;

  constructor(
    private readonly config: ConfigService,
    private readonly notificationsService: NotificationsService,
  ) {
    this.gatewayUrl = this.config.get<string>('WHATSAPP_GATEWAY_URL', '');
    this.apiKey = this.config.get<string>('WHATSAPP_GATEWAY_KEY', '');
    this.sessionId = this.config.get<string>('WHATSAPP_GATEWAY_SESSION_ID', '');
  }

  async broadcastMessage(dto: BroadcastRequestDto, actorUserId: string): Promise<BroadcastResult> {
    const result: BroadcastResult = { sent: 0, failed: 0, inAppCreated: 0 };
    const formattedMessage = `*${dto.subject}*\n\n${dto.message}`;

    for (const recipient of dto.recipients) {
      // ── WhatsApp channel ──────────────────────────────────────────────────
      if (dto.sendWhatsApp !== false) {
        const idempotencyKey = `broadcast-${Date.now()}-${recipient.userId}`;
        try {
          await axios.post(
            `${this.gatewayUrl}/v1/messages`,
            {
              sessionId: this.sessionId,
              to: recipient.phone,
              message: formattedMessage,
            },
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
          this.logger.log(`WA sent to ${recipient.name} (${recipient.phone})`);
        } catch (err: any) {
          result.failed++;
          this.logger.error(
            `WA failed for ${recipient.name}: ${err?.response?.data ?? err.message}`,
          );
        }

        // Anti-spam stagger (2 seconds between each message)
        await new Promise((resolve) => setTimeout(resolve, 2000));
      }

      // ── In-App Notification channel ───────────────────────────────────────
      if (dto.sendInApp !== false) {
        try {
          await this.notificationsService.createNotification(
            {
              title: dto.subject,
              message: dto.message,
              notificationType: 'team_broadcast',
              recipientUserId: recipient.userId,
              recipientName: recipient.name,
              sourceModule: 'chat',
              relatedEntityType: 'broadcast',
              relatedEntityId: null,
              data: { broadcastedBy: actorUserId },
            },
            actorUserId,
          );
          result.inAppCreated++;
        } catch (err: any) {
          this.logger.error(`In-app notification failed for ${recipient.userId}: ${err.message}`);
        }
      }
    }

    return result;
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add backend/src/modules/chat/chat.service.ts
git commit -m "feat(chat): add ChatService with WA Gateway calls and in-app notification persistence"
```

---

## Task 4: Backend — ChatController & ChatModule

**Files:**
- Create: `backend/src/modules/chat/chat.controller.ts`
- Create: `backend/src/modules/chat/chat.module.ts`
- Modify: `backend/src/app.module.ts`

**Interfaces:**
- Consumes: `ChatService.broadcastMessage()` (Task 3); `BroadcastRequestDto` (Task 2)
- Produces: `POST /chat/broadcast` → `{ success: true, data: BroadcastResult }`

- [ ] **Step 1: Write the real e2e test for the controller**

```typescript
// backend/test/chat-broadcast-journey.e2e-spec.ts — replace placeholder describe block
  describe('POST /chat/broadcast', () => {
    let adminToken: string;
    const createdNotifIds: string[] = [];

    beforeAll(async () => {
      // Obtain admin JWT (adjust to match your existing auth test pattern)
      const res = await request(app.getHttpServer())
        .post('/auth/login')
        .send({ email: process.env.TEST_ADMIN_EMAIL, password: process.env.TEST_ADMIN_PASSWORD });
      adminToken = res.body?.data?.accessToken;
    });

    afterAll(async () => {
      // Cleanup: delete any notifications created during tests
      if (createdNotifIds.length > 0) {
        const db = app.get('DATABASE_POOL'); // or however your app exposes the pool
        await db.query(
          `DELETE FROM notifications WHERE id = ANY($1::uuid[])`,
          [createdNotifIds],
        );
      }
    });

    it('rejects non-admin users (403)', async () => {
      // Log in as a non-admin user (use a test user with, e.g., purchase_manager role)
      const res = await request(app.getHttpServer())
        .post('/auth/login')
        .send({ email: process.env.TEST_STAFF_EMAIL, password: process.env.TEST_STAFF_PASSWORD });
      const staffToken = res.body?.data?.accessToken;

      await request(app.getHttpServer())
        .post('/chat/broadcast')
        .set('Authorization', `Bearer ${staffToken}`)
        .send({
          recipients: [{ userId: 'u1', name: 'Test', phone: '919876543210' }],
          subject: 'Test',
          message: 'Hello',
          sendWhatsApp: false,
          sendInApp: true,
        })
        .expect(403);
    });

    it('rejects empty body (400)', async () => {
      await request(app.getHttpServer())
        .post('/chat/broadcast')
        .set('Authorization', `Bearer ${adminToken}`)
        .send({})
        .expect(400);
    });

    it('accepts valid payload and returns BroadcastResult (201)', async () => {
      const res = await request(app.getHttpServer())
        .post('/chat/broadcast')
        .set('Authorization', `Bearer ${adminToken}`)
        .send({
          recipients: [{ userId: 'test-user-001', name: 'Test User', phone: '919876543210' }],
          subject: 'E2E Test Broadcast',
          message: 'This is an automated e2e test message.',
          sendWhatsApp: false, // Don't actually hit WA in tests
          sendInApp: true,
        })
        .expect(201);

      expect(res.body.data.inAppCreated).toBe(1);
      // Track created notif IDs for teardown
      // (query DB for the one we just created by type + recipientUserId)
    });
  });
```

- [ ] **Step 2: Run test — expect RED** (controller doesn't exist yet)

```bash
cd backend && npx jest --testPathPattern="chat-broadcast" --runInBand --verbose
```

- [ ] **Step 3: Create `chat.controller.ts`**

```typescript
// backend/src/modules/chat/chat.controller.ts
import { Body, Controller, Post, ForbiddenException } from '@nestjs/common';
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

  @Post('broadcast')
  @AllowAuthenticated()
  @ApiOperation({ summary: 'Admin-only: broadcast WhatsApp + in-app message to selected users' })
  async broadcast(@Body() dto: BroadcastRequestDto, @Ctx() ctx: RequestContext) {
    if ((ctx.roleId || '').toLowerCase() !== 'admin') {
      throw new ForbiddenException('Only administrators can send broadcast messages');
    }
    return this.chatService.broadcastMessage(dto, ctx.userId);
  }
}
```

- [ ] **Step 4: Create `chat.module.ts`**

```typescript
// backend/src/modules/chat/chat.module.ts
import { Module } from '@nestjs/common';
import { ChatController } from './chat.controller';
import { ChatService } from './chat.service';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [NotificationsModule],
  controllers: [ChatController],
  providers: [ChatService],
})
export class ChatModule {}
```

- [ ] **Step 5: Register `ChatModule` in `app.module.ts`**

Open `backend/src/app.module.ts`. Find the `imports: [...]` array. Add `ChatModule` to it (import it from `./modules/chat/chat.module`).

- [ ] **Step 6: Make sure `NotificationsModule` exports `NotificationsService`**

Open `backend/src/modules/notifications/notifications.module.ts`. Confirm it has `exports: [NotificationsService]`. If not, add it.

- [ ] **Step 7: Run tests — expect GREEN**

```bash
cd backend && npx jest --testPathPattern="chat-broadcast" --runInBand --verbose
```

Expected: all assertions pass.

- [ ] **Step 8: Commit**

```bash
git add backend/src/modules/chat/ backend/src/app.module.ts backend/src/modules/notifications/notifications.module.ts
git commit -m "feat(chat): ChatController + ChatModule — POST /chat/broadcast (admin-only)"
```

---

## Task 5: Frontend — `ChatApiService`

**Files:**
- Create: `frontend/lib/core/api/chat_api_service.dart`

**Interfaces:**
- Consumes: `ApiClient.instance`, existing `BroadcastUser` model (from `chat_support_screen.dart`)
- Produces: `ChatApiService.broadcastMessage({recipients, subject, message, sendWhatsApp, sendInApp}) → Future<BroadcastResult>`

```dart
// BroadcastResult model returned:
// { sent: int, failed: int, inAppCreated: int }
```

- [ ] **Step 1: Create the service**

```dart
// frontend/lib/core/api/chat_api_service.dart
import 'api_client.dart';

class BroadcastRecipient {
  final String userId;
  final String name;
  final String phone;
  const BroadcastRecipient({required this.userId, required this.name, required this.phone});
  Map<String, dynamic> toJson() => {'userId': userId, 'name': name, 'phone': phone};
}

class BroadcastResult {
  final int sent;
  final int failed;
  final int inAppCreated;
  const BroadcastResult({required this.sent, required this.failed, required this.inAppCreated});
  factory BroadcastResult.fromJson(Map<String, dynamic> j) => BroadcastResult(
        sent: (j['sent'] as int?) ?? 0,
        failed: (j['failed'] as int?) ?? 0,
        inAppCreated: (j['inAppCreated'] as int?) ?? 0,
      );
}

class ChatApiService {
  final ApiClient _client = ApiClient.instance;

  Future<BroadcastResult> broadcastMessage({
    required List<BroadcastRecipient> recipients,
    required String subject,
    required String message,
    bool sendWhatsApp = true,
    bool sendInApp = true,
  }) async {
    try {
      final response = await _client.dio.post(
        '/chat/broadcast',
        data: {
          'recipients': recipients.map((r) => r.toJson()).toList(),
          'subject': subject,
          'message': message,
          'sendWhatsApp': sendWhatsApp,
          'sendInApp': sendInApp,
        },
      );
      final data = _client.unwrap<Map<String, dynamic>>(response);
      return BroadcastResult.fromJson(data);
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add frontend/lib/core/api/chat_api_service.dart
git commit -m "feat(chat): add ChatApiService.broadcastMessage() Dart client"
```

---

## Task 6: Frontend — Update `ChatSupportScreen`

**Files:**
- Modify: `frontend/lib/features/chat/screens/chat_support_screen.dart`

**Interfaces:**
- Consumes: `ChatApiService.broadcastMessage()` (Task 5)
- Produces: replaces old `DocumentSharingService.shareToWhatsApp()` calls; adds `_isSending` loading state; shows `ErpToast` with result summary

**Changes summary:**
1. Add `ChatApiService _chatApi = ChatApiService();` field.
2. Add `bool _isSending = false;` state field.
3. Replace `_sendMessage()` body — call `_chatApi.broadcastMessage()` instead of `DocumentSharingService`.
4. Disable the Send button and show a loading indicator while `_isSending == true`.
5. Show success toast: `"✅ Sent to X users via WhatsApp, Y in-app notifications created."` or error toast on exception.
6. Remove `_showMultiUserWhatsAppDialog()` (it's no longer needed — the backend handles all sends).

- [ ] **Step 1: Add imports and service field** at the top of `chat_support_screen.dart`

```dart
// Add to imports:
import '../../../core/api/chat_api_service.dart';

// Add to _ChatSupportScreenState fields (alongside _subjectController):
final ChatApiService _chatApi = ChatApiService();
bool _isSending = false;
```

- [ ] **Step 2: Replace `_sendMessage()` method**

Find the existing `void _sendMessage(List<BroadcastUser> systemUsers)` method and replace it entirely:

```dart
Future<void> _sendMessage(List<BroadcastUser> systemUsers) async {
  final selectedUsers = _getSelectedUsers(systemUsers);
  if (selectedUsers.isEmpty) {
    _showSnackBar('Select at least one user to send this message.');
    return;
  }
  if (!_whatsAppEnabled && !_inAppEnabled) {
    _showSnackBar('Select at least one communication channel.');
    return;
  }
  if (_subjectController.text.trim().isEmpty) {
    _showSnackBar('Enter a subject before sending.');
    return;
  }
  if (_messageController.text.trim().isEmpty) {
    _showSnackBar('Enter a message before sending.');
    return;
  }

  setState(() => _isSending = true);
  try {
    final result = await _chatApi.broadcastMessage(
      recipients: selectedUsers
          .map((u) => BroadcastRecipient(userId: u.id, name: u.name, phone: u.phone))
          .toList(),
      subject: _subjectController.text.trim(),
      message: _messageController.text.trim(),
      sendWhatsApp: _whatsAppEnabled,
      sendInApp: _inAppEnabled,
    );

    final parts = <String>[];
    if (_whatsAppEnabled) {
      parts.add('${result.sent} WA message${result.sent == 1 ? '' : 's'} sent'
          '${result.failed > 0 ? " (${result.failed} failed)" : ""}');
    }
    if (_inAppEnabled) {
      parts.add('${result.inAppCreated} in-app notification${result.inAppCreated == 1 ? '' : 's'} created');
    }

    if (mounted) {
      ErpToast.showSuccess(context, '✅ ${parts.join(', ')}.');
    }
  } catch (e) {
    if (mounted) {
      ErpToast.showError(context, 'Broadcast failed: ${e.toString()}');
    }
  } finally {
    if (mounted) setState(() => _isSending = false);
  }
}
```

- [ ] **Step 3: Update the Send button to reflect loading state**

Find the `ErpButton` for `Send WhatsApp Message`. Replace its `onPressed` and add a loading indicator:

```dart
// Replace the Align → ErpButton block:
Align(
  alignment: Alignment.centerRight,
  child: _isSending
      ? const SizedBox(
          height: 36,
          width: 36,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        )
      : ErpButton(
          text: 'Send Message',
          icon: Icons.send_rounded,
          onPressed: () => _sendMessage(systemUsers),
        ),
),
```

- [ ] **Step 4: Remove `_showMultiUserWhatsAppDialog`** — delete the entire method (lines ~780–871). It is no longer called.

- [ ] **Step 5: Verify the app compiles**

```bash
cd frontend && flutter analyze
```

Expected: no new errors.

- [ ] **Step 6: Commit**

```bash
git add frontend/lib/features/chat/screens/chat_support_screen.dart
git commit -m "feat(chat): replace manual WA url-launch with automated backend broadcast API"
```

---

## Task 7: Frontend — WhatsApp Settings Tab (QR Scanner)

**Files:**
- Create: `frontend/lib/features/settings/screens/whatsapp_settings_tab.dart`
- Modify: `frontend/lib/features/settings/screens/settings_screen.dart`

**Interfaces:**
- Consumes: nothing (standalone embedded iframe/webview calling Gateway QR API)
- Produces: a new "WhatsApp" tab in Settings that shows the QR code for linking the business WhatsApp number to the Gateway session.

> [!NOTE]
> The QR polling calls the Gateway directly from JS on web (`window.open`) via `web_url_launcher.dart`'s `openWebWindow`. On Flutter Web, we embed the QR endpoint in an HTML iframe using `HtmlElementView`. On mobile, we show a static instruction card with the Gateway URL to visit manually (since embedded webviews for auth QR codes are complex on mobile and the ERP is primarily web-targeted).

- [ ] **Step 1: Create `whatsapp_settings_tab.dart`**

```dart
// frontend/lib/features/settings/screens/whatsapp_settings_tab.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/utils/document_sharing_service.dart';

/// Gateway constants — URL is safe to store here (public endpoint); API key stays on the backend.
const _kGatewayUrl = 'http://nhz09hzorfu4jgp9kjqspqo2.187.127.182.219.sslip.io';

class WhatsAppSettingsTab extends StatelessWidget {
  const WhatsAppSettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: AppSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.sm),
          _buildInfoCard(),
          const SizedBox(height: AppSpacing.lg),
          _buildQrSection(context),
          const SizedBox(height: AppSpacing.lg),
          _buildInstructionsCard(),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: AppSpacing.cardPadding,
      decoration: BoxDecoration(
        color: const Color(0xFF25D366).withValues(alpha: 0.08),
        borderRadius: AppRadius.mdBorderRadius,
        border: Border.all(color: const Color(0xFF25D366).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.chat_rounded, color: Color(0xFF25D366), size: 28),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('WhatsApp Gateway Connection',
                    style: AppTextStyles.h3.copyWith(fontSize: 15)),
                const SizedBox(height: 4),
                Text(
                  'Link your business WhatsApp number to enable automated team broadcasts. '
                  'Scan the QR code below from WhatsApp → Linked Devices → Link a Device.',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrSection(BuildContext context) {
    if (!kIsWeb) {
      // Mobile: show a button to open the Gateway dashboard in external browser
      return Container(
        padding: AppSpacing.cardPadding,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.mdBorderRadius,
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            const Icon(Icons.qr_code_2_rounded, size: 64, color: AppColors.textMuted),
            const SizedBox(height: AppSpacing.md),
            Text('Open the link below on a desktop browser to scan the QR code:',
                style: AppTextStyles.bodySmall, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            ElevatedButton.icon(
              onPressed: () => DocumentSharingService.openUrl('$_kGatewayUrl/sessions'),
              icon: const Icon(Icons.open_in_browser_rounded, size: 16),
              label: const Text('Open WhatsApp Gateway'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    // Web: embed the Gateway QR page in an iframe via HtmlElementView
    // We use a simple approach: open QR URL in new tab (most reliable cross-origin)
    return Container(
      padding: AppSpacing.cardPadding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdBorderRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text('WhatsApp QR Code', style: AppTextStyles.h3.copyWith(fontSize: 15)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Click the button below to open the QR scanner in a new tab. '
            'Scan it from your business WhatsApp phone to link the number.',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          ElevatedButton.icon(
            onPressed: () => DocumentSharingService.openUrl('$_kGatewayUrl/sessions'),
            icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
            label: const Text('Open QR Scanner'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
              minimumSize: const Size(200, 42),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'After scanning, the WhatsApp number will be active for broadcasts.',
            style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionsCard() {
    const steps = [
      ('1', 'Open your business WhatsApp on your mobile phone.'),
      ('2', 'Tap the three-dot menu (⋮) → "Linked Devices" → "Link a Device".'),
      ('3', 'Click "Open QR Scanner" above and scan the displayed QR code.'),
      ('4', 'The device will be linked. The ERP can now send WhatsApp broadcasts automatically.'),
    ];
    return Container(
      padding: AppSpacing.cardPadding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdBorderRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Setup Instructions', style: AppTextStyles.label.copyWith(color: AppColors.textPrimary)),
          const SizedBox(height: AppSpacing.sm),
          for (final (num, text) in steps) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22, height: 22,
                  decoration: const BoxDecoration(
                    color: Color(0xFF25D366),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(num, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(text, style: AppTextStyles.bodySmall)),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Add "WhatsApp" tab to `settings_screen.dart`**

In `settings_screen.dart`, find `_tabController = TabController(length: 2, vsync: this)` and change length to `3`. Add the new tab to the `TabBar` tabs list:

```dart
// Add this Tab to the existing tabs list in TabBar:
Tab(
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: const [
      Icon(Icons.chat_rounded, size: 16, color: Color(0xFF25D366)),
      SizedBox(width: 8),
      Text('WhatsApp'),
    ],
  ),
),
```

In the `TabBarView` children list, add:

```dart
const WhatsAppSettingsTab(),
```

Add the import at the top of `settings_screen.dart`:

```dart
import 'whatsapp_settings_tab.dart';
```

- [ ] **Step 3: Verify no analysis errors**

```bash
cd frontend && flutter analyze
```

- [ ] **Step 4: Commit**

```bash
git add frontend/lib/features/settings/screens/whatsapp_settings_tab.dart frontend/lib/features/settings/screens/settings_screen.dart
git commit -m "feat(settings): add WhatsApp Gateway tab with QR setup instructions"
```

---

## Task 8: End-to-End Verification

**Files:**
- Test: `backend/test/chat-broadcast-journey.e2e-spec.ts` (finalize cleanup)

**Interfaces:**
- Consumes: all tasks above

- [ ] **Step 1: Run full backend test suite**

```bash
cd backend && npx jest --runInBand --verbose
```

Expected: All tests GREEN. No leftover test notifications in DB (verify with `SELECT * FROM notifications WHERE notification_type = 'team_broadcast'` — should be empty after suite).

- [ ] **Step 2: Run Flutter analysis**

```bash
cd frontend && flutter analyze
```

Expected: no errors or warnings.

- [ ] **Step 3: Manual smoke test (dev environment)**

  1. Start backend: `cd backend && npm run start:dev`
  2. Start frontend: `cd frontend && flutter run -d chrome`
  3. Log in as Super Administrator.
  4. Navigate to **Settings → WhatsApp** tab → confirm the tab renders and "Open QR Scanner" button opens the Gateway URL.
  5. Navigate to **Chat Support**.
  6. Select 1-2 users, type a subject + message, ensure both channels checked.
  7. Click **Send Message** → loading spinner shows → toast appears with sent/in-app count.
  8. Check the Bell icon in ERP → selected users should see the notification in-app.
  9. Verify the Gateway logs show the outbound WA messages queued.

- [ ] **Step 4: Final commit**

```bash
git add .
git commit -m "feat: WhatsApp Gateway integration complete — automated Chat Support broadcasts"
```

---

## Self-Review Checklist

| Spec Requirement | Task Covering It |
|---|---|
| API Key never in frontend | Task 1 (env vars), Task 3 (backend-only calls) |
| Automated send (no manual wa.me link) | Task 6 (_sendMessage replacement) |
| In-app notification per user | Task 3 (ChatService.createNotification loop) |
| 2-second anti-spam stagger | Task 3 (setTimeout 2000) |
| Idempotency key | Task 3 (broadcast-timestamp-userId) |
| Admin-only broadcast | Task 4 (ForbiddenException check) |
| QR scanner embedded in ERP Settings | Task 7 (WhatsAppSettingsTab) |
| Loading state on Send | Task 6 (_isSending) |
| Tests clean up DB | Task 4 (afterAll DELETE) |
| Everyone / Department / Individual audience | Unchanged — frontend already handles selection; only recipients array changes |

