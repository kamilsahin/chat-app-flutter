export 'src/config/chat_config.dart';
export 'src/screens/room_list/room_list_screen.dart';
export 'src/screens/room/room_screen.dart';
export 'src/models/room.dart';
export 'src/models/message.dart';
export 'src/models/chat_user.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'src/config/chat_config.dart';
import 'src/providers/config_provider.dart';
import 'src/providers/service_providers.dart';

class ChatApp {
  ChatApp._();

  /// Host app calls this once after login.
  /// Pass [ChatConfig.fcmToken] (from firebase_messaging) to enable push
  /// notifications — the package registers the token with the backend.
  static Widget initialize({
    required ChatConfig config,
    required Widget child,
  }) {
    return ProviderScope(
      overrides: [
        chatConfigProvider.overrideWithValue(config),
      ],
      child: _ChatInitWidget(child: child),
    );
  }
}

class _ChatInitWidget extends ConsumerStatefulWidget {
  final Widget child;
  const _ChatInitWidget({required this.child});

  @override
  ConsumerState<_ChatInitWidget> createState() => _ChatInitWidgetState();
}

class _ChatInitWidgetState extends ConsumerState<_ChatInitWidget> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final config = ref.read(chatConfigProvider);
      if (config.fcmToken != null) {
        ref.read(apiServiceProvider).updateFcmToken(config.fcmToken!).ignore();
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
