import 'api_client.dart';

class BroadcastRecipient {
  final String userId;
  final String name;
  final String phone;
  const BroadcastRecipient({
    required this.userId,
    required this.name,
    required this.phone,
  });
  Map<String, dynamic> toJson() => {
        'userId': userId,
        'name': name,
        'phone': phone,
      };
}

class BroadcastResult {
  final int sent;
  final int failed;
  final int inAppCreated;
  const BroadcastResult({
    required this.sent,
    required this.failed,
    required this.inAppCreated,
  });
  factory BroadcastResult.fromJson(Map<String, dynamic> j) => BroadcastResult(
        sent: (j['sent'] as int?) ?? 0,
        failed: (j['failed'] as int?) ?? 0,
        inAppCreated: (j['inAppCreated'] as int?) ?? 0,
      );
}

class WhatsAppSessionStatus {
  final String sessionId;
  final String status;
  final String? phoneNumber;
  final String? qrDataUrl;
  final String? message;

  const WhatsAppSessionStatus({
    required this.sessionId,
    required this.status,
    this.phoneNumber,
    this.qrDataUrl,
    this.message,
  });

  factory WhatsAppSessionStatus.fromJson(Map<String, dynamic> j) =>
      WhatsAppSessionStatus(
        sessionId: (j['sessionId'] as String?) ?? '',
        status: (j['status'] as String?) ?? 'disconnected',
        phoneNumber: j['phoneNumber'] as String?,
        qrDataUrl: j['qrDataUrl'] as String?,
        message: j['message'] as String?,
      );
}

class ChatApiService {
  final ApiClient _client = ApiClient.instance;

  Future<WhatsAppSessionStatus> getSessionStatus() async {
    try {
      final response = await _client.dio.get('/chat/session/status');
      final data = _client.unwrap<Map<String, dynamic>>(response);
      return WhatsAppSessionStatus.fromJson(data);
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  Future<WhatsAppSessionStatus> connectSession() async {
    try {
      final response = await _client.dio.post('/chat/session/connect');
      final data = _client.unwrap<Map<String, dynamic>>(response);
      return WhatsAppSessionStatus.fromJson(data);
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  Future<WhatsAppSessionStatus> getSessionQr() async {
    try {
      final response = await _client.dio.get('/chat/session/qr');
      final data = _client.unwrap<Map<String, dynamic>>(response);
      return WhatsAppSessionStatus.fromJson(data);
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  Future<bool> disconnectSession() async {
    try {
      final response = await _client.dio.post('/chat/session/disconnect');
      final data = _client.unwrap<Map<String, dynamic>>(response);
      return (data['success'] as bool?) ?? true;
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

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
