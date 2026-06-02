import 'dart:developer' as dev;

import 'package:dio/dio.dart';
import '../domain/pantry_item.dart';
import 'network/api_client.dart';

String _formatDioError(String action, DioException e) {
  final status = e.response?.statusCode;
  if (status != null) {
    return '$action ($status)';
  }
  final inner = e.error;
  if (inner != null) {
    return '$action ($inner)';
  }
  return '$action (${e.type.name}: ${e.message})';
}

class PantryRepository {
  final ApiClient _apiClient;

  PantryRepository(this._apiClient);

  Future<List<PantryItem>> getPantry() async {
    try {
      dev.log('Fetching pantry', name: 'PantryRepository');
      final response = await _apiClient.dio.get('/pantry');
      final Map<String, dynamic> data = response.data;
      final List<dynamic> itemsJson = data['items'] ?? const [];
      return itemsJson
          .map((json) => PantryItem.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e, stack) {
      dev.log('Failed to load pantry: ${e.message}',
          name: 'PantryRepository', error: e, stackTrace: stack);
      throw Exception(_formatDioError('Failed to load pantry', e));
    }
  }

  Future<void> addToPantry(String ingredient) async {
    try {
      dev.log('Adding "$ingredient" to pantry', name: 'PantryRepository');
      await _apiClient.dio.put('/pantry/${Uri.encodeComponent(ingredient)}');
    } on DioException catch (e, stack) {
      dev.log('Failed to add "$ingredient" to pantry: ${e.message}',
          name: 'PantryRepository', error: e, stackTrace: stack);
      throw Exception(_formatDioError('Failed to add to pantry', e));
    }
  }

  Future<void> removeFromPantry(String ingredient) async {
    try {
      dev.log('Removing "$ingredient" from pantry', name: 'PantryRepository');
      await _apiClient.dio.delete('/pantry/${Uri.encodeComponent(ingredient)}');
    } on DioException catch (e, stack) {
      dev.log('Failed to remove "$ingredient" from pantry: ${e.message}',
          name: 'PantryRepository', error: e, stackTrace: stack);
      throw Exception(_formatDioError('Failed to remove from pantry', e));
    }
  }
}
