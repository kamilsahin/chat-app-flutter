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
  Future<List<Room>> getRooms({String? type}) async {
    final res = await _dio.get('/api/rooms',
        queryParameters: type != null ? {'type': type} : null);
    return (res.data as List).map((r) => Room.fromJson(r)).toList();
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

  Future<Message> sendImageMessage(String roomId, String filePath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });
    final res = await _dio.post(
      '/api/rooms/$roomId/messages/image',
      data: formData,
    );
    return Message.fromJson(res.data);
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
