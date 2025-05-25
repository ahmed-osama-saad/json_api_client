class JsonApiRef<T> {
  const JsonApiRef({required this.id, required this.type});

  final String id;
  final String type;

  factory JsonApiRef.fromJson(Map<String, dynamic> json) =>
      JsonApiRef<T>(id: json['id'], type: json['type']);

  Map<String, dynamic> toJson() => {'id': id, 'type': type};
}
