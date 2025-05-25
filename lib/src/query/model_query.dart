import 'package:json_api_client/src/base_model/base_model.dart';
import 'package:json_api_client/src/query/query.dart';

mixin ModelQuery<T extends BaseModel<T>> {
  final Map<String, String> _filters = {};
  final List<String> _withs = [];
  final Map<String, List<String>> _selects = {};
  final Map<String, String> _queryParams = {};

  get filters => _filters;
  get withs => _withs;
  get selects => _selects;
  get queryParams => _queryParams;

  T instanceFromJson(Map<String, dynamic> json);

  Query<T> where(String key, String value) {
    _filters[key] = value;
    return this as Query<T>;
  }

  Query<T> withRelations(List<String> relations) {
    _withs.addAll(relations);
    return this as Query<T>;
  }

  Query<T> select(List<String> fields, [String? type]) {
    type ??= T.toString();
    final current = _selects[type] ?? [];
    current.addAll(fields);
    _selects[type] = current;
    return this as Query<T>;
  }

  Query<T> withQueryParams(Map<String, String> queryParams) {
    _queryParams.addAll(queryParams);
    return this as Query<T>;
  }
}
