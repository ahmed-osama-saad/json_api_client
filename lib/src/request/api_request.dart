import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/retry.dart';
import 'package:japx/japx.dart';
import 'package:json_api_client/json_api_client.dart';
import 'package:json_api_client/src/exceptions/forbidden_exception.dart';
import 'package:json_api_client/src/exceptions/login_exception.dart';
import 'package:json_api_client/src/exceptions/server_exception.dart';
import 'package:json_api_client/src/exceptions/un_authorized_exception.dart';
import 'package:json_api_client/src/json_api_client_base.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

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

  static Future<Map<String, dynamic>> login(String email, String password) async {
    final result = await getClient().post(
      Uri.parse('${JsonApiClient.baseUrl}/auth/login'),
      headers: {
        'Accept': 'application/vnd.api+json',
        'Content-Type': 'application/json',
        ...?JsonApiClient.persistentHeaders,
      },
      body: json.encode({
        'email': email,
        'password': password,
      }),
    );
    final responseBody = json.decode(result.body);
    // TODO: close client
    if (result.statusCode.toString().startsWith('2')) {
      return responseBody;
    } else {
      throw LoginException(message: responseBody['message']);
    }
  }

  static Future<Map<String, dynamic>> register(
      {required String email,
      required String password,
      required String firstName,
      required String lastName,
      required String gender,
      required String username,
      required String? profilePicture,
      required String confirmPassword}) async {
    final client = getClient();
    final uri = Uri.parse('${JsonApiClient.baseUrl}/auth/register');
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll({
        'Accept': 'application/vnd.api+json',
        ...?JsonApiClient.persistentHeaders,
      })
      ..fields['email'] = email
      ..fields['password'] = password
      ..fields['first_name'] = firstName
      ..fields['last_name'] = lastName
      ..fields['gender'] = gender.toLowerCase()
      ..fields['username'] = username
      ..fields['password_confirmation'] = confirmPassword;

    // Attach the profile picture file
    if (profilePicture != null) {
      request.files.add(
          await http.MultipartFile.fromPath('profile_picture', profilePicture));
    }

    final streamedResponse = await client.send(request);
    final result = await _convertStreamedResponse(streamedResponse);
    final responseBody = json.decode(result.body);
    // TODO: close client
    if (result.statusCode.toString().startsWith('2')) {
      return responseBody;
    } else {
      throw LoginException(message: responseBody['message']);
    }
  }

  static Future<Map<String, dynamic>> loginWithGoogle() async {
    GoogleSignIn _googleSignIn = GoogleSignIn(
      forceCodeForRefreshToken: true,
    );
    _googleSignIn.disconnect();
    if (await _googleSignIn.isSignedIn()) {
      await _googleSignIn.signOut();
    }
    final googleSignInAccount = await _googleSignIn.signIn();
    final auth = await googleSignInAccount?.authentication;
    if (auth?.accessToken == null) {
      throw LoginException(message: 'Google sign in failed');
    }
    final result = await loginAsSocial(auth!.accessToken!, 'google');
    return result;
  }

  static Future<dynamic> loginAsSocial(String token, String provider) async {
    final result = await getClient().post(
      Uri.parse('${JsonApiClient.baseUrl}/auth/login/$provider/callback'),
      headers: {
        'Accept': 'application/vnd.api+json',
        'Content-Type': 'application/json',
        ...?JsonApiClient.persistentHeaders,
      },
      body: json.encode({
        'token': token,
      }),
    );
    // TODO: close client
    if (result.statusCode.toString().startsWith('2')) {
      final responseBody = json.decode(result.body);
      return responseBody;
    } else {
      throw LoginException(message: json.decode(result.body)['message']);
    }
  }

  static Future<Map<String, dynamic>> loginWithApple() async {
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );
    return await loginAsSocial(credential.identityToken!, 'apple');
  }

  static Future<void> forgotPassword(String email) async {
    final result = await getClient().post(
      Uri.parse('${JsonApiClient.baseUrl}/api/auth/forgotPassword'),
      headers: {
        'Accept': 'application/vnd.api+json',
        'Content-Type': 'application/json',
        ...?JsonApiClient.persistentHeaders,
      },
      body: json.encode({
        'email': email,
      }),
    );
    if (result.statusCode.toString().startsWith('2')) {
      final responseBody = json.decode(result.body);
      return responseBody['data'];
    } else {
      throw LoginException(message: json.decode(result.body)['message']);
    }
  }

  static Future<void> resetPassword(String email, String password,
      String confirmPassword, String token) async {
    final result = await getClient().post(
      Uri.parse('${JsonApiClient.baseUrl}/api/auth/resetPassword'),
      headers: {
        'Accept': 'application/vnd.api+json',
        'Content-Type': 'application/json',
        ...?JsonApiClient.persistentHeaders,
      },
      body: json.encode({
        'email': email,
        'password': password,
        'password_confirmation': confirmPassword,
        'token': token,
      }),
    );
    if (result.statusCode.toString().startsWith('2')) {
      final responseBody = json.decode(result.body);
      return responseBody['data'];
    } else {
      throw LoginException(message: json.decode(result.body)['message']);
    }
  }

  static Future<void> loginWithTrackerId(String trackerId) async {
    await ApiRequest.post('auth/login/$trackerId', version: false);
  }

  static Future<Map<String, dynamic>> partnerLogin(String cardNumber) async {
    try {
      final result = await getClient().post(
        Uri.parse(
            '${JsonApiClient.baseUrl}/${JsonApiClient.version}/${JsonApiClient.prefix}/login/'),
        headers: {
          'Accept': 'application/vnd.api+json',
          'Content-Type': 'application/json',
          ...?JsonApiClient.persistentHeaders,
        },
        body: json.encode({
          'cardnumber': cardNumber,
        }),
      );
      // TODO: close client
      if (result.statusCode.toString().startsWith('2')) {
        final responseBody = Japx.decode(json.decode(result.body));
        return responseBody['data'];
      } else {
        throw LoginException(message: json.decode(result.body)['message']);
      }
    } on Exception catch (e) {
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current);
      throw LoginException(message: e.toString());
    }
  }

  static Future<Map<String, dynamic>> partnerRegister(
      String email, String firstName, String lastName) async {
    try {
      final Map<String, dynamic> result = await partnerPost('register', body: {
        'email': email,
        'first_name': firstName,
        'last_name': lastName,
      });

      final responseBody = Japx.decode(result);
      return responseBody['data'];
    } catch (e) {
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current);
      rethrow;
    }
  }

  static Future<void> sendBatteryReport(
      {required int battery, required String publicId}) async {
    const path = 'resource/public/battery-reports';
    final body = {
      'battery_level': battery,
      'tracker_id': publicId,
    };
    post(path, body: body);
  }

  static Future<void> sendHealthCheckReport(
      {required List<String> healthCheckReport,
      required String publicId}) async {
    const path = 'resource/public/health-check-reports';
    final body = {
      'result': healthCheckReport,
      'tracker_id': publicId,
    };
    post(path, body: body);
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

  static Future<Map<String, dynamic>> partnerPost(
    String path, {
    Map<String, dynamic> body = const {},
    Map<String, dynamic>? queryParams,
    Map<String, String>? headers,
  }) async {
    return await post(path,
        isPartner: true,
        body: body,
        headers: headers,
        queryParams: queryParams);
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
