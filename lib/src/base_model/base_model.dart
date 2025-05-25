import 'package:json_annotation/json_annotation.dart';
import 'package:json_api_client/json_api_client.dart';

@JsonSerializable()
abstract class BaseModel<T extends BaseModel<T>> with BaseModelMixin<T> {
  BaseModel({String? id}) {
    this.id = id;
    type = JsonApiClient.typesMap[T]!;
  }

  @override
  Map<String, dynamic> toJson() {
    throw UnimplementedError();
  }

  JsonApiRef<T> toRef() {
    // TODO: Add exception meaningful if id is null
    return JsonApiRef(id: id!, type: type);
  }

  static List<JsonApiRef<T>> modelsToRefs<T extends BaseModel<T>>(
      List<BaseModel<T>> models) {
    return models.map((model) => model.toRef()).toList();
  }
}
