import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:io';

class AudioService {
  final AudioPlayer _player = AudioPlayer();
  bool _isRecording = false;
  String? _currentRecordingPath;

  bool get isRecording => _isRecording;
  String? get currentRecordingPath => _currentRecordingPath;

  Future<bool> startRecording() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final fileName = 'audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
      _currentRecordingPath = '${dir.path}/$fileName';
      _isRecording = true;
      return true;
    } catch (e) {
      print('Error starting recording: $e');
      return false;
    }
  }

  Future<String?> stopRecording() async {
    try {
      _isRecording = false;
      return _currentRecordingPath;
    } catch (e) {
      print('Error stopping recording: $e');
      _isRecording = false;
      return null;
    }
  }

  Future<void> playAudio(String filePath) async {
    try {
      await _player.play(DeviceFileSource(filePath));
    } catch (e) {
      print('Error playing audio: $e');
    }
  }

  Future<void> stopPlayback() async {
    try {
      await _player.stop();
    } catch (e) {
      print('Error stopping playback: $e');
    }
  }

  Future<void> deleteAudio(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print('Error deleting audio: $e');
    }
  }

  void dispose() {
    _player.dispose();
  }
}
