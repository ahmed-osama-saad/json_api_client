import 'package:http/http.dart' as http;

import 'base_exception.dart';

class ServerException extends BaseException {
  ServerException({super.message, this.response});

  http.Response? response;

  @override
  String toString() =>
      'ServerException: $message, response: ${response?.body} status: ${response?.statusCode} reason: ${response?.reasonPhrase}, headers: ${response?.headers}, url: ${response?.request?.url}, method: ${response?.request?.method} body: ${response?.request?.headers}';
}
