import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class AudioPlayerSheet extends StatefulWidget {
  final String audioUrl;
  final String? suraName;
  final int? ayaNumber;

  final VoidCallback? onPlaySequential;

  const AudioPlayerSheet({
    super.key,
    required this.audioUrl,
    this.suraName,
    this.ayaNumber,
    this.onPlaySequential,
  });

  @override
  State<AudioPlayerSheet> createState() => _AudioPlayerSheetState();
}

class _AudioPlayerSheetState extends State<AudioPlayerSheet> {
  late AudioPlayer _player;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _initAudio();
  }

  Future<void> _initAudio() async {
    try {
      await _player.setUrl(widget.audioUrl);
      _player.play();
    } catch (e) {
      debugPrint("Error loading audio: $e");
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 30),

            // Sura & Aya Info
            if (widget.suraName != null)
              Text(
                "${widget.suraName} - آية ${widget.ayaNumber}",
                style: TextStyle(
                  
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal.shade900,
                ),
              )
            else
              Text(
                "ترتيل الآية الكريمة",
                style: TextStyle(
                  
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal.shade900,
                ),
              ),

            const SizedBox(height: 30),

            // Progress Slider
            StreamBuilder<Duration>(
              stream: _player.positionStream,
              builder: (context, snapshot) {
                final position = snapshot.data ?? Duration.zero;
                final duration = _player.duration ?? Duration.zero;

                return Column(
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 4,
                        thumbShape:
                            const RoundSliderThumbShape(enabledThumbRadius: 8),
                        activeTrackColor: const Color(0xFF00695C),
                        inactiveTrackColor: Colors.teal.shade50,
                        thumbColor: const Color(0xFF00695C),
                        overlayColor: const Color(0xFF00695C).withOpacity(0.2),
                      ),
                      child: Slider(
                        value: position.inSeconds
                            .toDouble()
                            .clamp(0, duration.inSeconds.toDouble() + 1),
                        min: 0,
                        max: duration.inSeconds.toDouble() > 0
                            ? duration.inSeconds.toDouble()
                            : 1,
                        onChanged: (value) {
                          _player.seek(Duration(seconds: value.toInt()));
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildTimeText(position),
                          _buildTimeText(duration),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 30),

            // Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildSmallButton(Icons.replay_10_rounded, () {
                  final newPos = _player.position - const Duration(seconds: 10);
                  _player.seek(newPos < Duration.zero ? Duration.zero : newPos);
                }),
                const SizedBox(width: 30),
                StreamBuilder<PlayerState>(
                  stream: _player.playerStateStream,
                  builder: (context, snapshot) {
                    final playerState = snapshot.data;
                    final processingState = playerState?.processingState;
                    final playing = playerState?.playing ?? false;

                    if (processingState == ProcessingState.loading ||
                        processingState == ProcessingState.buffering) {
                      return Container(
                        width: 70,
                        height: 70,
                        padding: const EdgeInsets.all(16),
                        child: const CircularProgressIndicator(
                          color: Color(0xFF00695C),
                          strokeWidth: 3,
                        ),
                      );
                    }

                    return Container(
                      width: 76,
                      height: 76,
                      decoration: const BoxDecoration(
                        color: Color(0xFF00695C),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x4400695C),
                            blurRadius: 15,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: Icon(
                          playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          size: 45,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          if (playing) {
                            _player.pause();
                          } else {
                            if (processingState == ProcessingState.completed) {
                              _player.seek(Duration.zero);
                            }
                            _player.play();
                          }
                        },
                      ),
                    );
                  },
                ),
                const SizedBox(width: 30),
                _buildSmallButton(Icons.forward_10_rounded, () {
                  final newPos = _player.position + const Duration(seconds: 10);
                  final duration = _player.duration ?? Duration.zero;
                  _player.seek(newPos > duration ? duration : newPos);
                }),
              ],
            ),
            const SizedBox(height: 30),

            // Sequential Play Button
            if (widget.onPlaySequential != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onPlaySequential!();
                  },
                  icon: const Icon(Icons.playlist_play_rounded),
                  label: const Text(
                    "تشغيل متتابع من هذه الآية",
                    style: TextStyle(
                      
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade50,
                    foregroundColor: const Color(0xFF00695C),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeText(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return Text(
      "$minutes:$seconds",
      style: TextStyle(
        color: Colors.grey.shade600,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildSmallButton(IconData icon, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: const Color(0xFF00695C)),
        onPressed: onTap,
      ),
    );
  }
}
