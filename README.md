# chat_app_flutter

A Flutter package that embeds a real-time chat UI into any existing app. Connects to the [chat-app](https://github.com/kamilsahin/chat-app) Spring Boot backend over WebSocket/STOMP.

## Features

- Real-time messaging via WebSocket (STOMP over SockJS)
- Room list with last message preview and unread count badge
- Message bubbles with reply and emoji reaction support
- Typing indicators
- JWT-based auth — your app issues the token, this package just uses it
- Easily embedded as a path or git dependency

## Getting started

### 1. Backend

Clone and run the [chat-app](https://github.com/kamilsahin/chat-app) Spring Boot backend. Copy `.env.example` to `.env` and set your values:

```
CHAT_JWT_SECRET=dev-secret-key-for-chat-app-minimum-32chars
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
