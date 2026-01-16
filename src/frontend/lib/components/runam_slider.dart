import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app/theme.dart';

class RunAmSlider extends StatefulWidget {
  final String buttonText;
  final VoidCallback onComplete;
  final double threshold;
  final Color? borderColor;
  final Color? circleColor;
  final TextStyle? textStyle;
  final bool enabled;

  const RunAmSlider({
    super.key,
    this.buttonText = "Request",
    required this.onComplete,
    this.threshold = 0.9,
    this.borderColor,
    this.circleColor,
    this.textStyle,
    this.enabled = true,
  });

  @override
  State<RunAmSlider> createState() => _RunAmSliderState();
}

class _RunAmSliderState extends State<RunAmSlider> with TickerProviderStateMixin {
  double _sliderValue = 0.0;
  bool _isRunning = false;
  late AnimationController _pulseController;
  late AnimationController _secondArrowController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _secondArrowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    // Delay the second arrow animation by 700ms
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) {
        _secondArrowController.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _secondArrowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width - 48;
    double sliderWidth = 70 + (_sliderValue * 30); // Stretch from 70 to 100

    return Opacity(
      opacity: widget.enabled ? 1.0 : 0.5,
      child: GestureDetector(
        onHorizontalDragUpdate: widget.enabled ? (details) {
          setState(() {
            _sliderValue = (details.localPosition.dx / width).clamp(0.0, 1.0);
            _isRunning = _sliderValue > 0.6;
          });
        } : null,
        onHorizontalDragEnd: widget.enabled ? (details) {
          if (_sliderValue > widget.threshold) {
            widget.onComplete();
          } else {
            setState(() {
              _sliderValue = 0.0;
              _isRunning = false;
            });
          }
        } : null,
        child: Container(
          height: 80,
          width: width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(50),
            border: Border.all(
              color: widget.borderColor ?? AppTheme.primary700,
              width: 1,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                widget.buttonText,
                style: widget.textStyle ??
                    GoogleFonts.shantellSans(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary700,
                    ),
              ),
              Positioned(
                left: _sliderValue * (width - sliderWidth),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  height: 75,
                  width: sliderWidth,
                  margin: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(50),
                    color: widget.circleColor ?? AppTheme.primary500,
                  ),
                  child: Center(
                    child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // First arrow with lower opacity
                              AnimatedBuilder(
                                animation: _pulseController,
                                builder: (context, child) {
                                  return Transform.translate(
                                    offset: Offset(_pulseController.value * 8, 0),
                                    child: const Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      size: 30,
                                      color: Color.fromRGBO(98, 70, 234, 0.4),
                                    ),
                                  );
                                },
                              ),
                              // Second arrow with full opacity (delayed)
                              AnimatedBuilder(
                                animation: _secondArrowController,
                                builder: (context, child) {
                                  return Transform.translate(
                                    offset: Offset(_secondArrowController.value * 8 + 10, 0),
                                    child: const Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      size: 30,
                                      color: AppTheme.primary700,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
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

