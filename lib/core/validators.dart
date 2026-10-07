class Validators {
  Validators._();

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return '이메일을 입력해주세요.';
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!regex.hasMatch(value.trim())) return '올바른 이메일 형식이 아닙니다.';
    return null;
  }

  static String? password(String? value, {int minLength = 6}) {
    if (value == null || value.isEmpty) return '비밀번호를 입력해주세요.';
    if (value.length < minLength) return '비밀번호는 $minLength자 이상이어야 합니다.';
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
}
