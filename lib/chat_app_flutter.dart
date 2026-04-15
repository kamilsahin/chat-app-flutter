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

class ChatApp {
  ChatApp._();

  /// Host app calls this once after login.
  /// Wraps the subtree with required providers.
  static Widget initialize({
    required ChatConfig config,
    required Widget child,
  }) {
    return ProviderScope(
      overrides: [
        chatConfigProvider.overrideWithValue(config),
      ],
      child: child,
    );
  }
}
