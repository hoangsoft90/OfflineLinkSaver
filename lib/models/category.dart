import 'package:flutter/material.dart';

class Category {
  final String id;
  String name;
  String color; // hex color string like '#FF5722'
  int sortOrder;
  final DateTime createdAt;

  Category({
    required this.id,
    required this.name,
    this.color = '#2196F3',
    this.sortOrder = 0,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'color': color,
      'sort_order': sortOrder,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as String,
      name: map['name'] as String,
      color: map['color'] as String? ?? '#2196F3',
      sortOrder: map['sort_order'] as int? ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Category copyWith({
    String? name,
    String? color,
    int? sortOrder,
  }) {
    return Category(
      id: id,
      name: name ?? this.name,
      color: color ?? this.color,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt,
    );
  }

  /// Convert hex string to Color
  Color get toColor {
    final hex = color.replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }
}
