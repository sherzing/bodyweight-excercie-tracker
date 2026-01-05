import 'dart:math';
import 'package:flutter/material.dart';

/// Celebration overlay with confetti animation for workout completion.
class CelebrationOverlay extends StatefulWidget {
  final VoidCallback? onAnimationComplete;

  const CelebrationOverlay({
    super.key,
    this.onAnimationComplete,
  });

  @override
  State<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<CelebrationOverlay>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late List<_ConfettiParticle> _particles;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    _particles = List.generate(50, (_) => _createParticle());

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onAnimationComplete?.call();
      }
    });

    _controller.forward();
  }

  _ConfettiParticle _createParticle() {
    return _ConfettiParticle(
      x: _random.nextDouble(),
      y: -0.1 - _random.nextDouble() * 0.3,
      speed: 0.3 + _random.nextDouble() * 0.4,
      rotation: _random.nextDouble() * 2 * pi,
      rotationSpeed: (_random.nextDouble() - 0.5) * 10,
      size: 8 + _random.nextDouble() * 8,
      color: _randomColor(),
      wobble: _random.nextDouble() * 2 * pi,
      wobbleSpeed: 2 + _random.nextDouble() * 3,
    );
  }

  Color _randomColor() {
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.yellow,
      Colors.purple,
      Colors.orange,
      Colors.pink,
      Colors.cyan,
    ];
    return colors[_random.nextInt(colors.length)];
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _ConfettiPainter(
              particles: _particles,
              progress: _controller.value,
            ),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _ConfettiParticle {
  final double x;
  final double y;
  final double speed;
  final double rotation;
  final double rotationSpeed;
  final double size;
  final Color color;
  final double wobble;
  final double wobbleSpeed;

  _ConfettiParticle({
    required this.x,
    required this.y,
    required this.speed,
    required this.rotation,
    required this.rotationSpeed,
    required this.size,
    required this.color,
    required this.wobble,
    required this.wobbleSpeed,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  final double progress;

  _ConfettiPainter({
    required this.particles,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      final x = size.width * particle.x +
          sin(particle.wobble + progress * particle.wobbleSpeed * 2 * pi) * 30;
      final y = size.height * (particle.y + progress * particle.speed * 2);

      // Skip if particle is off screen
      if (y > size.height + 50) continue;

      final paint = Paint()
        ..color = particle.color.withOpacity(1 - progress * 0.5)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(particle.rotation + progress * particle.rotationSpeed);

      // Draw confetti as a rectangle
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: particle.size,
          height: particle.size * 0.6,
        ),
        paint,
      );

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
