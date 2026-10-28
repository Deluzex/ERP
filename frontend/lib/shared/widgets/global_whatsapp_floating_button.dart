import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/whatsapp_models.dart';
import '../../core/utils/document_sharing_service.dart';
import '../providers/app_state_providers.dart';

class GlobalWhatsAppFloatingButton extends ConsumerWidget {
  const GlobalWhatsAppFloatingButton({super.key});

  static const double _buttonSize = 46.0;

  void _openConfigDialog(BuildContext context, WidgetRef ref) {
    final db = ref.read(databaseServiceProvider);
    final config = db.globalSupportConfig;

    final teamCtrl = TextEditingController(text: config.teamName);
    final numberCtrl = TextEditingController(text: config.whatsappNumber);
    final linkCtrl = TextEditingController(text: config.groupLink ?? '');
    final msgCtrl = TextEditingController(text: config.defaultMessage);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF25D366).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.settings, color: Color(0xFF25D366), size: 20),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Configure WhatsApp Support', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          width: double.infinity,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: teamCtrl,
                  decoration: const InputDecoration(labelText: 'Team / Desk Name', hintText: 'e.g. Deluzex ERP Operations Team'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: numberCtrl,
                  decoration: const InputDecoration(labelText: 'Support WhatsApp Number', hintText: '+91 98200 12345'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: linkCtrl,
                  decoration: const InputDecoration(labelText: 'WhatsApp Group / Chat Link (Optional)', hintText: 'https://chat.whatsapp.com/...'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: msgCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Default Greeting Message'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              db.updateGlobalSupportConfig(GlobalSupportConfig(
                teamName: teamCtrl.text.trim(),
                whatsappNumber: numberCtrl.text.trim(),
                groupLink: linkCtrl.text.trim().isNotEmpty ? linkCtrl.text.trim() : null,
                defaultMessage: msgCtrl.text.trim(),
              ));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Global WhatsApp Support destination updated!')),
              );
            },
            child: const Text('Save Configuration'),
          ),
        ],
      ),
    );
  }

  void _launchWhatsApp(BuildContext context, WidgetRef ref) {
    final db = ref.read(databaseServiceProvider);
    final config = db.globalSupportConfig;

    if (config.groupLink != null && config.groupLink!.isNotEmpty) {
      DocumentSharingService.openUrl(config.groupLink!);
    } else {
      DocumentSharingService.shareToWhatsApp(
        phoneNumber: config.whatsappNumber,
        message: config.defaultMessage,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Positioned(
      bottom: 24,
      right: 24,
      child: Material(
        elevation: 6,
        shape: const CircleBorder(),
        color: const Color(0xFF25D366),
        child: Tooltip(
          message: 'Team Support',
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => _launchWhatsApp(context, ref),
            onLongPress: () => _openConfigDialog(context, ref),
            child: const SizedBox(
              width: _buttonSize,
              height: _buttonSize,
              child: Center(
                child: Icon(Icons.chat_bubble, color: Colors.white, size: 24),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
