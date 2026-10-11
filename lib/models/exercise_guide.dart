/// 종목 설명 한 개 (기본 운동만, 자료는 `core/exercise_guide_data.dart`).
class ExerciseGuide {
  /// 옮겨 온 free-exercise-db 항목 id. 직접 쓴 설명이면 null.
  final String? source;

  /// 주로 쓰는 근육 · 함께 쓰는 근육 (근육 그림 부품의 묶음 이름, [muscleLabel]로 우리말).
  final List<String> primary;
  final List<String> secondary;
  final ExerciseEquipment equipment;
  final ExerciseLevel level;

  /// 운동 방법 (3~5단계).
  final List<String> steps;

  const ExerciseGuide({
    required this.source,
    required this.primary,
    required this.secondary,
    required this.equipment,
    required this.level,
    required this.steps,
  });
}

enum ExerciseEquipment {
  barbell('바벨'),
  dumbbell('덤벨'),
  cable('케이블'),
  machine('머신'),
  bodyweight('맨몸'),
  kettlebell('케틀벨'),
  band('밴드'),
  ezBar('EZ바'),
  smith('스미스 머신'),
  plate('플레이트'),
  other('기타');

  final String label;

  const ExerciseEquipment(this.label);
}

enum ExerciseLevel {
  beginner('초급'),
  intermediate('중급'),
  advanced('고급');

  final String label;

  const ExerciseLevel(this.label);
}

/// 근육 묶음 이름 → 우리말.
String muscleLabel(String key) => _muscleLabels[key] ?? key;

const Map<String, String> _muscleLabels = {
  'chest': '가슴',
  'shoulders': '어깨',
  'obliques': '옆구리',
  'abs': '복근',
  'abductor': '엉덩이 바깥',
  'biceps': '이두',
  'calves': '종아리',
  'forearm': '전완',
  'glutes': '둔근',
  'harmstrings': '햄스트링',
  'lats': '광배',
  'upper_back': '등 가운데',
  'quads': '허벅지 앞',
  'trapezius': '승모근',
  'triceps': '삼두',
  'adductors': '허벅지 안쪽',
  'lower_back': '허리',
  'neck': '목',
};
