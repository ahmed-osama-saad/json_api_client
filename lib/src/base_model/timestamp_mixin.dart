import 'package:json_annotation/json_annotation.dart';
mixin Timestamps {
  @JsonKey(name: 'created_at')
  int? createdAt;

  @JsonKey(name: 'updated_at')
  int? updatedAt;

  DateTime get createdDate => DateTime.fromMillisecondsSinceEpoch(createdAt! * 1000);
  DateTime get updatedDate => DateTime.fromMillisecondsSinceEpoch(updatedAt! * 1000);

  set createdDate(DateTime date) => createdAt = date.millisecondsSinceEpoch ~/ 1000;
  set updatedDate(DateTime date) => updatedAt = date.millisecondsSinceEpoch ~/ 1000;
}
