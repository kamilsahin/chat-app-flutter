import 'dart:convert';

class ChatConfig {
  final String serverUrl;
  final String jwtToken;

  const ChatConfig({
    required this.serverUrl,
    required this.jwtToken,
  });

  String get wsUrl => serverUrl.replaceFirst(RegExp(r'^http'), 'ws');
  String get apiUrl => serverUrl;

  /// The user's ID — extracted from the JWT's `sub` claim.
  /// Matches the `senderId` stored on messages by the backend.
  String get userId {
    try {
      final parts = jwtToken.split('.');
      if (parts.length != 3) return jwtToken;
      // Base64url-decode the payload (pad if necessary)
      final payload = base64Url.normalize(parts[1]);
      final decoded = utf8.decode(base64Url.decode(payload));
      final map = jsonDecode(decoded) as Map<String, dynamic>;
      return map['sub'] as String? ?? jwtToken;
    } catch (_) {
      return jwtToken;
    }
  }
}
