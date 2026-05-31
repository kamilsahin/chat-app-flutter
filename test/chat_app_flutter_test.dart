import 'package:chat_app_flutter/chat_app_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChatConfig', () {
    test('extracts userId from JWT sub claim', () {
      // Header: {"alg":"HS256","typ":"JWT"}
      // Payload: {"sub":"user123"}
      const token =
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'
          '.eyJzdWIiOiJ1c2VyMTIzIn0'
          '.signature';
      final config = ChatConfig(serverUrl: 'http://localhost:8081', jwtToken: token);
      expect(config.userId, 'user123');
    });

    test('falls back to raw token when JWT is malformed', () {
      const token = 'not-a-jwt';
      final config = ChatConfig(serverUrl: 'http://localhost:8081', jwtToken: token);
      expect(config.userId, token);
    });

    test('wsUrl replaces http with ws', () {
      final config = ChatConfig(serverUrl: 'http://localhost:8081', jwtToken: 'tok');
      expect(config.wsUrl, 'ws://localhost:8081');
    });

    test('wsUrl replaces https with wss', () {
      final config = ChatConfig(serverUrl: 'https://example.com', jwtToken: 'tok');
      expect(config.wsUrl, 'wss://example.com');
    });
  });
}
