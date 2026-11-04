import { ForbiddenException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { ChatController } from './chat.controller';
import { ChatService } from './chat.service';
import { RequestContext } from '../../core/auth/request-context';

describe('ChatController', () => {
  let controller: ChatController;
  let mockChatService: Partial<ChatService>;

  beforeEach(async () => {
    mockChatService = {
      broadcastMessage: jest.fn().mockResolvedValue({ sent: 1, failed: 0, inAppCreated: 1 }),
      getSessionStatus: jest.fn().mockResolvedValue({ status: 'connected' } as any),
      connectSession: jest.fn().mockResolvedValue({ status: 'connecting' } as any),
      getSessionQr: jest.fn().mockResolvedValue({ qrDataUrl: null } as any),
      disconnectSession: jest.fn().mockResolvedValue({ success: true }),
    };

    const module: TestingModule = await Test.createTestingModule({
      controllers: [ChatController],
      providers: [{ provide: ChatService, useValue: mockChatService }],
    }).compile();

    controller = module.get<ChatController>(ChatController);
  });

  describe('broadcast', () => {
    const adminCtx: RequestContext = {
      userId: 'user-admin',
      userName: 'Admin',
      roleId: 'admin',
      branchIds: [],
      stockLocationIds: [],
      permissions: new Set(),
      correlationId: 'test-cid',
    };

    const staffCtx: RequestContext = {
      userId: 'user-staff',
      userName: 'Staff',
      roleId: 'purchase_manager',
      branchIds: [],
      stockLocationIds: [],
      permissions: new Set(),
      correlationId: 'test-cid',
    };

    const testDto = {
      recipients: [{ userId: 'user-1', name: 'User One', phone: '9876543210' }],
      subject: 'Notice',
      message: 'Hello team',
    };

    it('Positive: allows admin user to broadcast', async () => {
      const res = await controller.broadcast(testDto, adminCtx);
      expect(res).toEqual({ sent: 1, failed: 0, inAppCreated: 1 });
      expect(mockChatService.broadcastMessage).toHaveBeenCalledWith(testDto, 'user-admin');
    });

    it('Negative: rejects non-admin user with ForbiddenException', async () => {
      await expect(controller.broadcast(testDto, staffCtx)).rejects.toThrow(ForbiddenException);
    });

    it('Negative: rejects undefined ctx or missing roleId safely without 500 crash', async () => {
      await expect(controller.broadcast(testDto, undefined as any)).rejects.toThrow(ForbiddenException);
    });
  });
});

