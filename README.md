# chat_app_flutter

A Flutter package that embeds a real-time chat UI into any existing app. Connects to the **[chat-app](https://github.com/kamilsahin/chat-app)** Spring Boot backend over WebSocket/STOMP.

> **This package is one half of an open-source chat system.**
> - **Flutter package (this)** — drop-in chat UI for your Flutter app
> - **Spring Boot backend** — [github.com/kamilsahin/chat-app](https://github.com/kamilsahin/chat-app) — REST + WebSocket/STOMP server with MongoDB, JWT auth, FCM push notifications, and an Internal API for room management

Both projects are open-source and designed to work together. You can self-host the backend and plug this package into any Flutter app.

## Features

### Messaging
- Real-time messaging via WebSocket (STOMP over SockJS)
- Own messages right-aligned, others left-aligned
- Deleted message placeholder ("Mesaj silindi")
- Pinned message support

### Room List
- Last message preview and timestamp
- Unread count badge (green for normal, grey for muted)
- Pull-to-refresh
- Rooms sorted by latest activity

### Reply
- Reply to any message with a preview bar above the input field
- Replied message shown as a quoted block inside the bubble
- Tap the quoted block to scroll to and highlight the original message

### Emoji Reactions
- Long-press a bubble to open emoji picker (6 emojis: 👍 ❤️ 😂 😮 😢 🔥)
- Already-selected emoji highlighted with a green ring
- Reactions shown as tappable chips at the bottom-right of the bubble
- Own reaction highlighted with a green border on the chip

### Photo Sharing
- Send photos from gallery or camera via the image button in the input bar
- Images displayed as inline thumbnails inside the bubble
- Tap to open full-screen viewer with pinch-to-zoom (`InteractiveViewer`)

### Message Actions (long-press)
- **Copy** — copies text content to clipboard
- **Reply** — opens the reply bar pre-filled with the original message
- **Edit** — opens an edit dialog (own text messages only); broadcasts update to all participants
- **Delete** — soft-deletes with confirmation; replaced by "Bu mesaj silindi" placeholder for everyone

### Mute / Unmute
- Long-press a room tile to open the mute sheet
- Duration options: 1 hour, 8 hours, 1 week, permanent
- Muted rooms show a bell-off icon next to the name
- Optimistic local state update — no re-fetch needed

### Unread Count
- Badge cleared automatically when entering or leaving a room
- Own sent messages never increment the unread counter
- Messages received while a room is open do not increment the counter

### Push Notifications (FCM)
- Opt-in: pass an `fcmToken` in `ChatConfig` and the package registers it automatically
- Your app handles Firebase initialization and token retrieval (`firebase_messaging`); the package has no Firebase dependency
- Backend sends FCM push when a new message arrives (text or photo)
- Skips notification for the sender and for muted members (respects mute duration)
- Stale/unregistered tokens are cleaned up automatically
- Enable on the backend: set `chat.notifications.enabled=true` and `chat.notifications.fcm.credentials-file` to your service-account JSON path

### Other
- Auto-scroll to latest message on send
- Typing indicators in room app bar
- JWT-based auth — your app issues the token, this package just uses it
- Easily embedded as a path or git dependency

## Getting started

### 1. Backend

Clone and run the [chat-app](https://github.com/kamilsahin/chat-app) Spring Boot backend. Copy `.env.example` to `.env` and set your values:

```
CHAT_JWT_SECRET=SecretKeyToGenJWTs
CHAT_INTERNAL_SECRET=dev-internal-secret
```

Start with Docker Compose:

```bash
docker-compose up
```

The server runs on `http://localhost:8081` by default.

### 2. Create a room

Rooms are managed via the Internal API (backend-to-backend). Create a direct room with:

```bash
curl -X POST http://localhost:8081/internal/rooms \
  -H "Content-Type: application/json" \
  -H "X-Internal-Secret: dev-internal-secret" \
  -d '{
    "type": "DIRECT",
    "memberIds": ["user1", "user2"],
    "name": "Test Room"
  }'
```

### 3. Generate a test JWT

Go to [jwt.io](https://jwt.io) and fill in:

| Field | Value |
|-------|-------|
| Algorithm | `HS256` |
| Payload | `{ "sub": "user1" }` |
| Secret | `dev-secret-key-for-chat-app-minimum-32chars` |

Copy the encoded token from the left panel. Generate a second token with `"sub": "user2"` for the other user.

> The `sub` claim becomes the user's ID inside the chat system.

### 4. Add the dependency

```yaml
# pubspec.yaml
dependencies:
  chat_app_flutter:
    path: ../chat-app-flutter   # or use a git: reference
```

## Usage

Wrap the chat UI with `ChatApp.initialize()` once after login, passing the server URL and the JWT token issued by your app:

```dart
import 'package:chat_app_flutter/chat_app_flutter.dart';

// After login — wrap the subtree that needs chat
Widget chatWidget = ChatApp.initialize(
  config: ChatConfig(
    serverUrl: 'http://10.0.2.2:8081', // use your server URL
    jwtToken: yourJwtToken,
  ),
  child: const RoomListScreen(),
);
```

Navigate to `RoomScreen` for a specific room:

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => UncontrolledProviderScope(
      container: ProviderScope.containerOf(context),
      child: RoomScreen(roomId: roomId),
    ),
  ),
);
```

> `UncontrolledProviderScope` is required so the new route inherits the nested
> provider scope created by `ChatApp.initialize()`.

### Android emulator

When testing on an Android emulator, use `10.0.2.2` instead of `localhost` to
reach your host machine:

```dart
serverUrl: 'http://10.0.2.2:8081'
```

## Example app

See the `example/` directory for a full working demo with a login screen that
accepts a server URL and JWT token.

```bash
cd example
flutter run
```

## Architecture

| Layer | Technology |
|-------|-----------|
| State management | Riverpod (nested `ProviderScope`) |
| HTTP client | Dio |
| WebSocket | STOMP over SockJS (`stomp_dart_client`) |
| Backend | Spring Boot 3 + MongoDB |
