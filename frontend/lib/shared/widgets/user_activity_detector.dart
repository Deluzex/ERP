import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Centralized detector wrapping the ERP application to capture all user activity:
/// - Mouse clicks and touch taps (PointerDownEvent)
/// - Mouse movements (PointerMoveEvent, PointerHoverEvent)
/// - Scrolling (PointerScrollEvent via onPointerSignal)
/// - Keyboard typing (KeyDownEvent)
///
/// Resets the 30-minute inactivity auto-logout timer on any meaningful interaction.
class UserActivityDetector extends StatelessWidget {
  final Widget child;
  final VoidCallback onUserActivity;

  const UserActivityDetector({
    super.key,
    required this.child,
    required this.onUserActivity,
  });

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => onUserActivity(),
      onPointerMove: (_) => onUserActivity(),
      onPointerHover: (_) => onUserActivity(),
      onPointerSignal: (_) => onUserActivity(),
      child: Focus(
        canRequestFocus: false,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            onUserActivity();
          }
          return KeyEventResult.ignored;
        },
        child: child,
      ),
    );
  }
}

