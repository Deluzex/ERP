import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radius.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/models/subscription_model.dart';
import '../../core/utils/document_sharing_service.dart';
import '../providers/subscription_provider.dart';

class SubscriptionReminderDialog extends StatelessWidget {
  final SubscriptionStatus status;

  const SubscriptionReminderDialog({
    super.key,
    required this.status,
  });

  static Future<void> show(
    BuildContext context, {
    required SubscriptionStatus status,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => SubscriptionReminderDialog(status: status),
    );
  }

  void _openWhatsApp() {
    final message = 'નમસ્કાર Deluzex ટીમ, અમારી કંપની (${status.clientName}) નું Deluzex ERP સબ્સ્ક્રિપ્શન ${status.daysRemaining} દિવસમાં સમાપ્ત થશે. કૃપા કરીને રિન્યૂઅલ પ્રક્રિયા જણાવશો.';
    DocumentSharingService.shareToWhatsApp(
      phoneNumber: status.supportPhone,
      message: message,
    );
  }

  void _makeCall() {
    final cleaned = DocumentSharingService.cleanPhoneNumber(status.supportPhone);
    DocumentSharingService.openUrl('tel:$cleaned');
  }

  @override
  Widget build(BuildContext context) {
    final expiryFormatted = DateFormat('dd MMM yyyy').format(status.validUntil);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.xlBorderRadius,
          border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 30,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Bell / Alert Badge
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4), width: 1.5),
                ),
                child: const Icon(
                  Icons.notifications_active_rounded,
                  color: Color(0xFFD97706),
                  size: 26,
                ),
              ),
              const SizedBox(height: 12),

              // Header Title
              const Text(
                'સબ્સ્ક્રિપ્શન રિન્યૂઅલ સૂચના',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Deluzex Enterprise ERP • Renewal Reminder',
                style: AppTextStyles.caption.copyWith(color: AppColors.textDisabled, fontSize: 11),
              ),
              const SizedBox(height: 14),

              // Exact Gujarati Message requested by user (Short, Simple & Feelingful)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.07),
                  borderRadius: AppRadius.mdBorderRadius,
                  border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.2)),
                ),
                child: Column(
                  children: [
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 13.5,
                          height: 1.5,
                          color: AppColors.textPrimary,
                          fontFamily: 'Inter',
                        ),
                        children: [
                          const TextSpan(text: 'નમસ્કાર! આપનું સબ્સ્ક્રિપ્શન આગામી '),
                          TextSpan(
                            text: '${status.daysRemaining} દિવસોમાં',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFB45309),
                            ),
                          ),
                          const TextSpan(
                            text: ' સમાપ્ત થઈ રહ્યું છે. ફેક્ટરી ઉત્પાદન અને જીએસટી બિલિંગ અવિરત ચાલુ રહે તે માટે કૃપા કરીને સમયસર રિન્યૂ કરાવો.',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('સમાપ્તિ તારીખ:', style: AppTextStyles.caption),
                        Text(
                          expiryFormatted,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('બાકી દિવસો:', style: AppTextStyles.caption),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${status.daysRemaining} Days Left',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: Color(0xFFB45309),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // WhatsApp Quick Renewal Action
              SizedBox(
                width: double.infinity,
                height: 42,
                child: ElevatedButton.icon(
                  onPressed: () {
                    SubscriptionReminderTracker.markShownToday();
                    Navigator.of(context).pop();
                    _openWhatsApp();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.mdBorderRadius),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                  label: const Text(
                    'વોટ્સએપ પર રિન્યૂ કરાવો',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Call Action
              SizedBox(
                width: double.infinity,
                height: 38,
                child: OutlinedButton.icon(
                  onPressed: () {
                    SubscriptionReminderTracker.markShownToday();
                    Navigator.of(context).pop();
                    _makeCall();
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primary, width: 1.2),
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.mdBorderRadius),
                    foregroundColor: AppColors.primary,
                  ),
                  icon: const Icon(Icons.phone_in_talk_rounded, size: 16),
                  label: Text(
                    'કૉલ કરો (${status.supportPhone})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                  ),
                ),
              ),
              const SizedBox(height: 6),

              // Dismiss Button (Records daily dismissal)
              TextButton(
                onPressed: () {
                  SubscriptionReminderTracker.markShownToday();
                  Navigator.of(context).pop();
                },
                child: Text(
                  'સમજી ગયા (Dismiss for today)',
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
}
