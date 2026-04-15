import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chat_app_flutter/chat_app_flutter.dart';

void main() {
  runApp(const ProviderScope(child: ExampleApp()));
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chat Example',
      theme: ThemeData.dark(),
      home: const LoginScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// ---------------------------------------------------------------------------
// Login Screen — JWT token ve server URL gir, chat'e bağlan
// ---------------------------------------------------------------------------
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _serverController = TextEditingController(
    // Android emulator: 10.0.2.2 → host machine's localhost
    // Real device: use your computer's local IP (e.g. 192.168.1.x)
    text: 'http://10.0.2.2:8081',
  );
  final _tokenController = TextEditingController();

  void _connect() {
    final server = _serverController.text.trim();
    final token = _tokenController.text.trim();

    if (server.isEmpty || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Server URL ve token zorunlu')),
      );
      return;
    }

    final config = ChatConfig(serverUrl: server, jwtToken: token);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ChatApp.initialize(
          config: config,
          child: const ChatHome(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.chat_bubble_outline,
                  size: 64, color: Color(0xFF4CAF50)),
              const SizedBox(height: 24),
              const Text(
                'Chat App',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 40),
              _label('Server URL'),
              const SizedBox(height: 6),
              _field(_serverController, 'http://localhost:8081'),
              const SizedBox(height: 16),
              _label('JWT Token'),
              const SizedBox(height: 6),
              _field(_tokenController, 'jwt.io\'dan üret', maxLines: 4),
              const SizedBox(height: 8),
              const Text(
                'jwt.io → HS256 → sub: "user1" → secret: dev-secret-key-for-chat-app-minimum-32chars',
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _connect,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'Bağlan',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w500),
      );

  Widget _field(TextEditingController c, String hint, {int maxLines = 1}) =>
      TextField(
        controller: c,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
          filled: true,
          fillColor: const Color(0xFF1E1E1E),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      );
}

// ---------------------------------------------------------------------------
// Chat Home — RoomListScreen'i ProviderScope içinde çalıştırır
// ---------------------------------------------------------------------------
class ChatHome extends ConsumerWidget {
  const ChatHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const RoomListScreen();
  }
}
