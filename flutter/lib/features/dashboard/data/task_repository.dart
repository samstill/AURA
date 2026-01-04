import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/api/dio_client.dart';
import '../../chat/domain/task.dart';

part 'task_repository.g.dart';

@riverpod
Future<TaskRepository> taskRepository(Ref ref) async {
  final dio = await ref.watch(apiClientProvider.future);
  return TaskRepository(dio);
}

class TaskRepository {
  final Dio _dio;

  TaskRepository(this._dio);

  Future<Map<String, int>> getSummary() async {
    final response = await _dio.get('/api/v1/tasks/summary');
    return Map<String, int>.from(response.data);
  }

  Future<String> getTaskOverview() async {
    try {
      final response = await _dio.get('/api/v1/tasks/overview');
      return response.data['overview'] as String;
    } catch (e) {
      return "Unable to generate summary at this time.";
    }
  }

  Future<List<SecretaryTask>> getTasks({int limit = 20, int offset = 0}) async {
    final response = await _dio.get(
      '/api/v1/tasks',
      queryParameters: {'limit': limit, 'offset': offset},
    );
    return (response.data as List)
        .map((e) => SecretaryTask.fromJson(e))
        .toList();
  }

  Future<void> markAsRead(int taskId) async {
    await _dio.post('/api/v1/tasks/$taskId/read');
  }
}
