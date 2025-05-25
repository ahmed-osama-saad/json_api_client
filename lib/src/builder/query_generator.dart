import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:analyzer/dart/element/element.dart';

import 'generate_query.dart';

class QueryGenerator extends GeneratorForAnnotation<GenerateQuery> {
  @override
  String generateForAnnotatedElement(
      Element element, ConstantReader annotation, BuildStep buildStep) {
    if (element is! ClassElement) {
      throw InvalidGenerationSourceError(
          'GenerateQuery can only be applied to classes.',
          element: element);
    }

    final className = element.name;
    final queryClassName = '${className}Query';
    final endpoint = annotation.peek('endpoint')?.stringValue;
    final constructor = endpoint != null
        ? '''
          $queryClassName() {
            endpoint = '$endpoint';
          }
          '''
        : '';
    return '''

class $queryClassName extends Query<$className> {
  $constructor

  @override
  $className instanceFromJson(Map<String, dynamic> json) {
    return $className.fromJson(json);
  }
}
''';
  }
}

Builder queryBuilder(BuilderOptions options) =>
    SharedPartBuilder([QueryGenerator()], 'query');
