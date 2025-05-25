import 'package:json_api_client/json_api_client.dart';

class QueryRequest<T extends BaseModel<T>> {
  final Query<T> query;

  QueryRequest(this.query);

  Future<Map<String, dynamic>?> request({
    String? path,
    String? suffix,
    String method = 'GET',
    dynamic body = const {},
    Map<String, dynamic>? queryParams,
    Map<String, String>? headers,
    bool encode = true,
  }) async {
    queryParams = {
      ...query.filters.map((key, value) => MapEntry('filter[$key]', value)),
      ...?queryParams
    };
    if (query.selects.isNotEmpty) {
      queryParams = {
        ...query.selects
            .map((key, value) => MapEntry('fields[$key]', value.join(','))),
        ...queryParams
      };
    }
    if (queryParams.containsKey('include')) {
      queryParams['include'] =
          queryParams['include']! + ',' + query.withs.join(',');
    } else {
      if (query.withs.isNotEmpty) {
        queryParams['include'] = query.withs.join(',');
      }
    }
    String endpoint = path ?? query.generateEndpoint();
    if (suffix != null) {
      endpoint = '$endpoint/$suffix';
    }
    if (query.parentEndpoint != null) {
      endpoint = '${query.parentEndpoint}/$endpoint';
    }
    final prefix = query.prefix ?? JsonApiClient.prefix;
    if (prefix != null && prefix.isNotEmpty) {
      endpoint = "$prefix/$endpoint";
    }

    queryParams.addAll(query.queryParams);
    return ApiRequest.request(
      endpoint,
      method: method,
      headers: headers,
      queryParams: queryParams,
      encode: encode,
      body: body,
    );
  }

  Future<List<T>?> get({Map<String, dynamic>? queryParams}) async {
    final responseJson = await request(queryParams: queryParams);
    final list = _parseModelList(responseJson?['data']);
    return list;
  }

  Future<T?> getOne({Map<String, dynamic>? queryParams}) async {
    final responseJson = await request(queryParams: queryParams);
    return _parseModel(responseJson?['data']);
  }

  Future<T?> find({Map<String, dynamic>? queryParams, String? findId}) async {
    final responseJson =
        await request(suffix: findId, queryParams: queryParams);
    return _parseModel(responseJson?['data']);
  }

  Future<T?> first({Map<String, dynamic>? queryParams}) async {
    return (await get(queryParams: queryParams))?.first;
  }

  Future<void> delete(String id, {Map<String, dynamic>? queryParams}) async {
    await request(method: 'DELETE', suffix: id, queryParams: queryParams);
  }

  Future<T?> save(BaseModel<T> model,
      {Map<String, dynamic>? queryParams}) async {
    final responseJson = await request(
      method: 'PATCH',
      suffix: model.id,
      queryParams: queryParams,
      body: model.toJson(),
    );
    return _parseModel(responseJson?['data']);
  }

  Future<T?> create(BaseModel<T> model,
      {Map<String, dynamic>? queryParams}) async {
    final responseJson = await request(
      method: 'POST',
      queryParams: queryParams,
      body: model.toJson(),
    );
    return _parseModel(responseJson?['data']);
  }

  Future<List<T>?> bulkUpdate(List<BaseModel<T>> models,
      {Map<String, dynamic>? queryParams}) async {
    final body = models.map((model) => model.toJson()).toList();
    return await multipleAction('bulk', method: 'POST', body: body);
  }

  Future<T?> singularAction(String action,
      {Map<String, dynamic>? queryParams}) async {
    final responseJson = await request(
      method: 'GET',
      suffix: '-actions/$action',
      queryParams: queryParams,
    );
    return _parseModel(responseJson?['data']);
  }

  Future<List<T>?> multipleAction(String action,
      {Map<String, dynamic>? queryParams, String? method, dynamic body}) async {
    final responseJson = await request(
        method: method ?? 'GET',
        suffix: '-actions/$action',
        queryParams: queryParams,
        body: body);
    return _parseModelList(responseJson?['data']);
  }

  Future<T?> attach<R>(String id, List<JsonApiRef<R>> refs,
      {Map<String, dynamic>? queryParams, String? relationship}) async {
    final isMany = refs.length > 1;
    final body = isMany ? toRefsListBody(refs) : toRefBody(refs.first);
    final responseJson = await request(
      method: isMany ? 'POST' : 'PATCH',
      suffix: '$id/relationships/${relationship ?? JsonApiClient.typesMap[R]}',
      queryParams: queryParams,
      encode: false,
      body: body,
    );
    return _parseModel(responseJson?['data']);
  }

  Future<T?> detach<R>(String id, List<JsonApiRef<R>> refs,
      {Map<String, dynamic>? queryParams}) async {
    final responseJson = await request(
      method: 'DELETE',
      suffix: '$id/relationships/${JsonApiClient.typesMap[R]}',
      queryParams: queryParams,
      encode: false,
      body: toRefsListBody(refs),
    );
    return _parseModel(responseJson?['data']);
  }

  Map<String, List<Map<String, dynamic>>> toRefsListBody<R>(
          List<JsonApiRef<R>> refs) =>
      {'data': refs.map((ref) => ref.toJson()).toList()};

  Map<String, dynamic> toRefBody<R>(JsonApiRef<R> ref) =>
      {'data': ref.toJson()};

  List<T>? _parseModelList(List<Map<String, dynamic>?>? responseJson) {
    return responseJson?.map<T>((json) => _parseModel(json)!).toList();
  }

  T? _parseModel(Map<String, dynamic>? responseJson) {
    return responseJson != null ? query.instanceFromJson(responseJson) : null;
  }
}
