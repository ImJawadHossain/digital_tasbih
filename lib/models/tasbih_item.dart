class TasbihItem {
  String id;
  String name;
  int count;
  int targetLimit;
  Map<String, int> history; // Key: 'YYYY-MM-DD', Value: count for that day

  TasbihItem({
    required this.id,
    required this.name,
    this.count = 0,
    required this.targetLimit,
    Map<String, int>? history,
  }) : history = history ?? {};

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'count': count,
      'targetLimit': targetLimit,
      'history': history,
    };
  }

  factory TasbihItem.fromJson(Map<String, dynamic> json) {
    return TasbihItem(
      id: json['id'],
      name: json['name'],
      count: json['count'],
      targetLimit: json['targetLimit'],
      history: json['history'] != null 
          ? Map<String, int>.from(json['history']) 
          : {},
    );
  }
}
