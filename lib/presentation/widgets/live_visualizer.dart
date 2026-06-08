import 'dart:async';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'ceramic_texture.dart';

class LiveVisualizer extends StatefulWidget {
  const LiveVisualizer({
    super.key,
    required this.isPlaying,
    this.points = 36,
  });

  final bool isPlaying;
  final int points;

  @override
  State<LiveVisualizer> createState() => _LiveVisualizerState();
}

class _LiveVisualizerState extends State<LiveVisualizer> {
  final _random = math.Random();
  Timer? _timer;
  late List<double> _levels;

  @override
  void initState() {
    super.initState();
    _levels = List<double>.generate(widget.points, (_) => 0.15);
    _bindTimer();
  }

  @override
  void didUpdateWidget(covariant LiveVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPlaying != widget.isPlaying) {
      _bindTimer();
    }
  }

  void _bindTimer() {
    _timer?.cancel();
    if (!widget.isPlaying) {
      setState(() => _levels = List<double>.generate(widget.points, (_) => 0.1));
      return;
    }
    _timer = Timer.periodic(const Duration(milliseconds: 120), (_) {
      if (!mounted) return;
      setState(() {
        _levels = _levels
            .skip(1)
            .followedBy([
              0.15 + (_random.nextDouble() * 0.8),
            ])
            .toList();
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spots = _levels
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          Container(
            height: 96,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.mixerLineGradient[0].withValues(alpha: 0.35),
                  AppTheme.mixerLineGradient[1].withValues(alpha: 0.3),
                ],
              ),
            ),
          ),
          const Positioned.fill(child: CeramicFilmGrain()),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
              ),
            ),
          ),
          Container(
            height: 96,
            padding: const EdgeInsets.all(10),
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (widget.points - 1).toDouble(),
                minY: 0,
                maxY: 1.05,
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineTouchData: const LineTouchData(enabled: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    gradient: AppTheme.mixerLinearLr,
                    barWidth: 2.2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppTheme.mixerLineGradient[0].withValues(alpha: 0.28),
                          AppTheme.mixerLineGradient[1].withValues(alpha: 0.06),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
