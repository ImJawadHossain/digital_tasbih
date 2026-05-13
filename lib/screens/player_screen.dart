import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vibration/vibration.dart';
import '../models/tasbih_item.dart';
import 'dart:math';

class PlayerScreen extends StatefulWidget {
  final TasbihItem item;

  const PlayerScreen({super.key, required this.item});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  // Floating text animations list
  final List<_FloatingText> _floatingTexts = [];
  int _floatingId = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    for (final ft in _floatingTexts) {
      ft.controller.dispose();
    }
    super.dispose();
  }

  int get _currentLapCount {
    if (widget.item.count == 0) return 0;
    int rem = widget.item.count % widget.item.targetLimit;
    return (rem == 0) ? widget.item.targetLimit : rem;
  }

  double get _progressValue {
    if (widget.item.targetLimit == 0) return 0.0;
    return _currentLapCount / widget.item.targetLimit;
  }

  void _spawnFloatingText() {
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    final id = _floatingId++;
    final ft = _FloatingText(
      id: id,
      controller: controller,
      opacity: Tween<double>(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeInOut),
      ),
      offset: Tween<double>(begin: 0.0, end: -80.0).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeOut),
      ),
    );

    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _floatingTexts.removeWhere((f) => f.id == id);
        });
        // Dispose safely after the frame renders to prevent 'white screen' crash
        Future.delayed(Duration.zero, () {
          controller.dispose();
        });
      }
    });

    setState(() {
      _floatingTexts.add(ft);
    });
    controller.forward();
  }

  Future<void> _incrementCounter() async {
    bool hitLimit = ((widget.item.count + 1) % widget.item.targetLimit) == 0;

    // Haptic feedback
    if (await Vibration.hasVibrator() ?? false) {
      if (hitLimit) {
        Vibration.vibrate(duration: 500);
      } else {
        Vibration.vibrate(duration: 50);
      }
    }

    // Play button scale animation
    _animationController.forward().then((_) => _animationController.reverse());

    // Spawn floating text
    _spawnFloatingText();

    setState(() {
      widget.item.count++;

      // Update history for today
      String today = DateTime.now().toIso8601String().split('T')[0];
      widget.item.history[today] = (widget.item.history[today] ?? 0) + 1;
    });
  }

  Future<void> _resetCounter() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text('Reset Counter', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text('Reset ${widget.item.name} count back to 0?', style: GoogleFonts.inter()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Reset', style: GoogleFonts.inter(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (await Vibration.hasVibrator() ?? false) {
        Vibration.vibrate(duration: 150, amplitude: 255);
      }
      setState(() {
        widget.item.count = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    int totalLaps = (widget.item.count / widget.item.targetLimit).floor();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.item.name,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w600,
            fontSize: 24,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _resetCounter,
            tooltip: 'Reset Count',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Main content
            Column(
              children: [
                const Spacer(flex: 1),

                // Overall Stats
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildStatBadge('Total', widget.item.count.toString()),
                    const SizedBox(width: 16),
                    _buildStatBadge('Laps', totalLaps.toString()),
                  ],
                ),

                const Spacer(flex: 2),

                // Main Tap Button with Circular Progress
                Center(
                  child: GestureDetector(
                    onTap: _incrementCounter,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: SizedBox(
                        width: 320,
                        height: 320,
                        child: Stack(
                          fit: StackFit.expand,
                          clipBehavior: Clip.none,
                          children: [
                            // Circular Progress
                            TweenAnimationBuilder<double>(
                              tween: Tween<double>(
                                begin: _progressValue == 1.0 ? 0 : _progressValue,
                                end: _progressValue,
                              ),
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutCubic,
                              builder: (context, value, _) {
                                return CircularProgressIndicator(
                                  value: value,
                                  strokeWidth: 12,
                                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                  color: _progressValue == 1.0
                                      ? Theme.of(context).colorScheme.secondary
                                      : Theme.of(context).colorScheme.primary,
                                  strokeCap: StrokeCap.round,
                                );
                              },
                            ),

                            // Inner Button
                            Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Theme.of(context).colorScheme.primary.withOpacity(0.8),
                                      Theme.of(context).colorScheme.tertiary.withOpacity(0.8),
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                                      blurRadius: 32,
                                      offset: const Offset(0, 16),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        '$_currentLapCount',
                                        style: GoogleFonts.outfit(
                                          fontSize: 72,
                                          fontWeight: FontWeight.w800,
                                          height: 1.0,
                                          color: Theme.of(context).colorScheme.onPrimary,
                                        ),
                                      ),
                                      Text(
                                        '/ ${widget.item.targetLimit}',
                                        style: GoogleFonts.inter(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w600,
                                          color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // Floating text overlays
                            ..._floatingTexts.map((ft) {
                              return Positioned(
                                left: 0,
                                right: 0,
                                // Anchored exactly at the top of the circle
                                top: -20,
                                child: IgnorePointer(
                                  child: AnimatedBuilder(
                                    animation: ft.controller,
                                    builder: (context, _) {
                                      return Transform.translate(
                                        offset: Offset(0, ft.offset.value),
                                        child: Opacity(
                                          opacity: ft.opacity.value,
                                          child: Text(
                                            widget.item.name,
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.outfit(
                                              fontSize: 28,
                                              fontWeight: FontWeight.w700,
                                              color: Theme.of(context).colorScheme.primary,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const Spacer(flex: 3),

                Text(
                  'Tap anywhere inside the circle',
                  style: GoogleFonts.inter(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),

                const Spacer(flex: 1),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBadge(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper class to hold each floating text's animation state
class _FloatingText {
  final int id;
  final AnimationController controller;
  final Animation<double> opacity;
  final Animation<double> offset;

  _FloatingText({
    required this.id,
    required this.controller,
    required this.opacity,
    required this.offset,
  });
}
