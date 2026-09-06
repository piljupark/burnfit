import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/firestore_date.dart';

class Inbody {
  final String id;
  final String centerId;
  final String memberId;
  final String memberName;
  final String trainerId;
  final String measurementDate;
  final double weight;
  final double? muscleMass;
  final double? bodyFat;
  final double? bodyFatPercent;
  final double? bmi;
  final double? bmr;
  final int? visceralFat;
  final double? leftArm;
  final double? rightArm;
  final double? trunk;
  final double? leftLeg;
  final double? rightLeg;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Inbody({
    required this.id,
    required this.centerId,
    required this.memberId,
    required this.memberName,
    required this.trainerId,
    required this.measurementDate,
    required this.weight,
    this.muscleMass,
    this.bodyFat,
    this.bodyFatPercent,
    this.bmi,
    this.bmr,
    this.visceralFat,
    this.leftArm,
    this.rightArm,
    this.trunk,
    this.leftLeg,
    this.rightLeg,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'centerId': centerId,
      'memberId': memberId,
      'memberName': memberName,
      'trainerId': trainerId,
      'measurementDate': measurementDate,
      'weight': weight,
      'muscleMass': muscleMass,
      'bodyFat': bodyFat,
      'bodyFatPercent': bodyFatPercent,
      'bmi': bmi,
      'bmr': bmr,
      'visceralFat': visceralFat,
      'leftArm': leftArm,
      'rightArm': rightArm,
      'trunk': trunk,
      'leftLeg': leftLeg,
      'rightLeg': rightLeg,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory Inbody.fromMap(Map<String, dynamic> map) {
    return Inbody(
      id: map['id'] as String,
      centerId: map['centerId'] as String,
      memberId: map['memberId'] as String,
      memberName: map['memberName'] as String? ?? '',
      trainerId: map['trainerId'] as String,
      measurementDate: map['measurementDate'] as String,
      weight: (map['weight'] as num).toDouble(),
      muscleMass: (map['muscleMass'] as num?)?.toDouble(),
      bodyFat: (map['bodyFat'] as num?)?.toDouble(),
      bodyFatPercent: (map['bodyFatPercent'] as num?)?.toDouble(),
      bmi: (map['bmi'] as num?)?.toDouble(),
      bmr: (map['bmr'] as num?)?.toDouble(),
      visceralFat: map['visceralFat'] as int?,
      leftArm: (map['leftArm'] as num?)?.toDouble(),
      rightArm: (map['rightArm'] as num?)?.toDouble(),
      trunk: (map['trunk'] as num?)?.toDouble(),
      leftLeg: (map['leftLeg'] as num?)?.toDouble(),
      rightLeg: (map['rightLeg'] as num?)?.toDouble(),
      createdAt: FirestoreDate.parse(map['createdAt'], 'createdAt'),
      updatedAt: FirestoreDate.parse(map['updatedAt'], 'updatedAt'),
    );
  }
}
