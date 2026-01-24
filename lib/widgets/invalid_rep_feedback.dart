import 'package:flutter/material.dart';
import '../models/invalid_rep_reason.dart';

/// Displays brief feedback when a rep is marked invalid.
/// Shows the user-friendly message for 1.5 seconds with fade animation.
class InvalidRepFeedback extends StatefulWidget {
  const InvalidRepFeedback({super.key});

  @override
  State<InvalidRepFeedback> createState() => InvalidRepFeedbackState();
}

class InvalidRepFeedbackState extends State<InvalidRepFeedback>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  InvalidRepReason? _currentReason;
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Fade in quickly, stay visible, then fade out
    _fadeAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 10, // 150ms fade in
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 60, // 900ms visible
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 30, // 450ms fade out
      ),
    ]).animate(_controller);

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _isVisible = false;
          _currentReason = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Show feedback for the given invalid rep reason
  void show(InvalidRepReason reason) {
    setState(() {
      _currentReason = reason;
      _isVisible = true;
    });
    _controller.forward(from: 0.0);
  }

  /// Show feedback from InvalidRepInfo
  void showFromInfo(InvalidRepInfo info) {
    show(info.reason);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible || _currentReason == null) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: child,
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.orange.shade700,
            width: 2,
          ),
        ),
        child: Text(
          _currentReason!.userMessage,
          style: TextStyle(
            color: Colors.orange.shade300,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
