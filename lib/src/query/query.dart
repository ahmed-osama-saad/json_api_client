import 'package:json_api_client/json_api_client.dart';

abstract class Query<T extends BaseModel<T>>
    with ModelQuery<T>, JsonEndpoint<T> {
  String? prefix;
  String? parentEndpoint;

  Future<List<T>?> get({Map<String, dynamic>? queryParams}) async {
    final request = QueryRequest<T>(this);
    return await request.get(queryParams: queryParams);
  }

  Future<T?> getOne({Map<String, dynamic>? queryParams}) async {
    final request = QueryRequest<T>(this);
    final responseJson = await request.getOne(queryParams: queryParams);
    return responseJson;
  }

  Future<T?> find({Map<String, dynamic>? queryParams, String? findId}) async {
    final request = QueryRequest<T>(this);
    return await request.find(findId: findId);
  }

  Future<T?> first({Map<String, dynamic>? queryParams}) async {
    List<T>? models = await get(queryParams: queryParams);
    return models != null && models.isNotEmpty ? models.first : null;
  }

  Query<T> getFrom<R extends BaseModel<R>>(Query<R> parentQuery, String id) {
    final parentType = parentQuery.generateEndpoint();
    parentEndpoint = "$parentType/$id";
    return this;
  }

  Future<T?> save(BaseModel<T> model,
      {Map<String, dynamic>? queryParams}) async {
    final request = QueryRequest<T>(this);
    return await request.save(model, queryParams: queryParams);
  }

  Future<T?> create(BaseModel<T> model,
      {Map<String, dynamic>? queryParams}) async {
    final request = QueryRequest<T>(this);
    return await request.create(model, queryParams: queryParams);
  }

  Future<T?> singularAction(String action,
      {Map<String, dynamic>? queryParams}) async {
    final request = QueryRequest<T>(this);
    return await request.singularAction(action, queryParams: queryParams);
  }

  Future<List<T>?> multipleAction(String action,
      {Map<String, dynamic>? queryParams}) async {
    final request = QueryRequest<T>(this);
    return await request.multipleAction(action, queryParams: queryParams);
  }

  Future<List<T>?> bulkUpdate(List<BaseModel<T>> models,
      {Map<String, dynamic>? queryParams}) async {
    final request = QueryRequest<T>(this);
    return await request.bulkUpdate(models, queryParams: queryParams);
  }

  Future<T?> attach<R extends BaseModel<R>>(String id, List<R> models,
      {Map<String, dynamic>? queryParams, String? relationship}) async {
    final request = QueryRequest<T>(this);
    final refs = BaseModel.modelsToRefs(models);
    return await request.attach(id, refs,
        relationship: relationship, queryParams: queryParams);
  }

  Future<T?> detach<R extends BaseModel<R>>(String id, List<R> models,
      {Map<String, dynamic>? queryParams}) async {
    final request = QueryRequest<T>(this);
    final refs = BaseModel.modelsToRefs(models);
    return await request.detach(id, refs, queryParams: queryParams);
  }

  Future<void> delete(String id, {Map<String, dynamic>? queryParams}) async {
    final request = QueryRequest<T>(this);
    return await request.delete(id, queryParams: queryParams);
  }
}
