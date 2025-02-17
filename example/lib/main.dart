import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:record_example/audio_player.dart';

class AudioRecorder extends StatefulWidget {
  const AudioRecorder({required this.path, required this.onStop});
  final String path;
  final VoidCallback onStop;

  @override
  _AudioRecorderState createState() => _AudioRecorderState();
}

class _AudioRecorderState extends State<AudioRecorder> {
  bool _isRecording = false;
  bool _isPaused = false;
  int _recordDuration = 0;
  Timer? _timer;

  ///声音分贝
  final ValueNotifier<double> _volumedB = ValueNotifier<double>(0);

  @override
  void initState() {
    _isRecording = false;
    super.initState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _volumedB.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              _buildDbListener(),
              const SizedBox(width: 20),
              _buildRecordStopControl(),
              const SizedBox(width: 20),
              _buildPauseResumeControl(),
              const SizedBox(width: 20),
              _buildText(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDbListener() {
    return ValueListenableBuilder<double>(
      valueListenable: _volumedB,
      builder: (_, double volume, __) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          curve: Curves.ease,
          width: 5,
          height: volume,
          color: Colors.blue,
        );
      },
    );
  }

  Widget _buildRecordStopControl() {
    late Icon icon;
    late Color color;

    if (_isRecording || _isPaused) {
      icon = const Icon(Icons.stop, color: Colors.red, size: 30);
      color = Colors.red.withOpacity(0.1);
    } else {
      final ThemeData theme = Theme.of(context);
      icon = Icon(Icons.mic, color: theme.primaryColor, size: 30);
      color = theme.primaryColor.withOpacity(0.1);
    }

    return ClipOval(
      child: Material(
        color: color,
        child: InkWell(
          child: SizedBox(width: 56, height: 56, child: icon),
          onTap: () {
            _isRecording ? _stop() : _start();
          },
        ),
      ),
    );
  }

  Widget _buildPauseResumeControl() {
    if (!_isRecording && !_isPaused) {
      return const SizedBox.shrink();
    }

    late Icon icon;
    late Color color;

    if (!_isPaused) {
      icon = const Icon(Icons.pause, color: Colors.red, size: 30);
      color = Colors.red.withOpacity(0.1);
    } else {
      final ThemeData theme = Theme.of(context);
      icon = const Icon(Icons.play_arrow, color: Colors.red, size: 30);
      color = theme.primaryColor.withOpacity(0.1);
    }

    return ClipOval(
      child: Material(
        color: color,
        child: InkWell(
          child: SizedBox(width: 56, height: 56, child: icon),
          onTap: () {
            _isPaused ? _resume() : _pause();
          },
        ),
      ),
    );
  }

  Widget _buildText() {
    if (_isRecording || _isPaused) {
      return _buildTimer();
    }

    return const Text('Waiting to record');
  }

  Widget _buildTimer() {
    final String minutes = _formatNumber(_recordDuration ~/ 60);
    final String seconds = _formatNumber(_recordDuration % 60);

    return Text(
      '$minutes : $seconds',
      style: const TextStyle(color: Colors.red),
    );
  }

  String _formatNumber(int number) {
    String numberStr = number.toString();
    if (number < 10) {
      numberStr = '0' + numberStr;
    }

    return numberStr;
  }

  Future<void> _start() async {
    try {
      if (await Record.hasPermission()) {
        await Record.start(
            path: widget.path,
            onDecibelChange: (double volume) {
              print('db:$volume');
              _volumedB.value = volume;
            });

        final bool isRecording = await Record.isRecording();
        setState(() {
          _isRecording = isRecording;
          _recordDuration = 0;
        });

        _startTimer();
      }
    } catch (e) {
      print(e);
    }
  }

  Future<void> _stop() async {
    _timer?.cancel();
    await Record.stop();

    setState(() => _isRecording = false);

    widget.onStop();
  }

  Future<void> _pause() async {
    _timer?.cancel();
    await Record.pause();

    setState(() => _isPaused = true);
  }

  Future<void> _resume() async {
    _startTimer();
    await Record.resume();

    setState(() => _isPaused = false);
  }

  void _startTimer() {
    const Duration tick = Duration(seconds: 1);

    _timer?.cancel();

    _timer = Timer.periodic(tick, (Timer t) {
      setState(() => _recordDuration++);
    });
  }
}

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool showPlayer = false;
  String? path;

  @override
  void initState() {
    showPlayer = false;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: FutureBuilder<String>(
            future: getPath(),
            builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
              if (snapshot.hasData) {
                if (showPlayer) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25),
                    child: AudioPlayer(
                      path: snapshot.data!,
                      onDelete: () {
                        setState(() => showPlayer = false);
                      },
                    ),
                  );
                } else {
                  return AudioRecorder(
                    path: snapshot.data!,
                    onStop: () {
                      setState(() => showPlayer = true);
                    },
                  );
                }
              } else {
                return const Center(child: CircularProgressIndicator());
              }
            },
          ),
        ),
      ),
    );
  }

  Future<String> getPath() async {
    if (path == null) {
      final Directory dir = await getApplicationDocumentsDirectory();
      path = dir.path + '/' + DateTime.now().millisecondsSinceEpoch.toString() + '.m4a';
    }
    return path!;
  }
}
