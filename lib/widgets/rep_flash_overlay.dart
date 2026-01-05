import 'package:flutter/material.dart';

/// Overlay widget that flashes green for valid reps and red for invalid reps.
class RepFlashOverlay extends StatefulWidget {
  final Widget child;
  final VoidCallback? onFlashComplete;

  const RepFlashOverlay({
    super.key,
    required this.child,
    this.onFlashComplete,
  });

  @override
  State<RepFlashOverlay> createState() => RepFlashOverlayState();
}

class RepFlashOverlayState extends State<RepFlashOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  Color _flashColor = Colors.green;
  bool _isFlashing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _animation = Tween<double>(begin: 0.0, end: 0.4).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _controller.reverse();
      } else if (status == AnimationStatus.dismissed) {
        setState(() => _isFlashing = false);
        widget.onFlashComplete?.call();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Flash green for a valid rep
  void flashValid() {
    _flash(Colors.green);
  }

  /// Flash red for an invalid rep
  void flashInvalid() {
    _flash(Colors.red);
  }

  void _flash(Color color) {
    if (_isFlashing) return;

    setState(() {
      _flashColor = color;
      _isFlashing = true;
    });
    _controller.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_isFlashing)
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return IgnorePointer(
                child: Container(
                  color: _flashColor.withOpacity(_animation.value),
                ),
              );
            },
          ),
      ],
    );
  }
}
