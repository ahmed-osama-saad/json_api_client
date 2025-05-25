abstract class BaseException implements Exception {
  BaseException({this.message = 'Exception'});

  final String message;

  @override
  toString() => '$runtimeType $message';
}
