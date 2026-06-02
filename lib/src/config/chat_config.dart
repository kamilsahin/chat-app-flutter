import 'dart:convert';
import 'chat_theme.dart';

class ChatConfig {
  final String serverUrl;
  final String jwtToken;

  /// FCM token from firebase_messaging. If provided, the package registers
  /// it with the backend so push notifications can be delivered.
  final String? fcmToken;

  /// Visual theme. Defaults to [ChatTheme.dark] if not provided.
  final ChatTheme theme;

  /// Bir DIRECT sohbette karşı kullanıcının avatarına/appbar'ına tıklanınca
  /// çağrılır. Host uygulama (ActiZone) bu kullanıcının profiline yönlendirir.
  /// externalId = sohbetteki karşı kişinin kullanıcı ID'si.
  final void Function(String externalId)? onUserProfileTap;

  const ChatConfig({
    required this.serverUrl,
    required this.jwtToken,
    this.fcmToken,
    this.theme = const ChatTheme.dark(),
    this.onUserProfileTap,
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
      return map['sub'] as String? ?? map['id'] as String? ?? jwtToken;
    } catch (_) {
      return jwtToken;
    }
  }
}
