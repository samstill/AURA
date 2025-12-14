/// Project Aura - Dio HTTP Client
/// ================================
/// Centralized Dio instance with interceptors.

import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../config/app_config.dart';

part 'dio_client.g.dart';

/// Provides the shared CookieJar instance
@Riverpod(keepAlive: true)
CookieJar cookieJar(CookieJarRef ref) => CookieJar();

/// Provides the configured Dio instance for API calls
@Riverpod(keepAlive: true)
Dio apiClient(ApiClientRef ref) {
  final cookieJar = ref.watch(cookieJarProvider);
  
  final dio = Dio(BaseOptions(
    baseUrl: AppConfig.apiBaseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
    validateStatus: (status) => status != null && status < 500,
  ));
  
  // Cookie manager for session handling
  dio.interceptors.add(CookieManager(cookieJar));
  
  // Debug logging in development
  if (kDebugMode) {
    dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      logPrint: (obj) => debugPrint('[API] $obj'),
    ));
  }
  
  return dio;
}

/// Provides the configured Dio instance for Authentik API calls
@Riverpod(keepAlive: true)
Dio authentikClient(AuthentikClientRef ref) {
  final cookieJar = ref.watch(cookieJarProvider);
  
  final dio = Dio(BaseOptions(
    baseUrl: AppConfig.authentikBaseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    followRedirects: false,
    maxRedirects: 0,
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
    validateStatus: (status) => status != null && status < 500,
  ));
  
  // Cookie manager for session handling
  dio.interceptors.add(CookieManager(cookieJar));
  
  // Debug logging in development
  if (kDebugMode) {
    dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      logPrint: (obj) => debugPrint('[Auth] $obj'),
    ));
  }
  
  return dio;
}
