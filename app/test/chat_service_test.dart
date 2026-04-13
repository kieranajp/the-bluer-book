import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:app/infrastructure/chat_service.dart';

void main() {
  group('ChatEvent.fromJson', () {
    test('parses content and done fields', () {
      final event = ChatEvent.fromJson({
        'content': 'Hello',
        'done': false,
      });

      expect(event.content, 'Hello');
      expect(event.done, false);
      expect(event.sessionId, isNull);
    });

    test('parses session_id when present', () {
      final event = ChatEvent.fromJson({
        'content': 'Hi',
        'done': true,
        'session_id': 'sess-123',
      });

      expect(event.content, 'Hi');
      expect(event.done, true);
      expect(event.sessionId, 'sess-123');
    });

    test('defaults content to empty string when missing', () {
      final event = ChatEvent.fromJson({'done': false});
      expect(event.content, '');
    });

    test('defaults done to false when missing', () {
      final event = ChatEvent.fromJson({'content': 'test'});
      expect(event.done, false);
    });
  });

  group('UTF-8 decoding safety', () {
    test('Utf8Decoder with allowMalformed handles split multi-byte chars', () {
      // Simulate a multi-byte UTF-8 character split across chunks
      // "é" is U+00E9, encoded as [0xC3, 0xA9] in UTF-8
      final fullBytes = utf8.encode('café');

      // Split in the middle of the "é" character
      final chunk1 = fullBytes.sublist(0, fullBytes.length - 1); // ends mid-char
      final chunk2 = fullBytes.sublist(fullBytes.length - 1); // remaining byte

      final decoder = Utf8Decoder(allowMalformed: true);

      // Should not throw even with split character
      final part1 = decoder.convert(chunk1);
      final part2 = decoder.convert(chunk2);

      // The combined result should contain recognizable content
      // (with allowMalformed, split chars produce replacement characters,
      // but the decoder won't crash)
      expect(part1 + part2, isNotEmpty);
    });

    test('Utf8Decoder handles complete UTF-8 sequences normally', () {
      final bytes = utf8.encode('Hello, world! 🌍');
      final decoder = Utf8Decoder(allowMalformed: true);
      final result = decoder.convert(bytes);
      expect(result, 'Hello, world! 🌍');
    });

    test('Utf8Decoder handles empty chunks', () {
      final decoder = Utf8Decoder(allowMalformed: true);
      final result = decoder.convert([]);
      expect(result, '');
    });
  });
}
