import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/retry.dart';
import 'package:japx/japx.dart';
import 'package:json_api_client/json_api_client.dart';
import 'package:json_api_client/src/exceptions/forbidden_exception.dart';
import 'package:json_api_client/src/exceptions/server_exception.dart';
import 'package:json_api_client/src/exceptions/un_authorized_exception.dart';
import 'package:json_api_client/src/json_api_client_base.dart';

class ApiRequest {
  static Future<Map<String, dynamic>?> request(
    String path, {
    String method = 'GET',
    dynamic body = const {},
    Map<String, dynamic>? queryParams,
    Map<String, String>? headers,
    bool encode = true,
  }) async {
    final RetryClient client = getClient();
    try {
      queryParams ??= {};
      queryParams['locale'] = JsonApiClient.languageCode;

      if (JsonApiClient.userToken != null) {
        headers ??= {};
        headers['Authorization'] = 'Bearer ${JsonApiClient.userToken}';
      }
      final uri =
          Uri.parse('${JsonApiClient.baseUrl}/${JsonApiClient.version}/$path')
              .replace(queryParameters: queryParams);
      final languageHeader =
          MapEntry('accept-language', JsonApiClient.languageCode);

      final String encodedBody =
          encode ? json.encode(Japx.encode(body)) : json.encode(body);
      final request = http.Request(
        method,
        uri,
      )
        ..body = encodedBody
        ..headers.addAll({
          'Accept': 'application/vnd.api+json',
          'Content-Type': 'application/vnd.api+json',
          languageHeader.key: languageHeader.value,
          ...?JsonApiClient.persistentHeaders,
          ...?headers,
        });
      final streamedResponse = await client.send(request);
      final response = await _convertStreamedResponse(streamedResponse);
      if (response.statusCode == 204) {
        return null;
      }
      final Map<String, dynamic> jsonResponse = json.decode(response.body);
      if (response.statusCode.toString().startsWith('2')) {
        if (jsonResponse['data'] == null) {
          return null;
        }
        return Japx.decode(jsonResponse);
      } else if (response.statusCode == 401) {
        throw UnAuthorizedException();
      } else if (response.statusCode == 403) {
        throw ForbiddenException(
            message:
                jsonResponse['message'] ?? 'You are not allowed to do this.');
      } else {
        throw ServerException(
            response: response, message: jsonResponse['message'] ?? '');
      }
    } on Exception {
      rethrow;
    } finally {
      client.close();
    }
  }

  static Future<http.Response> _convertStreamedResponse(
      http.StreamedResponse streamedResponse) async {
    // Read the stream of bytes from the response.
    final bytes = await streamedResponse.stream.toBytes();
    final body = utf8.decode(bytes);

    // Create a new Response object.
    return http.Response(
      body,
      streamedResponse.statusCode,
      headers: streamedResponse.headers,
      request: streamedResponse.request,
      reasonPhrase: streamedResponse.reasonPhrase,
    );
  }

  static RetryClient getClient() {
    final timeoutClient = TimeoutClient(
      http.Client(),
      const Duration(seconds: 10),
    );

    return RetryClient(
      timeoutClient,
      retries: 3,
      when: (response) => response.statusCode == 408,
      delay: (retryCount) => const Duration(seconds: 1) * retryCount,
      whenError: (error, stackTrace) {
        FirebaseCrashlytics.instance.recordError(error, stackTrace);
        return error is TimeoutException ||
            error is SocketException ||
            error is http.ClientException;
      },
      onRetry: (p0, p1, retryCount) {
        if (kDebugMode) {
          print('Retrying request... $retryCount');
        }
      },
    );
  }

  static Future<Map<String, dynamic>> post(String path,
      {Map<String, dynamic> body = const {},
      Map<String, dynamic>? queryParams,
      Map<String, String>? headers,
      bool isPartner = false,
      bool version = true}) async {
    final uriPrefix = isPartner
        ? '${JsonApiClient.baseUrl}${version ? '/${JsonApiClient.version}' : ''}/${JsonApiClient.prefix}'
        : '${JsonApiClient.baseUrl}${version ? '/${JsonApiClient.version}' : ''}';

    queryParams ??= {};
    queryParams['locale'] = JsonApiClient.languageCode;

    final uri =
        Uri.parse('$uriPrefix/$path').replace(queryParameters: queryParams);

    if (JsonApiClient.userToken != null) {
      headers ??= {};
      headers['Authorization'] = 'Bearer ${JsonApiClient.userToken}';
    }

    final languageHeader =
        MapEntry('accept-language', JsonApiClient.languageCode);
    final streamedResponse = await getClient().send(
      http.Request('POST', uri)
        ..body = body.isNotEmpty ? json.encode(body) : ''
        ..headers.addAll({
          'Accept': 'application/vnd.api+json',
          'Content-Type': 'application/vnd.api+json',
          languageHeader.key: languageHeader.value,
          ...?JsonApiClient.persistentHeaders,
          ...?headers,
        }),
    );
    final http.Response response =
        await _convertStreamedResponse(streamedResponse);
    Map<String, dynamic>? jsonResponse;
    if (response.bodyBytes.isNotEmpty) {
      jsonResponse = json.decode(response.body);
    } else {
      jsonResponse = {};
    }
    // TODO: close client
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonResponse ?? {};
    } else if (response.statusCode == 401) {
      throw UnAuthorizedException();
    } else if (response.statusCode == 403) {
      throw ForbiddenException(
          message:
              jsonResponse?['message'] ?? 'You are not allowed to do this.');
    } else {
      throw ServerException(
          message: jsonResponse?['message'] ?? '', response: response);
    }
  }
}

class TimeoutClient extends http.BaseClient {
  final http.Client _inner;
  final Duration _timeout;

  TimeoutClient(this._inner, this._timeout);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _inner.send(request).timeout(_timeout);
  }

  @override
  void close() {
    _inner.close();
  }
}
