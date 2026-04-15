import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../services/stomp_service.dart';
import 'config_provider.dart';

final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService(ref.watch(chatConfigProvider));
});

final stompServiceProvider = Provider<StompService>((ref) {
  final service = StompService(ref.watch(chatConfigProvider));
  ref.onDispose(service.disconnect);
  return service;
});
