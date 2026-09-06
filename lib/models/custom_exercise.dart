import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/firestore_date.dart';
import 'workout.dart';

class CustomExercise {
  final String id;
  final String memberId;
  final String name;
  final WorkoutCategory category;
  final DateTime createdAt;

  const CustomExercise({
    required this.id,
    required this.memberId,
    required this.name,
    required this.category,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'memberId': memberId,
      'name': name,
      'category': category.name,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory CustomExercise.fromMap(Map<String, dynamic> map) {
    return CustomExercise(
      id: map['id'] as String,
      memberId: map['memberId'] as String,
      name: map['name'] as String,
      category: WorkoutCategory.values.firstWhere(
        (c) => c.name == map['category'],
        orElse: () => WorkoutCategory.chest,
      ),
      createdAt: FirestoreDate.parse(map['createdAt'], 'createdAt'),
    );
  }
}
