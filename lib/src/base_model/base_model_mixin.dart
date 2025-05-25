import 'package:json_annotation/json_annotation.dart';
import 'package:json_api_client/src/base_model/base_model.dart';

mixin BaseModelMixin<T> {
  String? id;
  late String type;

  @JsonKey(includeFromJson: false, includeToJson: false)
  BaseModel? parent;

  String get findId => id!.toString();

  Map<String, dynamic> toJson();

  Map<String, dynamic> postDefaultJson(Map<String, dynamic> json) {
    json['id'] = this.id;
    return json;
  }
}
