import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/firestore_date.dart';

enum UserRole { admin, trainer, member }

enum UserStatus { pending, approved, rejected }

enum Gender {
  male('남성'),
  female('여성'),
  other('기타');

  final String label;

  const Gender(this.label);
}

class ShareSettings {
  final bool workout;
  final bool meal;
  final bool body;

  const ShareSettings({
    this.workout = true,
    this.meal = true,
    this.body = true,
  });

  Map<String, dynamic> toMap() {
    return {'workout': workout, 'meal': meal, 'body': body};
  }

  factory ShareSettings.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const ShareSettings();
    return ShareSettings(
      workout: map['workout'] as bool? ?? true,
      meal: map['meal'] as bool? ?? true,
      body: map['body'] as bool? ?? true,
    );
  }

  ShareSettings copyWith({bool? workout, bool? meal, bool? body}) {
    return ShareSettings(
      workout: workout ?? this.workout,
      meal: meal ?? this.meal,
      body: body ?? this.body,
    );
  }
}

class UserProfile {
  /// 목표 글자 수 상한 (규칙은 여유 있게 200자까지 허용).
  static const int goalMaxLength = 100;

  final double? height;
  final double? weight;
  final double? muscleMass;
  final double? bodyFat;
  final String? goal;

  const UserProfile({
    this.height,
    this.weight,
    this.muscleMass,
    this.bodyFat,
    this.goal,
  });

  double? get bmi {
    if (height == null || weight == null || height! <= 0) return null;
    final h = height! / 100;
    return weight! / (h * h);
  }

  double? get bodyFatPercent {
    if (weight == null || bodyFat == null || weight! <= 0) return null;
    return (bodyFat! / weight!) * 100;
  }

  Map<String, dynamic> toMap() {
    return {
      'height': height,
      'weight': weight,
      'muscleMass': muscleMass,
      'bodyFat': bodyFat,
      'goal': goal,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      height: (map['height'] as num?)?.toDouble(),
      weight: (map['weight'] as num?)?.toDouble(),
      muscleMass: (map['muscleMass'] as num?)?.toDouble(),
      bodyFat: (map['bodyFat'] as num?)?.toDouble(),
      goal: map['goal'] as String?,
    );
  }

  UserProfile copyWith({
    double? height,
    double? weight,
    double? muscleMass,
    double? bodyFat,
    String? goal,
  }) {
    return UserProfile(
      height: height ?? this.height,
      weight: weight ?? this.weight,
      muscleMass: muscleMass ?? this.muscleMass,
      bodyFat: bodyFat ?? this.bodyFat,
      goal: goal ?? this.goal,
    );
  }
}

class AppUser {
  final String uid;
  final String email;
  final String name;
  final UserRole role;
  final UserStatus status;
  final String centerId;
  final String centerName;
  final String? trainerId;
  final String? trainerName;
  final String? birthDate;
  final Gender? gender;
  final UserProfile? profile;
  final ShareSettings shareSettings;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AppUser({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    required this.status,
    required this.centerId,
    required this.centerName,
    this.trainerId,
    this.trainerName,
    this.birthDate,
    this.gender,
    this.profile,
    this.shareSettings = const ShareSettings(),
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isAdmin => role == UserRole.admin;
  bool get isTrainer => role == UserRole.trainer;
  bool get isMember => role == UserRole.member;
  bool get isApproved => status == UserStatus.approved;

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'role': role.name,
      'status': status.name,
      'centerId': centerId,
      'centerName': centerName,
      'trainerId': trainerId,
      'trainerName': trainerName,
      'birthDate': birthDate,
      'gender': gender?.name,
      'profile': profile?.toMap(),
      'shareSettings': shareSettings.toMap(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: _requiredString(map, 'uid'),
      email: _requiredString(map, 'email'),
      name: _requiredString(map, 'name'),
      role: _parseRole(map['role']),
      status: _parseStatus(map['status']),
      centerId: _requiredString(map, 'centerId'),
      centerName: _requiredString(map, 'centerName'),
      trainerId: map['trainerId'] as String?,
      trainerName: map['trainerName'] as String?,
      birthDate: map['birthDate'] as String?,
      gender: map['gender'] != null
          ? Gender.values.firstWhere(
              (g) => g.name == map['gender'],
              orElse: () => Gender.other,
            )
          : null,
      profile: map['profile'] != null
          ? UserProfile.fromMap(map['profile'] as Map<String, dynamic>)
          : null,
      shareSettings: ShareSettings.fromMap(
        map['shareSettings'] as Map<String, dynamic>?,
      ),
      createdAt: FirestoreDate.parse(map['createdAt'], 'createdAt'),
      updatedAt: FirestoreDate.parse(map['updatedAt'], 'updatedAt'),
    );
  }

  static String _requiredString(Map<String, dynamic> map, String fieldName) {
    final value = map[fieldName];
    if (value is String && value.trim().isNotEmpty) return value;
    throw ArgumentError('$fieldName 값이 비어 있습니다.');
  }

  static UserRole _parseRole(Object? value) {
    if (value is String) {
      for (final role in UserRole.values) {
        if (role.name == value) return role;
      }
    }
    throw ArgumentError('사용자 역할이 올바르지 않습니다.');
  }

  static UserStatus _parseStatus(Object? value) {
    if (value is String) {
      for (final status in UserStatus.values) {
        if (status.name == value) return status;
      }
    }
    throw ArgumentError('사용자 상태가 올바르지 않습니다.');
  }

  AppUser copyWith({
    String? name,
    UserStatus? status,
    String? trainerId,
    String? trainerName,
    String? birthDate,
    Gender? gender,
    UserProfile? profile,
    ShareSettings? shareSettings,
    DateTime? updatedAt,
  }) {
    return AppUser(
      uid: uid,
      email: email,
      name: name ?? this.name,
      role: role,
      status: status ?? this.status,
      centerId: centerId,
      centerName: centerName,
      trainerId: trainerId ?? this.trainerId,
      trainerName: trainerName ?? this.trainerName,
      birthDate: birthDate ?? this.birthDate,
      gender: gender ?? this.gender,
      profile: profile ?? this.profile,
      shareSettings: shareSettings ?? this.shareSettings,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
