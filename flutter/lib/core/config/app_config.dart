/// Project Aura - App Configuration
/// ==================================
/// Unified configuration for API, Auth, and environment settings.
/// Handles platform-specific host resolution (emulator vs physical device).
library;

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;

/// Environment configuration
enum Environment { development, staging, production }

/// Centralized app configuration
class AppConfig {
  static const Environment environment = Environment.production;
  
  // ---------------------------------------------------------------------------
  // Dev Mode Configuration
  // ---------------------------------------------------------------------------
  
  /// Set to true when running Authentik locally via ./dev.sh --authentik-only
  /// Set to false when using Kubernetes Authentik (port 30080)
  static const bool useLocalAuthentik = false;
  
  /// Local Authentik port (from docker-compose.authentik.yml)
  static const int localAuthentikPort = 9000;
  
  /// Kubernetes Authentik port (NodePort)
  static const int kubernetesAuthentikPort = 30080;
  
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
  
  /// Get Authentik port based on dev mode
  static int get authentikPort => useLocalAuthentik 
      ? localAuthentikPort 
      : kubernetesAuthentikPort;
  
  /// Get the appropriate host for the current platform
  static String get host {
    if (environment == Environment.production) return 'api.encresa.com';
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
  static String get apiBaseUrl {
    if (environment == Environment.production) return 'https://api.encresa.com/api/v1';
    return 'http://$host:$backendPort/api/v1';
  }
  
  /// WebSocket URL for voice streaming
  static String get wsBaseUrl {
    if (environment == Environment.production) return 'wss://api.encresa.com/api/v1';
    return 'ws://$host:$backendPort/api/v1';
  }
  
  /// Health check URL
  static String get healthUrl {
    if (environment == Environment.production) return 'https://api.encresa.com/health';
    return 'http://$host:$backendPort/health';
  }
  
  // ---------------------------------------------------------------------------
  // Auth Configuration (Authentik)
  // ---------------------------------------------------------------------------
  
  /// OAuth2 Client ID - must match Authentik provider
  static const String clientId = 'JnbQ3drhh1iMJCnyaE8dSR3cJiRrWaMJ6GJT2msu';
  
  /// Redirect URL for OAuth2 callback
  static const String redirectUrl = 'com.encresa.aura://login-callback';
  
  /// OAuth2 scopes (includes 'roles' for RBAC)
  static const List<String> scopes = ['openid', 'profile', 'email', 'roles'];
  
  /// Default authentication flow slug
  static const String authFlowSlug = 'default-authentication-flow';
  
  /// Authentik base URL
  // static String get authentikBaseUrl => 'http://$host:$authentikPort';
  static String get authentikBaseUrl => 'https://auth.encresa.com';
  
  /// OIDC Issuer URL
  static String get issuer => '$authentikBaseUrl/application/o/aura-mobile/';
  
  /// Authorization endpoint
  static String get authorizationEndpoint => '${issuer}authorize/';
  
  /// Token endpoint
  static String get tokenEndpoint => '${issuer}token/';
  
  /// End session endpoint
  static String get endSessionEndpoint => '${issuer}end-session/';
  
  /// Userinfo endpoint
  static String get userinfoEndpoint => '${issuer}userinfo/';
  
  /// Debug: Print current configuration
  static void printConfig() {
    if (kDebugMode) {
      print('╔════════════════════════════════════════════════════════════╗');
      print('║              AURA Configuration                            ║');
      print('╠════════════════════════════════════════════════════════════╣');
      print('║ Environment: $environment');
      print('║ Host: $host');
      print('║ Local Authentik: $useLocalAuthentik');
      print('║ Authentik Port: $authentikPort');
      print('║ Backend URL: $apiBaseUrl');
      print('║ Authentik URL: $authentikBaseUrl');
      print('╚════════════════════════════════════════════════════════════╝');
    }
  }
}
