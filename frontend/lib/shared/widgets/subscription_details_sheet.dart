import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radius.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/models/subscription_model.dart';
import '../../core/utils/document_sharing_service.dart';

class SubscriptionDetailsSheet extends StatelessWidget {
  final SubscriptionStatus status;

  const SubscriptionDetailsSheet({super.key, required this.status});

  static Future<void> show(BuildContext context, SubscriptionStatus status) async {
    await showDialog(
      context: context,
      builder: (ctx) => SubscriptionDetailsSheet(status: status),
    );
  }

  void _openWhatsApp() {
    final message = 'નમસ્કાર Deluzex સપોર્ટ ટીમ, અમારી કંપની (${status.clientName}) ના Deluzex ERP સબ્સ્ક્રિપ્શન અંગે માહિતી જોઈએ છે.';
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
    final fromFormatted = DateFormat('dd MMM yyyy').format(status.validFrom);
    final isWarning = status.showRenewalWarning;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.xlBorderRadius,
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: isWarning
                              ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                              : const Color(0xFF16A34A).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isWarning ? Icons.warning_amber_rounded : Icons.verified_rounded,
                          color: isWarning ? const Color(0xFFD97706) : const Color(0xFF16A34A),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'સબ્સ્ક્રિપ્શન વિગતો',
                            style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                          Text(
                            'Deluzex Instance License',
                            style: AppTextStyles.caption.copyWith(color: AppColors.textDisabled, fontSize: 10.5),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 19, color: AppColors.textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 14),

              // Info rows
              _buildDetailRow('કંપની / ક્લાયન્ટ:', status.clientName),
              const SizedBox(height: 8),
              _buildDetailRow('પ્લાન:', status.planName),
              const SizedBox(height: 8),
              _buildDetailRow('શરૂઆત તારીખ:', fromFormatted),
              const SizedBox(height: 8),
              _buildDetailRow('સમાપ્તિ તારીખ:', expiryFormatted),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('બાકી સમય:', style: AppTextStyles.caption.copyWith(fontSize: 12)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: isWarning
                          ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                          : const Color(0xFF16A34A).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isWarning
                            ? const Color(0xFFF59E0B).withValues(alpha: 0.4)
                            : const Color(0xFF16A34A).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isWarning ? Icons.access_time_rounded : Icons.check_circle_rounded,
                          size: 12,
                          color: isWarning ? const Color(0xFFD97706) : const Color(0xFF16A34A),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${status.daysRemaining} Days Left',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: isWarning ? const Color(0xFFB45309) : const Color(0xFF15803D),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Short polite note
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  isWarning
                      ? 'નમસ્કાર! આપનું સબ્સ્ક્રિપ્શન ${status.daysRemaining} દિવસમાં પૂરું થાય છે. અવિરત સેવા માટે સમયસર રિન્યૂ કરાવો.'
                      : 'આપનું Deluzex ERP સબ્સ્ક્રિપ્શન સક્રિય છે. કોઈ પ્રશ્ન હોય તો હેલ્પડેસ્કનો સંપર્ક કરો.',
                  style: const TextStyle(fontSize: 11.5, height: 1.4, color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: 18),

              // Contact Actions
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _openWhatsApp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdBorderRadius),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                      label: const Text(
                        'WhatsApp',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _makeCall,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primary, width: 1.2),
                        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdBorderRadius),
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: const Icon(Icons.phone_outlined, size: 16),
                      label: const Text(
                        'Call Support',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.caption.copyWith(fontSize: 12)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600, fontSize: 12),
          ),
        ),
      ],
    );
  }
}
