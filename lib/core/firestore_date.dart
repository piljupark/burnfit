import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreDate {
  FirestoreDate._();

  static DateTime parse(Object? value, String fieldName) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String && value.trim().isNotEmpty) {
      final parsed = DateTime.tryParse(value.trim());
      if (parsed != null) return parsed;
    }
    if (value is int && value > 0) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    throw ArgumentError('$fieldName 날짜 형식이 올바르지 않습니다.');
  }

  static DateTime? parseNullable(Object? value, String fieldName) {
    if (value == null) return null;
    return parse(value, fieldName);
  }
}
