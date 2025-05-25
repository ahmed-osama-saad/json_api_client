// TODO: Put public facing types in this file.

/// Checks if you are awesome. Spoiler: you are.

class JsonApiClient {
  static String baseUrl = '*** Missing BASE_URL ***';
  static String languageCode = 'en';
  static String version = 'v1';
  static String? prefix;
  static Map<String, String>? persistentHeaders;
  static String? userToken;
  static Map<Type, String> typesMap = {};

  static init(
    String baseUrl, {
    String version = 'v1',
    String languageCode = 'de',
    String? prefix,
    required Map<Type, String> typesMap,
  }) {
    JsonApiClient.baseUrl = baseUrl;
    JsonApiClient.version = version;
    JsonApiClient.languageCode = languageCode;
    JsonApiClient.prefix = prefix;
    JsonApiClient.typesMap = typesMap;
  }

  static set language(String? languageCode) {
    JsonApiClient.languageCode = languageCode ?? 'de';
  }

  static registerType(
    Type type,
    String typeName, {
    bool override = false,
  }) {
    if (JsonApiClient.typesMap.containsKey(type) && !override) {
      throw Exception('Type already registered: $type');
    }
    JsonApiClient.typesMap[type] = typeName;
  }

  static appendHeaders(Map<String, String> headers) {
    if (JsonApiClient.persistentHeaders == null) {
      JsonApiClient.persistentHeaders = headers;
    } else {
      JsonApiClient.persistentHeaders!.addAll(headers);
    }
  }
}
