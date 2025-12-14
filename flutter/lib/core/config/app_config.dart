/// Project Aura - App Configuration
/// ==================================
/// Unified configuration for API, Auth, and environment settings.
/// Handles platform-specific host resolution (emulator vs physical device).

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Environment configuration
enum Environment { development, staging, production }

/// Centralized app configuration
class AppConfig {
  static const Environment environment = Environment.development;
  
  // ---------------------------------------------------------------------------
  // Network Configuration
  // ---------------------------------------------------------------------------
  
  /// Your machine's IP for physical device testing
  /// Find it with: hostname -I | awk '{print $1}'
  static const String _physicalDeviceHost = '192.168.29.167';
  
  /// Set to true when testing on a physical Android device
  static const bool _usePhysicalDevice = true;
  
  /// Backend port (NodePort)
  static const int backendPort = 30000;
  
  /// Authentik port (NodePort)
  static const int authentikPort = 30080;
  
  /// Get the appropriate host for the current platform
  static String get host {
    if (kIsWeb) return 'localhost';
    
    if (Platform.isAndroid) {
      return _usePhysicalDevice ? _physicalDeviceHost : '10.0.2.2';
    }
    
    if (Platform.isIOS) return 'localhost';
    
    return 'localhost';
  }
  
  // ---------------------------------------------------------------------------
  // API URLs
  // ---------------------------------------------------------------------------
  
  /// Base URL for the Aura Backend API
  static String get apiBaseUrl => 'http://$host:$backendPort/api/v1';
  
  /// WebSocket URL for voice streaming
  static String get wsBaseUrl => 'ws://$host:$backendPort/api/v1';
  
  /// Health check URL
  static String get healthUrl => 'http://$host:$backendPort/health';
  
  // ---------------------------------------------------------------------------
  // Auth Configuration (Authentik)
  // ---------------------------------------------------------------------------
  
  /// OAuth2 Client ID - must match Authentik provider
  static const String clientId = 'X28xia3rFhbApkx90g1PdAM8YoAlqaU7MO5faMsX';
  
  /// Redirect URL for OAuth2 callback
  static const String redirectUrl = 'com.project.aura://login-callback';
  
  /// OAuth2 scopes
  static const List<String> scopes = ['openid', 'profile', 'email'];
  
  /// Default authentication flow slug
  static const String authFlowSlug = 'default-authentication-flow';
  
  /// Authentik base URL
  static String get authentikBaseUrl => 'http://$host:$authentikPort';
  
  /// OIDC Issuer URL
  static String get issuer => '$authentikBaseUrl/application/o/aura/';
  
  /// Authorization endpoint
  static String get authorizationEndpoint => '${issuer}authorize/';
  
  /// Token endpoint
  static String get tokenEndpoint => '${issuer}token/';
  
  /// End session endpoint
  static String get endSessionEndpoint => '${issuer}end-session/';
  
  /// Userinfo endpoint
  static String get userinfoEndpoint => '${issuer}userinfo/';
}
