import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/domain/recipe.dart';
import 'package:app/domain/shopping_list_item.dart';
import 'package:app/infrastructure/chat_service.dart';
import 'package:app/infrastructure/network/api_client.dart';
import 'package:app/infrastructure/network/api_exception.dart';
import 'package:app/infrastructure/pantry_repository.dart';
import 'package:app/infrastructure/recipe_repository.dart';

/// The Go API's contract tests write the responses read here and replay the
/// requests written here. Rewrite this side's requests with
/// `UPDATE_CONTRACT=1 flutter test test/contract_test.dart`.
const _contractDir = '../testdata/contract';

/// Keys the Go API sends that the app deliberately does not model.
const _unmodelled = {'createdAt', 'updatedAt', 'photos'};

class _Exchange {
  _Exchange(this.method, this.path, this.status, this.body);

  factory _Exchange.read(String kind, String name) {
    final json = jsonDecode(File('$_contractDir/$kind/$name.json').readAsStringSync())
        as Map<String, dynamic>;
    return _Exchange(json['method'] as String, json['path'] as String,
        json['status'] as int?, json['body']);
  }

  final String method;
  final String path;
  final int? status;
  final Object? body;
}

class _Sent {
  _Sent(this.method, this.path, this.body);
  final String method;
  final String path;
  final Object? body;
}

/// Answers each request from the Go-owned response fixture for its method and
/// path, and records what the app sent.
class _FixtureAdapter implements HttpClientAdapter {
  _FixtureAdapter(List<String> responses)
      : _responses = [for (final name in responses) _Exchange.read('responses', name)];

  final List<_Exchange> _responses;
  final List<_Sent> sent = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final body = options.data is FormData
        ? null
        : jsonDecode(jsonEncode(options.data));
    sent.add(_Sent(options.method, options.uri.path, body));

    final match = _responses.where(
        (r) => r.method == options.method && r.path == options.uri.path);
    if (match.isEmpty) {
      return ResponseBody.fromString('', 404);
    }
    final ex = match.first;
    final text = switch (ex.body) {
      null => '',
      final String raw => raw,
      final json => jsonEncode(json),
    };
    return ResponseBody.fromString(text, ex.status ?? 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

(ApiClient, _FixtureAdapter) _client(List<String> responses) {
  final client = ApiClient();
  final adapter = _FixtureAdapter(responses);
  client.dio.interceptors.clear();
  client.dio.httpClientAdapter = adapter;
  return (client, adapter);
}

Object? _normalise(Object? value) => jsonDecode(jsonEncode(value));

/// Every key Go sends is modelled by the app unless listed in [_unmodelled],
/// every key the app models is one Go sends, and every value survives the
/// round trip through the app's model.
void _expectSameShape(String at, Object? go, Object? app) {
  if (go is Map) {
    expect(app, isA<Map>(), reason: '$at: Go sends an object');
    final appMap = app as Map;
    final goKeys = go.keys.where((k) => !_unmodelled.contains(k)).toSet();
    expect(appMap.keys.toSet(), goKeys, reason: '$at: keys differ between Go and the app');
    for (final k in goKeys) {
      _expectSameShape('$at.$k', go[k], appMap[k]);
    }
  } else if (go is List) {
    expect(app, isA<List>(), reason: '$at: Go sends a list');
    expect((app as List).length, go.length, reason: '$at: list length');
    for (var i = 0; i < go.length; i++) {
      _expectSameShape('$at[$i]', go[i], app[i]);
    }
  } else {
    expect(app, go, reason: '$at: value lost in the app model');
  }
}

void _expectRequestFixture(String name, _Sent sent) {
  final file = File('$_contractDir/requests/$name.json');
  final current = {'method': sent.method, 'path': sent.path, 'body': sent.body};
  if (Platform.environment['UPDATE_CONTRACT'] == '1') {
    file.parent.createSync(recursive: true);
    file.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(current)}\n');
    return;
  }
  expect(jsonDecode(file.readAsStringSync()), current,
      reason: '${file.path} is stale: rerun with UPDATE_CONTRACT=1, then run the Go contract tests');
}

void main() {
  final recipeFixture = _Exchange.read('responses', 'get_recipe');
  final recipePath = recipeFixture.path;
  final recipeId = recipePath.split('/').last;

  group('recipes', () {
    test('a single recipe decodes with nothing lost', () async {
      final (client, _) = _client(['get_recipe']);
      final recipe = await RecipeRepository(client).getRecipe(recipeId);
      _expectSameShape(r'$', recipeFixture.body, _normalise(recipe.toJson()));
    });

    test('the recipe list and meal plan decode through their envelopes', () async {
      final (client, _) = _client(['list_recipes', 'list_meal_plan']);
      final repo = RecipeRepository(client);

      final list = _Exchange.read('responses', 'list_recipes').body as Map;
      final page = await repo.getRecipes();
      expect(page.total, list['total']);
      _expectSameShape(r'$.recipes', list['recipes'], _normalise(page.recipes));

      final plan = _Exchange.read('responses', 'list_meal_plan').body as Map;
      _expectSameShape(r'$.recipes', plan['recipes'], _normalise(await repo.getMealPlanRecipes()));
    });

    test('saving sends what Go reads, and decodes what Go answers', () async {
      final (client, adapter) = _client(['create_recipe', 'update_recipe']);
      final repo = RecipeRepository(client);
      final recipe = Recipe.fromJson(recipeFixture.body as Map<String, dynamic>);

      final created = await repo.createRecipe(recipe);
      _expectSameShape(r'$', _Exchange.read('responses', 'create_recipe').body, _normalise(created.toJson()));
      _expectRequestFixture('create_recipe', adapter.sent.last);

      final updated = await repo.updateRecipe(recipeId, recipe);
      _expectSameShape(r'$', _Exchange.read('responses', 'update_recipe').body, _normalise(updated.toJson()));
      _expectRequestFixture('update_recipe', adapter.sent.last);
    });

    test('labels, units and ingredients decode with nothing lost', () async {
      final (client, _) = _client(['list_labels', 'list_units', 'list_ingredients']);
      final repo = RecipeRepository(client);

      _expectSameShape(r'$.labels', (_Exchange.read('responses', 'list_labels').body as Map)['labels'],
          _normalise(await repo.getLabels()));
      _expectSameShape(r'$.units', (_Exchange.read('responses', 'list_units').body as Map)['units'],
          _normalise(await repo.getUnits()));
      _expectSameShape(r'$.ingredients', (_Exchange.read('responses', 'list_ingredients').body as Map)['ingredients'],
          _normalise(await repo.getIngredients()));
    });

    test('a photo upload answers with the stored URL', () async {
      final (client, _) = _client(['upload_photo']);
      final url = await RecipeRepository(client)
          .uploadRecipePhoto(recipeId, Uint8List.fromList([0x89, 0x50]), 'lasagne.png');
      expect(url, (_Exchange.read('responses', 'upload_photo').body as Map)['url']);
    });

    test('an unknown recipe surfaces the error envelope', () async {
      final fixture = _Exchange.read('responses', 'recipe_not_found');
      final (client, _) = _client(['recipe_not_found']);
      final error = (fixture.body as Map)['error'] as Map;

      await expectLater(
        RecipeRepository(client).getRecipe(fixture.path.split('/').last),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', fixture.status)
            .having((e) => e.code, 'code', error['code'])
            .having((e) => e.serverMessage, 'serverMessage', error['message'])),
      );
    });
  });

  group('pantry and shopping list', () {
    test('pantry items carry exactly the keys the app reads', () async {
      final (client, _) = _client(['list_pantry']);
      final items = (_Exchange.read('responses', 'list_pantry').body as Map)['items'] as List;
      final pantry = await PantryRepository(client).getPantry();

      expect(pantry.length, items.length);
      for (var i = 0; i < items.length; i++) {
        final go = items[i] as Map;
        expect(go.keys.toSet(), {'ingredient', 'addedAt'});
        expect(pantry[i].ingredient, go['ingredient']);
        expect(pantry[i].addedAt, DateTime.parse(go['addedAt'] as String));
      }
    });

    test('shopping items carry exactly the keys and sources the app knows', () async {
      final (client, _) = _client(['shopping_list']);
      final items = (_Exchange.read('responses', 'shopping_list').body as Map)['items'] as List;
      final list = await PantryRepository(client).getShoppingList();

      expect(list.length, items.length);
      final sources = <String>{};
      for (var i = 0; i < items.length; i++) {
        final go = items[i] as Map;
        expect(go.keys.toSet(), {'name', 'source'});
        expect(list[i].name, go['name']);
        expect(list[i].source, go['source']);
        sources.add(go['source'] as String);
      }
      expect(sources, {ShoppingListItem.sourceMealPlan, ShoppingListItem.sourceCustom});
    });

    test('adding a custom item sends what Go reads', () async {
      final (client, adapter) = _client(['add_shopping_item']);
      await PantryRepository(client).addCustomShoppingItem('washing-up liquid');
      _expectRequestFixture('add_shopping_item', adapter.sent.last);
    });
  });

  test('the chat stream decodes event by event', () async {
    final (client, adapter) = _client(['chat_stream']);
    final stream = _Exchange.read('responses', 'chat_stream').body as String;
    final goEvents = [
      for (final line in stream.split('\n'))
        if (line.startsWith('data: ')) jsonDecode(line.substring(6)) as Map,
    ];

    final events = await ChatService(client).sendMessage("What's for dinner?", sessionId: 'sess-1').toList();
    _expectRequestFixture('chat', adapter.sent.last);

    expect(events.length, goEvents.length);
    for (var i = 0; i < events.length; i++) {
      expect(goEvents[i].keys.toSet(), {'content', 'done', 'session_id'});
      expect(events[i].content, goEvents[i]['content']);
      expect(events[i].done, goEvents[i]['done']);
      expect(events[i].sessionId, goEvents[i]['session_id']);
    }
  });
}
