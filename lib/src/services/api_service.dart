import 'package:dio/dio.dart';
import '../config/chat_config.dart';
import '../models/room.dart';
import '../models/message.dart';
import '../models/chat_user.dart';

class ApiService {
  late final Dio _dio;

  ApiService(ChatConfig config) {
    _dio = Dio(BaseOptions(
      baseUrl: config.apiUrl,
      headers: {'Authorization': 'Bearer ${config.jwtToken}'},
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));
  }

  // Rooms
  Future<({List<Room> rooms, bool hasNext})> getRooms({
    String? type,
    int page = 0,
    int size = 20,
  }) async {
    final res = await _dio.get('/api/rooms', queryParameters: {
      if (type != null) 'type': type,
      'page': page,
      'size': size,
    });

    final raw = res.data;

    // Paginated response → Map with "content" array
    if (raw is Map<String, dynamic>) {
      final rooms = (raw['content'] as List)
          .map<Room>((r) => Room.fromJson(r as Map<String, dynamic>))
          .toList();
      // Spring Slice: hasNext veya last'tan hesapla
      final hasNext = raw['hasNext'] as bool?
          ?? !(raw['last'] as bool? ?? true);
      return (rooms: rooms, hasNext: hasNext);
    }

    // Fallback: düz liste döndüyse (eski backend)
    if (raw is List) {
      final rooms = raw
          .map<Room>((r) => Room.fromJson(r as Map<String, dynamic>))
          .toList();
      return (rooms: rooms, hasNext: false);
    }

    return (rooms: <Room>[], hasNext: false);
  }

  Future<Room> getRoom(String roomId) async {
    final res = await _dio.get('/api/rooms/$roomId');
    return Room.fromJson(res.data);
  }

  // Messages
  Future<List<Message>> getMessages(String roomId, {String? cursor}) async {
    final res = await _dio.get(
      '/api/rooms/$roomId/messages',
      queryParameters: cursor != null ? {'cursor': cursor} : null,
    );
    return (res.data['content'] as List)
        .map((m) => Message.fromJson(m))
        .toList();
  }

  Future<Message?> getPinnedMessage(String roomId) async {
    try {
      final res = await _dio.get('/api/rooms/$roomId/pin');
      return Message.fromJson(res.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<Message> editMessage(String messageId, String content) async {
    final res = await _dio.patch(
      '/api/messages/$messageId',
      data: {'content': content},
    );
    return Message.fromJson(res.data);
  }

  Future<Message> deleteMessage(String messageId) async {
    final res = await _dio.delete('/api/messages/$messageId');
    return Message.fromJson(res.data);
  }

  /// Marks all messages in the room as read for the current user.
  Future<void> markRoomAsRead(String roomId) async {
    await _dio.post('/api/rooms/$roomId/read');
  }

  // Users
  Future<ChatUser> getUser(String userId) async {
    final res = await _dio.get('/api/users/$userId');
    return ChatUser.fromJson(res.data);
  }

  Future<ChatUser> updateProfile({
    String? displayName,
    String? avatarUrl,
    String? bio,
  }) async {
    final res = await _dio.put('/api/users/me', data: {
      if (displayName != null) 'displayName': displayName,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      if (bio != null) 'bio': bio,
    });
    return ChatUser.fromJson(res.data);
  }

  Future<Message> sendImageMessage(
    String roomId,
    String filePath, {
    String? mimeType,
  }) async {
    final resolvedMime = mimeType ?? _mimeFromPath(filePath);
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        filePath,
        contentType: DioMediaType.parse(resolvedMime),
      ),
    });
    final res = await _dio.post(
      '/api/rooms/$roomId/messages/image',
      data: formData,
      options: Options(sendTimeout: const Duration(seconds: 60)),
    );
    return Message.fromJson(res.data);
  }

  static String _mimeFromPath(String path) {
    final ext = path.split('.').last.toLowerCase();
    return switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'heic' || 'heif' => 'image/heic',
      _ => 'image/jpeg',
    };
  }

  Future<void> updateFcmToken(String token) async {
    await _dio.put('/api/users/me/fcm-token', data: {'token': token});
  }

  // Mute
  /// [duration] — ISO-8601 string e.g. "PT1H", "PT8H", "P7D".
  /// Pass null for permanent (no expiry).
  Future<void> muteRoom(String roomId, {String? duration}) async {
    await _dio.put(
      '/api/rooms/$roomId/mute',
      data: duration != null ? {'duration': duration} : {},
    );
  }

  Future<void> unmuteRoom(String roomId) async {
    await _dio.delete('/api/rooms/$roomId/mute');
  }
}
