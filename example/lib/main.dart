import 'package:chat_app_flutter/chat_app_flutter.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Sabitleri buraya yaz ───────────────────────────────────────────────────
// Must match JWT_SECRET in chat-app backend .env
const _chatSecret = 'actizone-chat-secret-2026-minimum-32-chars-ok';

// Android emulator → 10.0.2.2, gerçek cihaz → bilgisayarın local IP'si
const _defaultServer = 'http://10.0.2.2:8081';
// ──────────────────────────────────────────────────────────────────────────

void main() {
  runApp(const ProviderScope(child: ExampleApp()));
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chat Test',
      theme: ThemeData.dark(),
      home: const LoginScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _serverCtrl = TextEditingController(text: _defaultServer);
  final _userIdCtrl = TextEditingController();

  String _generateToken(String userId) {
    final jwt = JWT({'sub': userId});
    return jwt.sign(
      SecretKey(_chatSecret),
      algorithm: JWTAlgorithm.HS256,
      expiresIn: const Duration(days: 30),
    );
  }

  void _connect() {
    final server = _serverCtrl.text.trim();
    final userId = _userIdCtrl.text.trim();

    if (server.isEmpty || userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Server URL ve kullanıcı ID zorunlu')),
      );
      return;
    }

    final token = _generateToken(userId);
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
                'Chat Test',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              const SizedBox(height: 40),
              _label('Server URL'),
              const SizedBox(height: 6),
              _field(_serverCtrl, _defaultServer),
              const SizedBox(height: 16),
              _label('Kullanıcı ID'),
              const SizedBox(height: 6),
              _field(_userIdCtrl, '4744'),
              const SizedBox(height: 4),
              const Text(
                'JWT otomatik üretilir — secret: actizone-chat-secret-2026-...',
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
                child: const Text('Bağlan',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(
          color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500));

  Widget _field(TextEditingController c, String hint) => TextField(
        controller: c,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
          filled: true,
          fillColor: const Color(0xFF1E1E1E),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      );
}

class ChatHome extends ConsumerWidget {
  const ChatHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const RoomListScreen();
  }
}
