## 0.1.2

- Fix: "Tried to read a provider from a ProviderContainer that was already disposed" — `_container` nulled before microtask fires, callbacks now null-safe
- Fix: `muteRoom` sent ISO-8601 strings but backend expects enum values (`HOURS_1`, `HOURS_8`, `WEEK_1`, `INDEFINITE`) — mapping added in `ApiService`

## 0.1.1

- Fix: provider mutation in `dispose()` caused "Tried to modify a provider while the widget tree was building" error — deferred via `Future.microtask`
- Fix: typing indicator timer firing after widget disposal caused "Cannot use ref after widget was disposed" error — switched to `_container` reference

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
