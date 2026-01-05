// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

/// Generates simple WAV audio files for workout feedback sounds.
/// Run with: dart run tool/generate_audio.dart
void main() {
  final audioDir = Directory('assets/audio');
  if (!audioDir.existsSync()) {
    audioDir.createSync(recursive: true);
  }

  // Generate different sounds for each feedback type
  generateTone('assets/audio/rep_complete.wav', 880, 0.15); // A5 - short high beep
  generateTone('assets/audio/invalid_rep.wav', 220, 0.2); // A3 - lower buzz
  generateTone('assets/audio/countdown.wav', 660, 0.1); // E5 - quick tick
  generateTone('assets/audio/workout_start.wav', 523, 0.3); // C5 - medium tone
  generateTone('assets/audio/workout_complete.wav', 1047, 0.5); // C6 - celebration high
  generateTone('assets/audio/goal_reached.wav', 1175, 0.4); // D6 - success chime

  print('Audio files generated successfully in assets/audio/');
}

/// Generate a simple sine wave tone WAV file
void generateTone(String path, double frequency, double durationSeconds) {
  const sampleRate = 44100;
  const bitsPerSample = 16;
  const numChannels = 1;

  // ignore: prefer_const_declarations
  final numSamples = (sampleRate * durationSeconds).round();
  final samples = Int16List(numSamples);

  // Generate sine wave with fade in/out to avoid clicks
  for (int i = 0; i < numSamples; i++) {
    final t = i / sampleRate;
    const amplitude = 0.5 * 32767; // 50% volume

    // Apply envelope (fade in first 10%, fade out last 10%)
    double envelope = 1.0;
    final fadeLength = numSamples * 0.1;
    if (i < fadeLength) {
      envelope = i / fadeLength;
    } else if (i > numSamples - fadeLength) {
      envelope = (numSamples - i) / fadeLength;
    }

    samples[i] = (amplitude * envelope * sin(2 * pi * frequency * t)).round();
  }

  // Build WAV file
  final dataSize = numSamples * (bitsPerSample ~/ 8);
  final fileSize = 36 + dataSize;

  final buffer = ByteData(44 + dataSize);
  var offset = 0;

  // RIFF header
  buffer.setUint8(offset++, 0x52); // 'R'
  buffer.setUint8(offset++, 0x49); // 'I'
  buffer.setUint8(offset++, 0x46); // 'F'
  buffer.setUint8(offset++, 0x46); // 'F'
  buffer.setUint32(offset, fileSize, Endian.little);
  offset += 4;
  buffer.setUint8(offset++, 0x57); // 'W'
  buffer.setUint8(offset++, 0x41); // 'A'
  buffer.setUint8(offset++, 0x56); // 'V'
  buffer.setUint8(offset++, 0x45); // 'E'

  // fmt chunk
  buffer.setUint8(offset++, 0x66); // 'f'
  buffer.setUint8(offset++, 0x6D); // 'm'
  buffer.setUint8(offset++, 0x74); // 't'
  buffer.setUint8(offset++, 0x20); // ' '
  buffer.setUint32(offset, 16, Endian.little); // Subchunk1Size
  offset += 4;
  buffer.setUint16(offset, 1, Endian.little); // AudioFormat (PCM)
  offset += 2;
  buffer.setUint16(offset, numChannels, Endian.little);
  offset += 2;
  buffer.setUint32(offset, sampleRate, Endian.little);
  offset += 4;
  buffer.setUint32(offset, sampleRate * numChannels * (bitsPerSample ~/ 8), Endian.little); // ByteRate
  offset += 4;
  buffer.setUint16(offset, numChannels * (bitsPerSample ~/ 8), Endian.little); // BlockAlign
  offset += 2;
  buffer.setUint16(offset, bitsPerSample, Endian.little);
  offset += 2;

  // data chunk
  buffer.setUint8(offset++, 0x64); // 'd'
  buffer.setUint8(offset++, 0x61); // 'a'
  buffer.setUint8(offset++, 0x74); // 't'
  buffer.setUint8(offset++, 0x61); // 'a'
  buffer.setUint32(offset, dataSize, Endian.little);
  offset += 4;

  // Sample data
  for (int i = 0; i < numSamples; i++) {
    buffer.setInt16(offset, samples[i], Endian.little);
    offset += 2;
  }

  // Write file
  final file = File(path);
  file.writeAsBytesSync(buffer.buffer.asUint8List());
  print('Generated: $path (${frequency.round()}Hz, ${durationSeconds}s)');
}
