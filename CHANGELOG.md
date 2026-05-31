## 0.1.0

Initial public release.

- Real-time messaging via WebSocket (STOMP over SockJS)
- Room list with unread count badges, mute support, and pull-to-refresh
- Reply to messages with a quoted preview bar
- Emoji reactions (6 emojis) with long-press picker
- Photo sharing from gallery or camera with full-screen viewer
- Message actions: copy, reply, edit, delete (long-press)
- Push notification support via FCM (opt-in, no Firebase dependency in package)
- Typing indicators in room app bar
- JWT-based auth — host app issues the token, package consumes it
- Riverpod state management with a stable nested `ProviderScope`
- `ChatApp.initialize()` / `ChatApp.reset()` API for easy integration
