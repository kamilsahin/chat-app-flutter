class ChatConfig {
  final String serverUrl;
  final String jwtToken;

  const ChatConfig({
    required this.serverUrl,
    required this.jwtToken,
  });

  String get wsUrl => serverUrl.replaceFirst(RegExp(r'^http'), 'ws');
  String get apiUrl => serverUrl;
}
