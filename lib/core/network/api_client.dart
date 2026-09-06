/// The app's HTTP surface.
///
/// Repositories depend on this interface, never on a concrete client, which is
/// what lets the whole networking stack be swapped or faked without touching a
/// single caller. Implementations must translate their own transport errors
/// into [ApiException] before throwing.
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
