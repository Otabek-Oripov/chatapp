// custom_audio_bubble.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class CustomAudioBubble extends StatefulWidget {
  final String audioUrl;
  final bool isMe;
  final Color bubbleColor;
  final Color textColor;
  final Color accentColor;
  final String uniqueId; // Yangi: har bir bubble uchun unikal ID

  const CustomAudioBubble({
    required this.audioUrl,
    required this.isMe,
    required this.bubbleColor,
    required this.textColor,
    required this.accentColor,
    required this.uniqueId,
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
  bool _isLoading = true;
  bool _hasError = false;
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
    _initPlayer(); // Faqat bir marta
  }

  Future<void> _initPlayer() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      await _player.setUrl(widget.audioUrl);
      _duration = _player.duration ?? Duration.zero;

      // Duration stream
      _player.durationStream.listen((dur) {
        if (!mounted || dur == null) return;
        setState(() => _duration = dur);
      });

      // Position stream
      _player.positionStream.listen((pos) {
        if (!mounted) return;
        setState(() => _position = pos);
      });

      // Player state stream
      _player.playerStateStream.listen((state) {
        if (!mounted) return;

        final playing = state.playing;
        final completed = state.processingState == ProcessingState.completed;

        setState(() {
          _isPlaying = playing && !completed;
        });

        if (completed) {
          _player.pause();
          _player.seek(Duration.zero);
          _waveController.stop();
          setState(() => _position = Duration.zero);
        } else if (playing) {
          _waveController.repeat(reverse: true);
        } else {
          _waveController.stop();
        }
      });

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Audio load error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  void didUpdateWidget(covariant CustomAudioBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Faqat URL o'zgarsa qayta yuklash
    if (oldWidget.audioUrl != widget.audioUrl) {
      _player.stop();
      _initPlayer();
    }
  }

  @override
  void dispose() {
    _player.stop();
    _waveController.stop();
    _waveController.dispose();
    _player.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
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
            // Play / Pause
            InkWell(
              onTap: _isLoading || _hasError
                  ? null
                  : () async {
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
                child: _isLoading
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : _hasError
                    ? const Icon(Icons.error, color: Colors.red, size: 20)
                    : Icon(
                  _isPlaying ? Icons.pause : Icons.play_arrow,
                  color: widget.accentColor,
                  size: 28,
                ),
              ),
            ),

            const SizedBox(width: 10),

            // Waveform
            Expanded(
              child: AnimatedBuilder(
                animation: _waveController,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _WaveformPainter(
                      value: _waveController.value,
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

            // Duration
            Text(
              _formatDuration(_duration),
              style: TextStyle(
                fontSize: 12,
                color: widget.textColor.withOpacity(0.8),
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(width: 8),

            // Speed
            InkWell(
              onTap: _isLoading || _hasError
                  ? null
                  : () {
                setState(() {
                  _speed = _speed == 1.0 ? 1.5 : _speed == 1.5 ? 2.0 : 1.0;
                  _player.setSpeed(_speed);
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${_speed.toStringAsFixed(1)}x',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
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
      final barHeight = animHeight.clamp(4.0, 28.0);

      final isPlayed = (i / totalBars) < progress;

      paint.color = isPlayed
          ? accentColor.withOpacity(0.95)
          : accentColor.withOpacity(0.35);

      final y = (size.height - barHeight) / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, barHeight),
          const Radius.circular(3),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}