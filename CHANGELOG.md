## 0.1.8

- Optimistic UI fix: duplicate message flash eliminated — pending message is atomically replaced by the confirmed one in a single state update.

## 0.1.7

- Optimistic UI: sent messages appear instantly on screen before server confirmation, then seamlessly replaced by the confirmed message.

## 0.1.6

- STOMP reconnect: subscriptions are re-established after connection drop; pending callbacks are queued safely.
- App resume: STOMP reconnects immediately when the app comes to foreground instead of waiting for the next retry interval.
- FCM token registration: `ChatConfig.fcmToken` is sent to the backend on init so push notifications work.
- Active room tracking: `ChatApp.setActiveRoom` / `refreshActiveRoom` allow the host app to clear and restore the active room (e.g. when navigating to a profile screen).
- Message list refresh: `MessageListNotifier.refresh()` re-fetches from the API; called on room open and on FCM delivery to recover messages STOMP may have missed.
- `addMessage` works during refresh (`AsyncLoading`) — STOMP messages are no longer lost during a concurrent refresh.
- Typing indicator: self-typing events are filtered out so the sender never sees their own "typing…" indicator.
- Pull-to-refresh: swipe down on the message list to reload from the backend.
- Bug fix: `refresh()` has a 15-second timeout to prevent indefinite hangs on network errors.

## 0.1.5

- Add `DirectChatScreen` — opens a DIRECT chat by the other user's id (find-or-create the room, then show the room). For "message from profile" flows.
- Add `RoomByIdScreen` — opens a chat by `roomId` (fetches the room, then shows it). For notification-tap flows.
- Add `ApiService.createDirectRoom(otherUserId)` and `clearHistory(roomId)`.
- Add `Room.otherUserId` — the other participant in a DIRECT room (populated by the backend), used for profile navigation.
- Add `ChatConfig.onUserProfileTap(externalId)` — tapping a room-list avatar or the room app bar invokes this so the host app can navigate to the user's profile.
- Add `ChatTheme.appBarBackgroundColor` / `appBarForegroundColor` — lets the host brand the top app bar independently of tile/sheet surfaces.
- Clear chat: `RoomListNotifier.clearHistory` removes the room locally; the room list long-press menu gets a "delete chat" action.
- Realtime: subscribe to a per-user channel so a new or previously-cleared conversation surfaces at the top without a manual refresh; add `silentRefresh`.
- Room list now sorts by last activity on every build so incoming messages move a room to the top reliably.
- STOMP client reconnects automatically (`reconnectDelay`).
- Dismiss the keyboard on message-list scroll.

## 0.1.4

- Add `ChatApp.activeRoomId` static getter — exposes the currently open room ID so host apps can suppress in-app notifications for the active room
- Add `ChatApp.notificationColor` static getter — exposes the chat theme primary color for custom notification UI outside the package
- Fix: `catchError` handler in scroll listener now returns a value (lint warning)
- Fix: `prefer_null_aware_operators` in `notificationColor` getter

## 0.1.3

- Fix: remaining `.read()` call on nullable `_container` in image send flow

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
