import 'package:flutter/material.dart';

/// Runs a drop-bounce animation on each letter of “Elytic”, then two gentle heartbeats,
/// followed by a smooth fade-out transition.
class LandingAnimation extends StatefulWidget {
  final VoidCallback onAnimationComplete;

  const LandingAnimation({Key? key, required this.onAnimationComplete})
      : super(key: key);

  @override
  _LandingAnimationState createState() => _LandingAnimationState();
}

class _LandingAnimationState extends State<LandingAnimation>
    with TickerProviderStateMixin {
  static const _word = 'Elytic';
  static const _stagger = Duration(milliseconds: 250);
  static const _dropDuration = Duration(milliseconds: 600);
  static const _beatDuration = Duration(milliseconds: 500); // Slower beat duration
  static const _totalBeats = 2;

  late final AnimationController _dropController;
  late final List<Animation<double>> _drops;
  late final AnimationController _beatController;
  late final Animation<double> _beat;

  late final AnimationController _fadeController;
  late final Animation<double> _fade;

  int _beatsDone = 0;

  @override
  void initState() {
    super.initState();

    final totalDropMs = _dropDuration.inMilliseconds +
        (_word.length - 1) * _stagger.inMilliseconds;
    _dropController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: totalDropMs),
    );

    _drops = List.generate(_word.length, (i) {
      final start = (i * _stagger.inMilliseconds) / totalDropMs;
      final end = (i * _stagger.inMilliseconds + _dropDuration.inMilliseconds) /
          totalDropMs;
      return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _dropController,
          curve: Interval(start, end, curve: Curves.elasticOut),
        ),
      );
    });

    _beatController = AnimationController(
      vsync: this,
      duration: _beatDuration,
    );
    _beat = Tween<double>(begin: 1.0, end: 1.2).animate( // Reduced scale range
      CurvedAnimation(parent: _beatController, curve: Curves.easeInOut),
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fade = Tween<double>(begin: 1.0, end: 0.0).animate(_fadeController);

    _beatController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _beatsDone++;
        if (_beatsDone < _totalBeats) {
          _beatController.reverse();
        } else {
          _fadeController.forward();
        }
      } else if (status == AnimationStatus.dismissed &&
          _beatsDone < _totalBeats) {
        _beatController.forward();
      }
    });

    _fadeController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onAnimationComplete();
      }
    });

    _dropController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _beatController.forward();
      }
    });

    _dropController.forward();
  }

  @override
  void dispose() {
    _dropController.dispose();
    _beatController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    return FadeTransition(
      opacity: _fade,
      child: AnimatedBuilder(
        animation: Listenable.merge([_dropController, _beatController]),
        builder: (context, child) {
          if (!_dropController.isCompleted) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(_word.length, (i) {
                final frac = _drops[i].value;
                final dy = frac * screenHeight - screenHeight;
                return Transform.translate(
                  offset: Offset(0, dy),
                  child: Text(
                    _word[i],
                    style: const TextStyle(
                      fontSize: 120,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }),
            );
          }

          // Gentle Heartbeat
          return Transform.scale(
            scale: _beat.value,
            child: const Text(
              _word,
              style: TextStyle(
                fontSize: 100,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        },
      ),
    );
  }
}
