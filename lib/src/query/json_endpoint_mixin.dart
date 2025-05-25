import 'package:json_api_client/src/base_model/base_model.dart';
import 'package:pluralize/pluralize.dart';

mixin JsonEndpoint<T extends BaseModel<T>> {
  String? endpoint;

  String generateEndpoint() => endpoint ?? generate();

  String generate() {
    return toPlural(toKebabCase(T.toString()));
  }

  String toKebabCase(String text) {
    return text
        .replaceAllMapped(
          RegExp(r'[A-Z]'),
          (Match match) => '-${match[0]!.toLowerCase()}',
        )
        .substring(1); // To remove the leading hyphen.
  }

  String toPlural(String text) {
    final pluralize = Pluralize();

    return pluralize.plural(text);
  }

  String get defaultJsonGet => generateDefaultJsonGet(T.toString());

  String get defaultJsonFind => generateDefaultJsonFind(T.toString());

  // default json file should be named plural_model_name_find.json
  // the file should be a raw response form the backend
  String generateDefaultJsonFind(String text) {
    return 'packages/json_api_client/lib/assets/${generate()}_find.json';
  }

  // default json file should be named plural_model_name_get.json
  // the file should be a raw response form the backend
  String generateDefaultJsonGet(String text) {
    return 'packages/json_api_client/lib/assets/${generate()}_get.json';
  }
}
