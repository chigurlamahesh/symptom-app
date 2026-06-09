import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AnimatedButton extends StatefulWidget {
  final Widget child;
  final double scaleFactor;
  final Duration duration;
  final bool enabled;

  const AnimatedButton({
    super.key,
    required this.child,
    this.scaleFactor = 0.90, // Significant 10% scale down to be clearly visible
    this.duration = const Duration(milliseconds: 150), // 150ms for a smoother transition
    this.enabled = true,
  });

  @override
  State<AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<AnimatedButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }
    return Listener(
      behavior: HitTestBehavior.translucent, // Ensure it registers events even if child is opaque
      onPointerDown: (_) {
        if (kDebugMode) {
          print("AnimatedButton pointer down - scaling to ${widget.scaleFactor}");
        }
        if (mounted) {
          setState(() => _isPressed = true);
        }
      },
      onPointerUp: (_) {
        if (kDebugMode) {
          print("AnimatedButton pointer up - resetting scale");
        }
        if (mounted) {
          setState(() => _isPressed = false);
        }
      },
      onPointerCancel: (_) {
        if (kDebugMode) {
          print("AnimatedButton pointer cancel - resetting scale");
        }
        if (mounted) {
          setState(() => _isPressed = false);
        }
      },
      child: AnimatedScale(
        scale: _isPressed ? widget.scaleFactor : 1.0,
        duration: widget.duration,
        curve: Curves.easeOutBack, // Springy curve for extra tactile feel
        child: widget.child,
      ),
    );
  }
}
