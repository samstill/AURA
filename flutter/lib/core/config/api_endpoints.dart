/// Project Aura - API Endpoints
/// =============================
/// Centralized API endpoint definitions.
library;

import 'app_config.dart';

/// API endpoint paths
class ApiEndpoints {
  ApiEndpoints._();
  
  static String get baseUrl => AppConfig.apiBaseUrl;
  
  // Health
  static String get health => '${AppConfig.apiBaseUrl}/health';
  static String get ready => '${AppConfig.apiBaseUrl}/ready';
  
  // Auth
  static String get login => '$baseUrl/auth/login';
  static String get callback => '$baseUrl/auth/callback';
  static String get callbackToken => '$baseUrl/auth/callback/token';
  static String get logout => '$baseUrl/auth/logout';
  static String get logoutRedirect => '$baseUrl/auth/logout/redirect';
  static String get refresh => '$baseUrl/auth/refresh';
  static String get me => '$baseUrl/auth/me';
  static String get authStatus => '$baseUrl/auth/status';
  
  // Chat
  static String get chatSend => '$baseUrl/chat/send';
  static String get conversations => '$baseUrl/chat/conversations';
  static String conversationHistory(String id) => '$baseUrl/chat/conversations/$id/history';
  
  // Voice
  static String get voiceStream => '${AppConfig.wsBaseUrl}/voice/stream';
  static String get voiceSessionStart => '$baseUrl/voice/session/start';
}
