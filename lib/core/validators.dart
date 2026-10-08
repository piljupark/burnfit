import 'birth_date.dart';

class Validators {
  Validators._();

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return '이메일을 입력해주세요.';
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!regex.hasMatch(value.trim())) return '올바른 이메일 형식이 아닙니다.';
    return null;
  }

  /// 새 비밀번호 최소 길이 (회원·트레이너·관리자 가입 공통).
  /// 서버의 관리자 가입 검증(functions/admin_setup.js `LIMITS.passwordMin`)과 같다.
  static const int passwordMinLength = 8;

  /// 새 비밀번호(가입)용 검증.
  static String? password(String? value, {int minLength = passwordMinLength}) {
    if (value == null || value.isEmpty) return '비밀번호를 입력해주세요.';
    if (value.length < minLength) return '비밀번호는 $minLength자 이상이어야 합니다.';
    return null;
  }

  /// 로그인·본인 확인용: 이미 있는 비밀번호라 길이 기준은 따지지 않는다
  /// (기준이 바뀌기 전에 만든 짧은 비밀번호도 로그인할 수 있어야 한다).
  static String? existingPassword(String? value) {
    if (value == null || value.isEmpty) return '비밀번호를 입력해주세요.';
    return null;
  }

  static String? name(String? value) {
    if (value == null || value.trim().isEmpty) return '이름을 입력해주세요.';
    if (value.trim().length < 2) return '이름은 2자 이상이어야 합니다.';
    return null;
  }

  static String? required(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) return '$fieldName을(를) 입력해주세요.';
    return null;
  }

  static String? positiveNumber(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) return '$fieldName을(를) 입력해주세요.';
    final n = double.tryParse(value.trim());
    if (n == null || n <= 0) return '올바른 $fieldName을(를) 입력해주세요.';
    return null;
  }

  /// 생년월일 8자리(yyyyMMdd). 실제 있는 날짜이고 1900년 이후 · 오늘 이전이어야 한다.
  static String? birthDate(String? value) {
    final v = value?.trim() ?? '';
    if (v.length != 8) return '생년월일을 8자리로 입력해주세요. (예: 19900101)';
    final date = parseBirthDate(v);
    if (date == null || date.year < 1900 || date.isAfter(DateTime.now())) {
      return '올바른 생년월일을 입력해주세요.';
    }
    return null;
  }

  /// 선택 입력 숫자: 비었으면 null, 숫자가 아니거나 범위 밖이면 ArgumentError(안내 문구).
  static double? optionalNumberInRange(
    String text,
    String label, {
    required double min,
    required double max,
  }) {
    final t = text.trim();
    if (t.isEmpty) return null;
    final v = double.tryParse(t);
    if (v == null) throw ArgumentError('$label을(를) 숫자로 입력해주세요.');
    if (v < min || v > max) {
      String fmt(double n) =>
          n == n.roundToDouble() ? n.toStringAsFixed(0) : '$n';
      throw ArgumentError('$label은(는) ${fmt(min)}~${fmt(max)} 사이로 입력해주세요.');
    }
    return v;
  }

  /// 신체 정보 입력 → UserProfile 값 (온보딩·신체 정보 수정 공통 범위).
  static ({double? height, double? weight, double? muscleMass, double? bodyFat})
  bodyMetrics({
    required String height,
    required String weight,
    required String muscleMass,
    required String bodyFat,
  }) {
    return (
      height: optionalNumberInRange(height, '키', min: 50, max: 250),
      weight: optionalNumberInRange(weight, '체중', min: 20, max: 300),
      muscleMass: optionalNumberInRange(muscleMass, '골격근량', min: 5, max: 100),
      bodyFat: optionalNumberInRange(bodyFat, '체지방량', min: 1, max: 150),
    );
  }
}
