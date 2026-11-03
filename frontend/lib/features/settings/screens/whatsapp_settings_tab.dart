import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/api/chat_api_service.dart';
import '../../../core/widgets/erp_toast.dart';

class WhatsAppSettingsTab extends StatefulWidget {
  const WhatsAppSettingsTab({super.key});

  @override
  State<WhatsAppSettingsTab> createState() => _WhatsAppSettingsTabState();
}

class _WhatsAppSettingsTabState extends State<WhatsAppSettingsTab> {
  final ChatApiService _chatApi = ChatApiService();

  bool _isLoading = true;
  bool _isConnecting = false;
  bool _isQrExpired = false;
  String _status = 'disconnected';
  String _sessionId = '';
  String? _phoneNumber;
  String? _qrDataUrl;
  Timer? _pollTimer;
  int _pollAttempts = 0;
  int _consecutiveErrors = 0;

  @override
  void initState() {
    super.initState();
    _fetchInitialStatus();
  }

  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _pollAttempts = 0;
    _consecutiveErrors = 0;
  }

  Future<void> _fetchInitialStatus() async {
    setState(() => _isLoading = true);
    try {
      final res = await _chatApi.getSessionStatus();
      if (!mounted) return;
      setState(() {
        _status = res.status;
        _sessionId = res.sessionId;
        _phoneNumber = res.phoneNumber;
        // If the gateway already has an active QR ready to scan, surface it
        if (res.status == 'qr_ready' && res.qrDataUrl != null) {
          _qrDataUrl = res.qrDataUrl;
        }
        _isLoading = false;
      });

      // If qr_ready, start polling with safety cap
      if (res.status == 'qr_ready') {
        _stopPolling();
        _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _checkConnectionStatus());
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _startConnection() async {
    _stopPolling();
    setState(() {
      _isConnecting = true;
      _qrDataUrl = null;
      _isQrExpired = false;
    });

    try {
      // Step 1: Force fresh QR from gateway
      final res = await _chatApi.connectSession();
      if (!mounted) return;
      setState(() {
        _sessionId = res.sessionId;
        _status = res.status;
        _qrDataUrl = res.qrDataUrl;
        _phoneNumber = res.phoneNumber;
        _isConnecting = false;
      });

      if (res.status == 'connected') {
        ErpToast.showSuccess(context, '🎉 WhatsApp is already connected!');
        return;
      }

      // Step 2: Poll ONLY connection status (max 30 attempts = 2 minutes)
      _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _checkConnectionStatus());
    } catch (e) {
      if (!mounted) return;
      setState(() => _isConnecting = false);
      ErpToast.showError(context, 'Failed to initialize session: $e');
    }
  }

  /// Polls ONLY for status change (connected/disconnected).
  /// Enforces a 2-minute safety timeout and aborts on 3 consecutive errors (e.g. 401).
  Future<void> _checkConnectionStatus() async {
    _pollAttempts++;
    if (_pollAttempts > 30) {
      _stopPolling();
      if (mounted) {
        setState(() {
          _isQrExpired = true;
          _isConnecting = false;
        });
        ErpToast.showInfo(context, 'QR code pairing timed out. Click Refresh to get a new code.');
      }
      return;
    }

    try {
      final res = await _chatApi.getSessionStatus();
      if (!mounted) return;
      _consecutiveErrors = 0; // reset on valid response

      // If QR was initially missing or pending, display it
      if ((_qrDataUrl == null || _qrDataUrl!.isEmpty) && res.qrDataUrl != null && res.qrDataUrl!.isNotEmpty) {
        setState(() {
          _qrDataUrl = res.qrDataUrl;
          _sessionId = res.sessionId;
        });
      }

      if (res.status == 'connected') {
        _stopPolling();
        setState(() {
          _status = 'connected';
          _sessionId = res.sessionId;
          _phoneNumber = res.phoneNumber ?? _phoneNumber;
          _isConnecting = false;
          _qrDataUrl = null;
          _isQrExpired = false;
        });
        ErpToast.showSuccess(context, '🎉 WhatsApp successfully connected!');
      }
    } catch (e) {
      _consecutiveErrors++;
      // Stop polling on 3 consecutive failures (prevents 401 spam on expired auth)
      if (_consecutiveErrors >= 3) {
        _stopPolling();
        if (mounted) {
          setState(() => _isConnecting = false);
        }
      }
    }
  }

  /// Re-links WhatsApp: fully unlinks existing device and generates fresh QR
  Future<void> _relink() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Re-link WhatsApp Number?'),
        content: const Text(
          'This will disconnect the currently linked WhatsApp phone and purge credentials so you can scan and pair a new phone number.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Proceed to Re-link'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    _stopPolling();
    setState(() {
      _isLoading = true;
      _qrDataUrl = null;
    });

    try {
      // 1. Purge credentials on Gateway so old phone cannot auto-reconnect
      await _chatApi.disconnectSession();
      if (!mounted) return;
      setState(() {
        _status = 'disconnected';
        _phoneNumber = null;
        _isLoading = false;
      });
      // 2. Immediately start pairing to generate a fresh QR
      await _startConnection();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ErpToast.showError(context, 'Failed to re-link: $e');
    }
  }

  Future<void> _disconnect() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disconnect WhatsApp?'),
        content: const Text(
          'Are you sure you want to disconnect this WhatsApp number? This will purge all credentials and stop automated messages.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      _stopPolling();
      await _chatApi.disconnectSession();
      if (!mounted) return;
      ErpToast.showInfo(context, 'WhatsApp number disconnected and purged.');
      await _fetchInitialStatus();
    } catch (e) {
      if (!mounted) return;
      ErpToast.showError(context, 'Failed to disconnect: $e');
      setState(() => _isLoading = false);
    }
  }

  void _copySessionId() {
    if (_sessionId.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _sessionId));
    ErpToast.showSuccess(context, 'Session ID copied to clipboard!');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return SingleChildScrollView(
      padding: AppSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.sm),
          _buildStatusHeaderCard(),
          const SizedBox(height: AppSpacing.lg),
          _buildQrCard(),
          const SizedBox(height: AppSpacing.lg),
          _buildInstructionsCard(),
        ],
      ),
    );
  }

  Widget _buildStatusHeaderCard() {
    final isConnected = _status == 'connected';

    return Container(
      padding: AppSpacing.cardPadding,
      decoration: BoxDecoration(
        color: isConnected
            ? const Color(0xFF25D366).withValues(alpha: 0.08)
            : AppColors.surface,
        borderRadius: AppRadius.mdBorderRadius,
        border: Border.all(
          color: isConnected
              ? const Color(0xFF25D366).withValues(alpha: 0.35)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isConnected
                      ? const Color(0xFF25D366)
                      : AppColors.textDisabled,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isConnected ? Icons.check_circle_rounded : Icons.chat_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'WhatsApp Multi-Project Gateway',
                          style: AppTextStyles.h3.copyWith(fontSize: 16),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isConnected
                                ? const Color(0xFFDCFCE7)
                                : const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isConnected ? 'CONNECTED' : 'DISCONNECTED',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isConnected
                                  ? const Color(0xFF15803D)
                                  : const Color(0xFFB91C1C),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isConnected
                          ? 'Automated team broadcast and messaging is active.'
                          : 'Connect your business WhatsApp number to enable automated broadcasts.',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_sessionId.isNotEmpty) ...[
            const Divider(height: 24, color: AppColors.borderLight),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ACTIVE GATEWAY SESSION ID',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textMuted,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        _sessionId,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (_phoneNumber != null && _phoneNumber!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Linked Phone: +$_phoneNumber',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isConnected
                                ? const Color(0xFF15803D)
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _copySessionId,
                  icon: const Icon(Icons.copy_rounded, size: 14),
                  label: const Text('Copy ID'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQrCard() {
    final isConnected = _status == 'connected';

    if (isConnected) {
      return Container(
        width: double.infinity,
        padding: AppSpacing.cardPadding,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.mdBorderRadius,
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.verified_rounded,
              size: 54,
              color: Color(0xFF25D366),
            ),
            const SizedBox(height: 12),
            Text(
              'WhatsApp Account is Connected!',
              style: AppTextStyles.h3.copyWith(fontSize: 16),
            ),
            const SizedBox(height: 6),
            if (_phoneNumber != null)
              Text(
                'Phone Number: +$_phoneNumber',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _relink,
                  icon: const Icon(Icons.sync_rounded, size: 16),
                  label: const Text('Re-link / Scan New'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _disconnect,
                  icon: const Icon(Icons.link_off_rounded, size: 16),
                  label: const Text('Disconnect Number'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: AppSpacing.cardPadding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdBorderRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(
            'Scan WhatsApp QR Code',
            style: AppTextStyles.h3.copyWith(fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            'Scan this QR code from your business WhatsApp phone to link your number.',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          _buildQrViewer(),
          const SizedBox(height: 20),
          SizedBox(
            width: 260,
            child: ElevatedButton.icon(
              onPressed: _startConnection,
              icon: Icon(
                _qrDataUrl != null
                    ? Icons.refresh_rounded
                    : Icons.qr_code_scanner_rounded,
                size: 18,
              ),
              label: Text(
                _qrDataUrl != null ? 'Refresh QR Code' : 'Generate QR Code',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.smBorderRadius,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrViewer() {
    if (_isConnecting) {
      return Container(
        width: 240,
        height: 240,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(strokeWidth: 2.5),
            SizedBox(height: 14),
            Text(
              'Generating QR Code...',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    if (_isQrExpired) {
      return Container(
        width: 240,
        height: 240,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.timer_off_rounded, size: 48, color: Color(0xFFD97706)),
            SizedBox(height: 10),
            Text(
              'QR Code Expired',
              style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF92400E), fontSize: 14),
            ),
            SizedBox(height: 6),
            Text(
              'Pairing timed out. Click below to generate a fresh QR code.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xFFB45309)),
            ),
          ],
        ),
      );
    }

    if (_qrDataUrl != null && _qrDataUrl!.isNotEmpty) {
      try {
        final cleanBase64 = _qrDataUrl!.contains(',')
            ? _qrDataUrl!.split(',').last
            : _qrDataUrl!;
        final bytes = base64Decode(cleanBase64.replaceAll(RegExp(r'\s+'), ''));

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Image.memory(
            bytes,
            width: 220,
            height: 220,
            fit: BoxFit.contain,
          ),
        );
      } catch (e) {
        return Container(
          width: 240,
          height: 240,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFECACA)),
          ),
          child: const Text(
            'Unable to decode QR Image.',
            style: TextStyle(color: Color(0xFFB91C1C), fontSize: 12),
          ),
        );
      }
    }

    return Container(
      width: 240,
      height: 240,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.qr_code_2_rounded, size: 64, color: AppColors.textDisabled),
          SizedBox(height: 10),
          Text(
            'Click below to generate QR code',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionsCard() {
    const steps = [
      ('1', 'Open your business WhatsApp on your mobile phone.'),
      ('2', 'Tap the three-dot menu (⋮) → "Linked Devices" → "Link a Device".'),
      ('3', 'Scan the QR code displayed above directly using your phone camera.'),
      ('4', 'Once scanned, WhatsApp will pair instantly and status becomes Connected.'),
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
          Text(
            'Connection Instructions',
            style: AppTextStyles.label.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final (num, text) in steps) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: Color(0xFF25D366),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      num,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
