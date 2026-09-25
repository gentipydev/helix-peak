import 'dart:convert';
import 'dart:io';

import 'package:helixpeek/core/network/api_client.dart';

Map<String, dynamic> catalogFixture() =>
    jsonDecode(File('test/fixtures/catalog.json').readAsStringSync())
        as Map<String, dynamic>;

class CatalogApi implements ApiClient {
  CatalogApi({this.answer});
  Future<Map<String, dynamic>> Function(String, Map<String, dynamic>?)? answer;
  final List<String> asked = [];

  @override
  Future<Map<String, dynamic>> getJson(String path, {Map<String, dynamic>? query}) async {
    asked.add(path);
    return answer == null ? catalogFixture() : await answer!(path, query);
  }

  @override
  Future<Map<String, dynamic>> postJson(String path, {required Map<String, dynamic> body}) =>
      throw UnimplementedError();
}
