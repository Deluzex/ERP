import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Centralized detector wrapping the ERP application to capture all user activity:
/// - Mouse clicks and touch taps (PointerDownEvent)
/// - Mouse movements & hovers (PointerMoveEvent, PointerHoverEvent)
/// - Scrolling inside lists, tables, and pages (PointerScrollEvent / PointerSignal)
/// - Keyboard typing inside text fields, forms, search bars, and shortcuts (HardwareKeyboard & KeyDownEvent)
/// - Navigation, dialog, dropdown, and component interactions
///
/// Resets the 30-minute inactivity auto-logout timer on any meaningful interaction.
class UserActivityDetector extends StatefulWidget {
  final Widget child;
  final VoidCallback onUserActivity;

  const UserActivityDetector({
    super.key,
    required this.child,
    required this.onUserActivity,
  });

  @override
  State<UserActivityDetector> createState() => _UserActivityDetectorState();
}

class _UserActivityDetectorState extends State<UserActivityDetector> {
  DateTime _lastActivityReported = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    // 1. Capture all global hardware keyboard events application-wide
    // (even when consumed by EditableText, TextField, Shortcuts, or FocusNodes)
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);

    // 2. Capture all global pointer events application-wide
    // (clicks, taps, drags, scrolls, hovering)
    WidgetsBinding.instance.pointerRouter.addGlobalRoute(_handlePointerEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    WidgetsBinding.instance.pointerRouter.removeGlobalRoute(_handlePointerEvent);
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      _triggerActivity();
    }
    return false; // Do not consume or suppress the key event
  }

  void _handlePointerEvent(PointerEvent event) {
    // Only meaningful user pointer actions
    if (event is PointerDownEvent ||
        event is PointerMoveEvent ||
        event is PointerHoverEvent ||
        event is PointerScrollEvent ||
        event is PointerPanZoomUpdateEvent) {
      _triggerActivity();
    }
  }

  void _triggerActivity() {
    final now = DateTime.now();
    // Throttle calling parent callback to at most once every 300ms to avoid UI overhead
    if (now.difference(_lastActivityReported).inMilliseconds >= 300) {
      _lastActivityReported = now;
      widget.onUserActivity();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _triggerActivity(),
      onPointerMove: (_) => _triggerActivity(),
      onPointerHover: (_) => _triggerActivity(),
      onPointerSignal: (_) => _triggerActivity(),
      child: Focus(
        canRequestFocus: false,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            _triggerActivity();
          }
          return KeyEventResult.ignored;
        },
        child: widget.child,
      ),
    );
  }
}
