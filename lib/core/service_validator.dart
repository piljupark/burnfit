import 'dart:io';

import 'constants.dart';

class ServiceValidator {
  ServiceValidator._();

  static final _datePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');
  static final _timePattern = RegExp(r'^\d{2}:\d{2}$');

  static void requireText(String value, String fieldName) {
    if (value.trim().isEmpty) {
      throw ArgumentError('$fieldName 값이 비어 있습니다.');
    }
  }

  static void requireDateKey(String value, String fieldName) {
    if (!_datePattern.hasMatch(value) || DateTime.tryParse(value) == null) {
      throw ArgumentError('$fieldName 형식이 올바르지 않습니다.');
    }
  }

  static void requireOptionalTime(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) return;
    if (!_timePattern.hasMatch(value.trim())) {
      throw ArgumentError('$fieldName 형식이 올바르지 않습니다.');
    }
  }

  static void requirePositiveInt(int value, String fieldName) {
    if (value <= 0) {
      throw ArgumentError('$fieldName 값은 0보다 커야 합니다.');
    }
  }

  static void requireNonNegativeInt(int value, String fieldName) {
    if (value < 0) {
      throw ArgumentError('$fieldName 값은 0 이상이어야 합니다.');
    }
  }

  static void requireOptionalPositiveDouble(double? value, String fieldName) {
    if (value != null && value <= 0) {
      throw ArgumentError('$fieldName 값은 0보다 커야 합니다.');
    }
  }

  static void requireNonNegativeDouble(double value, String fieldName) {
    if (value < 0) {
      throw ArgumentError('$fieldName 값은 0 이상이어야 합니다.');
    }
  }

  static void requireOptionalPositiveInt(int? value, String fieldName) {
    if (value != null && value <= 0) {
      throw ArgumentError('$fieldName 값은 0보다 커야 합니다.');
    }
  }

  static void requireImageCount(int count) {
    if (count > AppConstants.imageMaxCount) {
      throw ArgumentError(
        '이미지는 최대 ${AppConstants.imageMaxCount}장까지 업로드할 수 있습니다.',
      );
    }
  }

  static void requireImageLength(int length) {
    if (length <= 0) {
      throw ArgumentError('이미지 파일이 비어 있습니다.');
    }
    if (length > AppConstants.imageMaxBytes) {
      throw ArgumentError(
        '이미지는 ${AppConstants.imageMaxMegabytes}MB 이하만 업로드할 수 있습니다.',
      );
    }
  }

  static Future<void> requireImageFile(File file) async {
    final length = await file.length();
    requireImageLength(length);
  }
}
