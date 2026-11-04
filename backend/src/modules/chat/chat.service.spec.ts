import { Test, TestingModule } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import axios from 'axios';
import { ChatService } from './chat.service';
import { NotificationsService } from '../notifications/notifications.service';

jest.mock('axios');
const mockedAxios = axios as jest.Mocked<typeof axios>;

describe('ChatService', () => {
  let service: ChatService;
  let mockNotificationsService: Partial<NotificationsService>;
  let mockConfigService: Partial<ConfigService>;

  beforeEach(async () => {
    jest.clearAllMocks();

    mockConfigService = {
      get: jest.fn((key: string, defaultValue?: any) => {
        if (key === 'WHATSAPP_GATEWAY_URL') return 'http://test-gateway.com';
        if (key === 'WHATSAPP_GATEWAY_KEY') return 'test-key';
        if (key === 'WHATSAPP_GATEWAY_SESSION_ID') return 'test-session';
        if (key === 'WHATSAPP_MIN_DELAY_MS') return 0;
        if (key === 'WHATSAPP_MAX_DELAY_MS') return 0;
        return defaultValue;
      }),
    };

    mockNotificationsService = {
      createNotification: jest.fn().mockResolvedValue({ id: 'notif-1' } as any),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        ChatService,
        { provide: ConfigService, useValue: mockConfigService },
        { provide: NotificationsService, useValue: mockNotificationsService },
      ],
    }).compile();

    service = module.get<ChatService>(ChatService);
  });

  describe('broadcastMessage Resilience', () => {
    it('Positive: sends WhatsApp and In-App messages successfully', async () => {
      mockedAxios.post.mockResolvedValueOnce({ data: { success: true } });

      const result = await service.broadcastMessage(
        {
          recipients: [
            { userId: '00000000-0000-0000-0000-000000000001', name: 'John Doe', phone: '9876543210' },
          ],
          subject: 'Team Update',
          message: 'Hello team',
          sendWhatsApp: true,
          sendInApp: true,
        },
        '00000000-0000-0000-0000-000000000000',
      );

      expect(result.sent).toBe(1);
      expect(result.failed).toBe(0);
      expect(result.inAppCreated).toBe(1);
      expect(mockedAxios.post).toHaveBeenCalledTimes(1);
    });

    it('Negative: handles WhatsApp gateway network error gracefully without throwing', async () => {
      mockedAxios.post.mockRejectedValueOnce(new Error('Gateway connection timeout'));

      const result = await service.broadcastMessage(
        {
          recipients: [
            { userId: '00000000-0000-0000-0000-000000000001', name: 'John Doe', phone: '9876543210' },
          ],
          subject: 'Team Update',
          message: 'Hello team',
          sendWhatsApp: true,
          sendInApp: false,
        },
        '00000000-0000-0000-0000-000000000000',
      );

      expect(result.sent).toBe(0);
      expect(result.failed).toBe(1);
      expect(result.inAppCreated).toBe(0);
    });

    it('Edge case: handles null, undefined, or empty phone numbers without crashing', async () => {
      const result = await service.broadcastMessage(
        {
          recipients: [
            { userId: '00000000-0000-0000-0000-000000000001', name: 'No Phone User', phone: '' as any },
            { userId: '00000000-0000-0000-0000-000000000002', name: 'Undefined Phone', phone: undefined as any },
            { userId: '00000000-0000-0000-0000-000000000003', name: 'Null Phone', phone: null as any },
          ],
          subject: 'Alert',
          message: 'Check phone status',
          sendWhatsApp: true,
          sendInApp: false,
        },
        '00000000-0000-0000-0000-000000000000',
      );

      expect(result.sent).toBe(0);
      expect(result.failed).toBe(3);
    });

    it('Edge case: handles malformed DTO or empty recipients without crashing', async () => {
      const result = await service.broadcastMessage(
        {
          recipients: [] as any,
          subject: 'Empty test',
          message: 'No recipients',
        },
        'actor-id',
      );

      expect(result.sent).toBe(0);
      expect(result.failed).toBe(0);
      expect(result.inAppCreated).toBe(0);
    });
  });
});

