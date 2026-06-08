import '../domain/me.dart';
import 'network/api_client.dart';

class MeRepository {
  final ApiClient _apiClient;

  MeRepository(this._apiClient);

  /// Fetches the signed-in user's identity and homes from GET /api/me.
  /// Throws on network or auth failure — the caller (the auth provider)
  /// is responsible for translating 401s into a sign-out.
  Future<Me> fetchMe() async {
    final res = await _apiClient.dio.get<Map<String, dynamic>>('/me');
    final body = res.data;
    if (body == null) {
      throw const FormatException('Empty /api/me response');
    }
    return Me.fromJson(body);
  }
}
