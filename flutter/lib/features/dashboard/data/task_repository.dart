import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/api/api_exception.dart';
import '../../../../core/api/dio_client.dart';
import '../../chat/domain/task.dart';

part 'task_repository.g.dart';

/// Secretary brief data from /chat/brief API
class SecretaryBrief {
  final String brief;
  final int count;
  final List<NotificationItem> items;

  SecretaryBrief({
    required this.brief,
    required this.count,
    required this.items,
  });

  factory SecretaryBrief.fromJson(Map<String, dynamic> json) {
    return SecretaryBrief(
      brief: json['brief'] as String? ?? 'No updates available.',
      count: json['count'] as int? ?? 0,
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => NotificationItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  factory SecretaryBrief.empty() => SecretaryBrief(
        brief: 'All clear! No pending tasks or notifications.',
        count: 0,
        items: [],
      );
}

/// Notification item from backend
class NotificationItem {
  final String id;
  final String title;
  final String description;
  final String time;
  final String type;
  final bool isRead;

  NotificationItem({
    required this.id,
    required this.title,
    required this.description,
    required this.time,
    required this.type,
    required this.isRead,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['task_id']?.toString() ?? json['id']?.toString() ?? '',
      title: json['title'] as String? ?? 'Notification',
      description: json['description'] as String? ?? json['result'] as String? ?? '',
      time: _formatTime(json['completed_at'] as String?),
      type: json['type'] as String? ?? 'info',
      isRead: json['is_read'] as bool? ?? false,
    );
  }

  static String _formatTime(String? timestamp) {
    if (timestamp == null) return 'Just now';
    try {
      final dt = DateTime.parse(timestamp);
      final now = DateTime.now();
      final diff = now.difference(dt);
      
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
      if (diff.inHours < 24) return '${diff.inHours} hours ago';
      return '${diff.inDays} days ago';
    } catch (_) {
      return 'Recently';
    }
  }
}

@riverpod
Future<TaskRepository> taskRepository(Ref ref) async {
  final dio = await ref.watch(apiClientProvider.future);
  return TaskRepository(dio);
}

class TaskRepository {
  final Dio _dio;

  TaskRepository(this._dio);

  /// Get task summary counts (total, unread)
  Future<Map<String, int>> getSummary() async {
    try {
      final response = await _dio.get('/tasks/summary');
      return Map<String, int>.from(response.data);
    } on DioException catch (e) {
      debugPrint('❌ [TaskRepo] getSummary failed: $e');
      throw ApiException.fromDioException(e);
    }
  }

  /// Get natural language overview of tasks
  Future<String> getTaskOverview() async {
    try {
      final response = await _dio.get('/tasks/overview');
      return response.data['overview'] as String;
    } catch (e) {
      debugPrint('⚠️ [TaskRepo] getTaskOverview failed: $e');
      return 'Unable to generate summary at this time.';
    }
  }

  /// Get list of background tasks
  Future<List<SecretaryTask>> getTasks({int limit = 20, int offset = 0}) async {
    try {
      final response = await _dio.get(
        '/tasks',
        queryParameters: {'limit': limit, 'offset': offset},
      );
      return (response.data as List)
          .map((e) => SecretaryTask.fromJson(e))
          .toList();
    } on DioException catch (e) {
      debugPrint('❌ [TaskRepo] getTasks failed: $e');
      throw ApiException.fromDioException(e);
    }
  }

  /// Mark a task as read
  Future<void> markAsRead(int taskId) async {
    try {
      await _dio.post('/tasks/$taskId/read');
    } on DioException catch (e) {
      debugPrint('❌ [TaskRepo] markAsRead failed: $e');
      throw ApiException.fromDioException(e);
    }
  }

  /// Get secretary brief with unread notifications summary
  Future<SecretaryBrief> getSecretaryBrief() async {
    try {
      final response = await _dio.get('/chat/brief');
      return SecretaryBrief.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      debugPrint('⚠️ [TaskRepo] getSecretaryBrief failed: $e');
      // Return empty brief on error instead of throwing
      return SecretaryBrief.empty();
    }
  }

  /// Get all notifications
  Future<List<NotificationItem>> getNotifications() async {
    try {
      final response = await _dio.get('/chat/notifications');
      final items = response.data as List<dynamic>;
      return items
          .map((e) => NotificationItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      debugPrint('⚠️ [TaskRepo] getNotifications failed: $e');
      return []; // Return empty list on error
    }
  }

  /// Mark a notification as read
  Future<void> markNotificationRead(String taskId) async {
    try {
      await _dio.post('/chat/notifications/$taskId/read');
    } on DioException catch (e) {
      debugPrint('❌ [TaskRepo] markNotificationRead failed: $e');
      throw ApiException.fromDioException(e);
    }
  }
}

