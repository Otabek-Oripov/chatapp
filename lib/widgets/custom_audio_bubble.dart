import 'dart:math';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class CustomAudioBubble extends StatefulWidget {
  final String audioUrl;
  final bool isMe;
  final Color bubbleColor;
  final Color textColor;
  final Color accentColor;

  const CustomAudioBubble({
    required this.audioUrl,
    required this.isMe,
    required this.bubbleColor,
    required this.textColor,
    required this.accentColor,
    Key? key,
  }) : super(key: key);

  @override
  State<CustomAudioBubble> createState() => _CustomAudioBubbleState();
}

class _CustomAudioBubbleState extends State<CustomAudioBubble>
    with SingleTickerProviderStateMixin {
  late final AudioPlayer _player;
  late final AnimationController _waveController;
  late final List<double> _waveHeights;

  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  double _speed = 1.0;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _waveHeights = List.generate(16, (i) => 4 + Random().nextDouble() * 12);
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      await _player.setUrl(widget.audioUrl);

      _player.durationStream.listen((dur) {
        if (dur != null) setState(() => _duration = dur);
      });

      _player.positionStream.listen((pos) {
        setState(() => _position = pos);
      });

      _player.playerStateStream.listen((state) {
        final playing = state.playing;
        final completed = state.processingState == ProcessingState.completed;

        setState(() {
          _isPlaying = playing && !completed;
        });

        if (completed) {
          _player.pause();
          _player.seek(Duration.zero);
          _waveController.stop();
        } else if (playing) {
          _waveController.repeat(reverse: true);
        } else {
          _waveController.stop();
        }
      });
    } catch (e) {
      debugPrint('Audio load error: $e');
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    _player.dispose();
    super.dispose();
  }

  String _formatMinutes(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    return '$m:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final progress = _duration.inMilliseconds == 0
        ? 0.0
        : _position.inMilliseconds / _duration.inMilliseconds;

    return Align(
      alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: widget.bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(widget.isMe ? 16 : 4),
            bottomRight: Radius.circular(widget.isMe ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ▶️ Play / Pause
            InkWell(
              onTap: () async {
                if (_isPlaying) {
                  await _player.pause();
                } else {
                  await _player.play();
                }
              },
              borderRadius: BorderRadius.circular(50),
              child: CircleAvatar(
                radius: 22,
                backgroundColor: widget.accentColor.withOpacity(0.1),
                child: Icon(
                  _isPlaying ? Icons.pause : Icons.play_arrow,
                  color: widget.accentColor,
                  size: 28,
                ),
              ),
            ),

            const SizedBox(width: 10),

            // 🔊 Animated Waveform
            Expanded(
              child: AnimatedBuilder(
                animation: _waveController,
                builder: (context, _) {
                  final value = _waveController.value;
                  return CustomPaint(
                    painter: _WaveformPainter(
                      value: value,
                      progress: progress,
                      accentColor: widget.accentColor,
                      baseHeights: _waveHeights,
                    ),
                    child: const SizedBox(height: 36),
                  );
                },
              ),
            ),

            const SizedBox(width: 12),

            // ⏱ Duration
            Text(
              _formatMinutes(_duration),
              style: TextStyle(
                fontSize: 12,
                color: widget.textColor.withOpacity(0.8),
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(width: 8),

            // 🔁 Speed toggle
            InkWell(
              onTap: () {
                setState(() {
                  if (_speed == 1.0)
                    _speed = 1.5;
                  else if (_speed == 1.5)
                    _speed = 2.0;
                  else
                    _speed = 1.0;
                  _player.setSpeed(_speed);
                });
              },
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${_speed.toStringAsFixed(1)}x',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final double value;
  final double progress;
  final Color accentColor;
  final List<double> baseHeights;

  _WaveformPainter({
    required this.value,
    required this.progress,
    required this.accentColor,
    required this.baseHeights,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round;

    final totalBars = baseHeights.length;
    final barWidth = size.width / (totalBars * 1.5);
    final gap = barWidth * 0.5;

    for (int i = 0; i < totalBars; i++) {
      final x = i * (barWidth + gap);
      final baseHeight = baseHeights[i];
      final animHeight = baseHeight + sin((value * pi * 2) + i) * 4;
      final barHeight = animHeight.clamp(4, 28);

      final progressRatio = (i / totalBars);
      final isPlayed = progressRatio < progress;

      paint.color = isPlayed
          ? accentColor.withOpacity(0.95)
          : accentColor.withOpacity(0.35);

      final y = (size.height - barHeight) / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, barHeight.toDouble()),
          const Radius.circular(3),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter oldDelegate) {
    return oldDelegate.value != value || oldDelegate.progress != progress;
  }
}
