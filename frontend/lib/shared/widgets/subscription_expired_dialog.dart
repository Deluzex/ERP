import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radius.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/utils/document_sharing_service.dart';

class SubscriptionExpiredDialog extends StatelessWidget {
  final String clientName;
  final String planName;
  final String? expiredOn;
  final String supportPhone;
  final String supportEmail;

  const SubscriptionExpiredDialog({
    super.key,
    required this.clientName,
    required this.planName,
    this.expiredOn,
    required this.supportPhone,
    required this.supportEmail,
  });

  static Future<void> show(
    BuildContext context, {
    String clientName = 'Deluzex ERP Client',
    String planName = 'Enterprise Annual Edition',
    String? expiredOn,
    String supportPhone = '+91 98250 12345',
    String supportEmail = 'billing@deluzex.com',
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => SubscriptionExpiredDialog(
        clientName: clientName,
        planName: planName,
        expiredOn: expiredOn,
        supportPhone: supportPhone,
        supportEmail: supportEmail,
      ),
    );
  }

  void _openWhatsApp() {
    final message = 'નમસ્કાર Deluzex ટીમ, અમારી કંપની ($clientName) નું Deluzex ERP સબ્સ્ક્રિપ્શન રિન્યૂ કરાવવું છે. કૃપા કરીને વિગતો જણાવશો.';
    DocumentSharingService.shareToWhatsApp(
      phoneNumber: supportPhone,
      message: message,
    );
  }

  void _makeCall() {
    final cleaned = DocumentSharingService.cleanPhoneNumber(supportPhone);
    DocumentSharingService.openUrl('tel:$cleaned');
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.xlBorderRadius,
          border: Border.all(color: AppColors.danger.withValues(alpha: 0.35), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 32,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Warning Icon with soft glow
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.danger.withValues(alpha: 0.3), width: 1.5),
                ),
                child: const Icon(
                  Icons.lock_clock_rounded,
                  color: AppColors.danger,
                  size: 30,
                ),
              ),
              const SizedBox(height: 14),

              // Gujarati Title (Feelingful & Simple)
              const Text(
                'સબ્સ્ક્રિપ્શન સમાપ્ત થયેલ છે',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Deluzex Enterprise ERP • Subscription Expired',
                style: AppTextStyles.caption.copyWith(color: AppColors.textDisabled, fontSize: 11),
              ),
              const SizedBox(height: 14),

              // Warm and feelingful Gujarati message
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: AppRadius.mdBorderRadius,
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    const Text(
                      'નમસ્કાર!\nઆપનું સબ્સ્ક્રિપ્શન સમાપ્ત થયેલ છે. ફેક્ટરી ઉત્પાદન અને જીએસટી બિલિંગ અવિરત ચાલુ રહે તે માટે કૃપા કરીને સંપર્ક કરો.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Divider(height: 1),
                    const SizedBox(height: 10),
                    _buildRow('ક્લાયન્ટ / કંપની:', clientName),
                    const SizedBox(height: 6),
                    _buildRow('સક્રિય પ્લાન:', planName),
                    if (expiredOn != null && expiredOn!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _buildRow('સમાપ્તિ તારીખ:', expiredOn!, isHighlight: true),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Action Buttons: WhatsApp Support, Call Support
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: _openWhatsApp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.mdBorderRadius),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                  label: const Text(
                    'WhatsApp પર સંપર્ક કરો',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              SizedBox(
                width: double.infinity,
                height: 40,
                child: OutlinedButton.icon(
                  onPressed: _makeCall,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primary, width: 1.2),
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.mdBorderRadius),
                    foregroundColor: AppColors.primary,
                  ),
                  icon: const Icon(Icons.phone_in_talk_rounded, size: 17),
                  label: Text(
                    'કૉલ કરો ($supportPhone)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Close Button
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'બંધ કરો (Close)',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textMuted,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value, {bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.caption),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: isHighlight ? AppColors.danger : null,
              fontSize: 12.5,
            ),
          ),
        ),
      ],
    );
  }
}
