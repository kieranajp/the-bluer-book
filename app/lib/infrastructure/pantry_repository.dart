import 'dart:developer' as dev;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import '../domain/pantry_item.dart';
import '../domain/shopping_list_item.dart';
import 'network/api_client.dart';
import 'network/api_exception.dart';

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
      throw ApiException.fromDio('Failed to load pantry', e);
    }
  }

  Future<void> addToPantry(String ingredient) async {
    try {
      dev.log('Adding "$ingredient" to pantry', name: 'PantryRepository');
      await _apiClient.dio.put('/pantry/${Uri.encodeComponent(ingredient)}');
    } on DioException catch (e, stack) {
      dev.log('Failed to add "$ingredient" to pantry: ${e.message}',
          name: 'PantryRepository', error: e, stackTrace: stack);
      throw ApiException.fromDio('Failed to add to pantry', e);
    }
  }

  Future<void> removeFromPantry(String ingredient) async {
    try {
      dev.log('Removing "$ingredient" from pantry', name: 'PantryRepository');
      await _apiClient.dio.delete('/pantry/${Uri.encodeComponent(ingredient)}');
    } on DioException catch (e, stack) {
      dev.log('Failed to remove "$ingredient" from pantry: ${e.message}',
          name: 'PantryRepository', error: e, stackTrace: stack);
      throw ApiException.fromDio('Failed to remove from pantry', e);
    }
  }

  /// Everything to buy: meal-plan ingredients not yet in the pantry, plus any
  /// free-text custom items.
  Future<List<ShoppingListItem>> getShoppingList() async {
    try {
      dev.log('Fetching shopping list', name: 'PantryRepository');
      final response = await _apiClient.dio.get('/shopping-list');
      final Map<String, dynamic> data = response.data;
      final List<dynamic> items = data['items'] ?? const [];
      return items
          .map((e) => ShoppingListItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e, stack) {
      dev.log('Failed to load shopping list: ${e.message}',
          name: 'PantryRepository', error: e, stackTrace: stack);
      throw ApiException.fromDio('Failed to load shopping list', e);
    }
  }

  /// Add a free-text item (e.g. "washing-up liquid") to the shopping list.
  Future<void> addCustomShoppingItem(String name) async {
    try {
      dev.log('Adding custom shopping item "$name"', name: 'PantryRepository');
      await _apiClient.dio.post('/shopping-list', data: {'name': name});
    } on DioException catch (e, stack) {
      dev.log('Failed to add custom shopping item "$name": ${e.message}',
          name: 'PantryRepository', error: e, stackTrace: stack);
      throw ApiException.fromDio('Failed to add item', e);
    }
  }

  /// Remove a previously added custom item from the shopping list.
  Future<void> removeCustomShoppingItem(String name) async {
    try {
      dev.log('Removing custom shopping item "$name"', name: 'PantryRepository');
      await _apiClient.dio.delete('/shopping-list/${Uri.encodeComponent(name)}');
    } on DioException catch (e, stack) {
      dev.log('Failed to remove custom shopping item "$name": ${e.message}',
          name: 'PantryRepository', error: e, stackTrace: stack);
      throw ApiException.fromDio('Failed to remove item', e);
    }
  }

  /// Upload a photo of a physical shopping list; the backend has Gemini parse
  /// the items and adds them as custom items. Returns the names that were added.
  Future<List<String>> scanShoppingList(Uint8List bytes, String filename) async {
    try {
      dev.log('Scanning shopping list photo ($filename, ${bytes.length} bytes)',
          name: 'PantryRepository');
      final ext = filename.split('.').last.toLowerCase();
      final mimeType = switch (ext) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        'gif' => 'image/gif',
        'heic' || 'heif' => 'image/heic',
        _ => 'image/jpeg',
      };
      final formData = FormData.fromMap({
        'photo': MultipartFile.fromBytes(
          bytes,
          filename: filename,
          contentType: MediaType.parse(mimeType),
        ),
      });
      final response =
          await _apiClient.dio.post('/shopping-list/scan', data: formData);
      final Map<String, dynamic> data = response.data;
      final List<dynamic> added = data['added'] ?? const [];
      return added.map((e) => e as String).toList();
    } on DioException catch (e, stack) {
      dev.log('Failed to scan shopping list: ${e.message}',
          name: 'PantryRepository', error: e, stackTrace: stack);
      throw ApiException.fromDio('Failed to scan shopping list', e);
    }
  }
}
