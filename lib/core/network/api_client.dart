abstract interface class ApiClient {
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? query,
  });

  Future<Map<String, dynamic>> postJson(
    String path, {
    required Map<String, dynamic> body,
  });
}
