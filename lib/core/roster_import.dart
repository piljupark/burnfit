import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../models/roster_entry.dart';
import 'validators.dart';

/// 명단 파일을 읽지 못했을 때. 안내 문구가 그대로 보이게 ArgumentError로 둔다
/// (`AppFeedback.errorMessage`가 message를 쓴다).
class RosterFileException extends ArgumentError {
  RosterFileException(String super.message);
}

/// 명단 파일 한 줄의 검사 결과 (시안 09 '명단 올리기').
enum RosterCheck {
  /// 같은 번호의 승인된 계정이 이미 있다 → 저장하지 않는다.
  joined,

  /// 미가입 → 명단에 저장한다.
  ready,

  /// 확인 필요 → 빼고 저장한다.
  problem,
}

class RosterPreviewRow {
  /// 파일의 줄 번호 (1부터, 머리줄 포함)
  final int line;
  final String name;
  final RosterCheck check;

  /// 결과 한 줄 ('박코치 · PT 10회', '휴대폰 번호 형식을 확인해 주세요' 등)
  final String message;

  /// [RosterCheck.ready]일 때 저장할 값
  final RosterEntry? entry;

  const RosterPreviewRow({
    required this.line,
    required this.name,
    required this.check,
    required this.message,
    this.entry,
  });
}

/// 명단 파일(.xlsx · .csv) 읽기와 줄 검사. 서버를 부르지 않는 순수 함수라 테스트한다.
///
/// 회원 탭 · 트레이너 탭에서 따로 올린다 ([check]의 `role`).
/// - 회원: 이름 · 휴대폰 · 담당 트레이너 · PT 횟수 · 시작일 · 종료일
/// - 트레이너: 이름 · 휴대폰
/// 첫 줄에 '이름'이나 '휴대폰'이 있으면 머리줄로 보고 칸 이름으로 순서를 찾는다
/// (없으면 위 순서). 필수는 이름 · 휴대폰. '구분' 칸이 있으면 다른 구분 줄은 확인 필요로 뺀다.
class RosterImport {
  RosterImport._();

  /// 칸 안내 (올리기 화면)
  static List<String> columnsFor(String role) => role == 'trainer'
      ? const ['이름', '휴대폰']
      : const ['이름', '휴대폰', '담당 트레이너', 'PT 횟수', '시작일', '종료일'];

  static const int maxRows = 1000;
  static const int maxPtSessions = 500;

  // ── 파일 → 표 ──────────────────────────────────────────────────────────────

  /// 첫 시트를 줄 × 칸 표로. 칸 값은 String · num · DateTime · null.
  static List<List<Object?>> readTable(Uint8List bytes, String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.csv')) return _readCsv(bytes);
    if (lower.endsWith('.xlsx')) return _readXlsx(bytes);
    throw RosterFileException('엑셀(.xlsx)이나 CSV(.csv) 파일을 골라 주세요.');
  }

  static List<List<Object?>> _readXlsx(Uint8List bytes) {
    final Excel book;
    try {
      book = Excel.decodeBytes(bytes);
    } catch (_) {
      throw RosterFileException(
        '엑셀 파일을 읽지 못했어요. 엑셀에서 .xlsx로 다시 저장해 주세요.',
      );
    }
    if (book.tables.isEmpty) {
      throw RosterFileException('엑셀 파일에 시트가 없어요.');
    }
    final sheet = book.tables.values.first;
    return [
      for (final row in sheet.rows) [for (final c in row) _cell(c?.value)],
    ];
  }

  static Object? _cell(CellValue? v) => switch (v) {
    null => null,
    TextCellValue() => v.value.toString(),
    IntCellValue() => v.value,
    DoubleCellValue() => v.value,
    DateCellValue() => DateTime(v.year, v.month, v.day),
    DateTimeCellValue() => DateTime(v.year, v.month, v.day),
    _ => v.toString(),
  };

  static List<List<Object?>> _readCsv(Uint8List bytes) {
    String text;
    try {
      text = utf8.decode(bytes);
    } on FormatException {
      // 한국어 엑셀의 'CSV' 저장은 UTF-8이 아니다.
      throw RosterFileException(
        "CSV 글자를 읽지 못했어요. 엑셀에서 'CSV UTF-8'로 저장하거나 .xlsx로 올려 주세요.",
      );
    }
    if (text.startsWith('﻿')) text = text.substring(1);
    return parseCsv(text);
  }

  /// 큰따옴표 칸(안의 쉼표 · 줄바꿈 · "" 포함)을 지원하는 CSV 읽기.
  static List<List<Object?>> parseCsv(String text) {
    final rows = <List<Object?>>[];
    var row = <Object?>[];
    final cell = StringBuffer();
    var quoted = false;
    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      if (quoted) {
        if (ch == '"') {
          if (i + 1 < text.length && text[i + 1] == '"') {
            cell.write('"');
            i++;
          } else {
            quoted = false;
          }
        } else {
          cell.write(ch);
        }
      } else if (ch == '"') {
        quoted = true;
      } else if (ch == ',') {
        row.add(cell.toString());
        cell.clear();
      } else if (ch == '\n' || ch == '\r') {
        if (ch == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
        row.add(cell.toString());
        cell.clear();
        rows.add(row);
        row = <Object?>[];
      } else {
        cell.write(ch);
      }
    }
    if (cell.isNotEmpty || row.isNotEmpty) {
      row.add(cell.toString());
      rows.add(row);
    }
    return rows;
  }

  // ── 표 → 검사 ──────────────────────────────────────────────────────────────

  /// 줄마다 가입됨 · 미가입 · 확인 필요를 가린다.
  ///
  /// - [trainers]: 같은 센터의 승인된 트레이너 (담당 이름 → id)
  /// - [joinedPhones]: 이미 승인된 계정의 번호 → 이름
  static List<RosterPreviewRow> check(
    List<List<Object?>> table, {
    required String role,
    required String centerId,
    required List<({String uid, String name})> trainers,
    required Map<String, String> joinedPhones,
  }) {
    // 빈 줄은 건너뛰되 줄 번호는 파일 그대로 둔다.
    final lines = <(int, List<Object?>)>[
      for (var i = 0; i < table.length; i++)
        if (table[i].any((c) => _text(c).isNotEmpty)) (i + 1, table[i]),
    ];
    if (lines.isEmpty) {
      throw RosterFileException('파일에 줄이 없어요.');
    }

    final isTrainerFile = role == 'trainer';
    var cols = _defaultColumns;
    final first = lines.first.$2.map(_text).toList();
    if (first.any((t) => t.contains('이름') || t.contains('휴대폰'))) {
      cols = _columnsFromHeader(first);
      lines.removeAt(0);
    }
    if (isTrainerFile) {
      // 트레이너 명단은 담당 · PT 칸을 쓰지 않는다
      cols = (
        role: cols.role,
        name: cols.name,
        phone: cols.phone,
        trainer: -1,
        ptTotal: -1,
        ptStart: -1,
        ptEnd: -1,
      );
    }
    if (cols.name < 0 || cols.phone < 0) {
      throw RosterFileException("머리줄에 '이름'과 '휴대폰' 칸이 있어야 해요.");
    }
    if (lines.length > maxRows) {
      throw RosterFileException('한 번에 $maxRows줄까지 올릴 수 있어요.');
    }

    Object? at(List<Object?> row, int col) =>
        col >= 0 && col < row.length ? row[col] : null;

    // 같은 번호가 몇 줄인지 먼저 센다.
    final phoneCounts = <String, int>{};
    for (final (_, row) in lines) {
      final p = _phone(at(row, cols.phone));
      if (p != null) phoneCounts[p] = (phoneCounts[p] ?? 0) + 1;
    }

    final result = <RosterPreviewRow>[];
    for (final (line, row) in lines) {
      final name = _text(at(row, cols.name));
      RosterPreviewRow problem(String message) => RosterPreviewRow(
        line: line,
        name: name.isEmpty ? '이름 없음' : name,
        check: RosterCheck.problem,
        message: message,
      );

      // '구분' 칸이 있으면 이 탭의 구분과 같은지만 본다 (비면 이 탭의 구분)
      final roleText = _text(at(row, cols.role));
      if (roleText.isNotEmpty) {
        final isMemberText = roleText == '회원' || roleText == 'member';
        final isTrainerText = roleText == '트레이너' || roleText == 'trainer';
        if (!isMemberText && !isTrainerText) {
          result.add(problem("구분은 '회원'이나 '트레이너'로 적어 주세요"));
          continue;
        }
        if (isTrainerText != isTrainerFile) {
          result.add(
            problem(
              isTrainerText
                  ? '트레이너 줄은 트레이너 탭에서 올려 주세요'
                  : '회원 줄은 회원 탭에서 올려 주세요',
            ),
          );
          continue;
        }
      }
      if (name.length < 2 || name.length > 30) {
        result.add(problem('이름을 확인해 주세요 (2~30자)'));
        continue;
      }
      final phone = _phone(at(row, cols.phone));
      if (phone == null) {
        result.add(problem('휴대폰 번호 형식을 확인해 주세요'));
        continue;
      }
      final dup = phoneCounts[phone] ?? 0;
      if (dup > 1) {
        result.add(problem('같은 번호가 $dup줄 있어요'));
        continue;
      }
      final joinedName = joinedPhones[phone];
      if (joinedName != null) {
        result.add(
          RosterPreviewRow(
            line: line,
            name: name,
            check: RosterCheck.joined,
            message: joinedName == name ? '이미 가입했어요' : '이미 가입했어요 ($joinedName)',
          ),
        );
        continue;
      }

      String? trainerId;
      String? trainerName;
      int? ptTotal;
      DateTime? ptStart;
      DateTime? ptEnd;
      if (role == 'member') {
        final t = _text(at(row, cols.trainer));
        if (t.isNotEmpty) {
          final found = trainers.where((x) => x.name.trim() == t).toList();
          if (found.isEmpty) {
            result.add(problem("'$t' 트레이너가 센터에 없어요"));
            continue;
          }
          if (found.length > 1) {
            result.add(problem("'$t' 이름의 트레이너가 둘 이상이에요"));
            continue;
          }
          trainerId = found.first.uid;
          trainerName = found.first.name;
        }
        final totalCell = at(row, cols.ptTotal);
        if (_text(totalCell).isNotEmpty) {
          ptTotal = _int(totalCell);
          if (ptTotal == null || ptTotal < 1 || ptTotal > maxPtSessions) {
            result.add(problem('PT 횟수는 1~$maxPtSessions 숫자로 적어 주세요'));
            continue;
          }
        }
        final startCell = at(row, cols.ptStart);
        final endCell = at(row, cols.ptEnd);
        if (_text(startCell).isNotEmpty) {
          ptStart = _date(startCell);
          if (ptStart == null) {
            result.add(problem('시작일 형식을 확인해 주세요 (2026-10-01)'));
            continue;
          }
        }
        if (_text(endCell).isNotEmpty) {
          ptEnd = _date(endCell);
          if (ptEnd == null) {
            result.add(problem('종료일 형식을 확인해 주세요 (2027-01-31)'));
            continue;
          }
        }
        if (ptTotal == null && (ptStart != null || ptEnd != null)) {
          result.add(problem('기간이 있으면 PT 횟수도 적어 주세요'));
          continue;
        }
        if (ptStart != null && ptEnd != null && ptEnd.isBefore(ptStart)) {
          result.add(problem('종료일이 시작일보다 앞서요'));
          continue;
        }
      }

      final entry = RosterEntry(
        id: RosterEntry.idFor(phone),
        centerId: centerId,
        role: role,
        name: name,
        phone: phone,
        trainerId: trainerId,
        trainerName: trainerName,
        ptTotal: ptTotal,
        ptStart: ptStart,
        ptEnd: ptEnd,
        updatedAt: DateTime.now(),
      );
      result.add(
        RosterPreviewRow(
          line: line,
          name: name,
          check: RosterCheck.ready,
          message: summary(entry),
          entry: entry,
        ),
      );
    }
    return result;
  }

  /// 명단 줄 요약: '박코치 · PT 10회 (2026-10-01 ~ 2027-01-31)' / '담당 없음 · PT 없음' / '트레이너'.
  static String summary(RosterEntry e) {
    if (e.isTrainer) return '트레이너';
    String d(DateTime x) =>
        '${x.year}-${x.month.toString().padLeft(2, '0')}-${x.day.toString().padLeft(2, '0')}';
    final period = e.ptStart == null && e.ptEnd == null
        ? ''
        : ' (${e.ptStart == null ? '' : d(e.ptStart!)} ~ ${e.ptEnd == null ? '' : d(e.ptEnd!)})';
    return [
      e.trainerName ?? '담당 없음',
      e.ptTotal == null ? 'PT 없음' : 'PT ${e.ptTotal}회$period',
    ].join(' · ');
  }

  // ── 칸 값 ──────────────────────────────────────────────────────────────────

  /// 머리줄이 없을 때: 이름 · 휴대폰 · 담당 트레이너 · PT 횟수 · 시작일 · 종료일 (트레이너는 앞 둘만)
  static const _defaultColumns = (
    role: -1,
    name: 0,
    phone: 1,
    trainer: 2,
    ptTotal: 3,
    ptStart: 4,
    ptEnd: 5,
  );

  static ({
    int role,
    int name,
    int phone,
    int trainer,
    int ptTotal,
    int ptStart,
    int ptEnd,
  })
  _columnsFromHeader(List<String> header) {
    int find(bool Function(String) test) => header.indexWhere(test);
    return (
      role: find((h) => h.contains('구분') || h.contains('역할')),
      name: find((h) => h.contains('이름') && !h.contains('담당')),
      phone: find(
        (h) => h.contains('휴대폰') || h.contains('전화') || h.contains('연락처'),
      ),
      trainer: find((h) => h.contains('담당') || h.contains('트레이너')),
      ptTotal: find((h) => h.contains('횟수')),
      ptStart: find((h) => h.contains('시작')),
      ptEnd: find((h) => h.contains('종료') || h.contains('만료')),
    );
  }

  static String _text(Object? v) {
    if (v == null) return '';
    if (v is double && v == v.roundToDouble()) return v.toInt().toString();
    return v.toString().trim();
  }

  /// 엑셀이 숫자로 바꿔 앞 0이 빠진 번호(1012345678)도 받는다.
  static String? _phone(Object? v) {
    var digits = _text(v).replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 10 && digits.startsWith('1')) digits = '0$digits';
    return Validators.normalizePhone(digits);
  }

  static int? _int(Object? v) {
    if (v is int) return v;
    if (v is double) return v == v.roundToDouble() ? v.toInt() : null;
    return int.tryParse(_text(v).replaceAll('회', '').trim());
  }

  /// 날짜 칸: 엑셀 날짜 · 엑셀 날짜 숫자 · '2026-10-01' · '2026.10.01' · '2026/10/01' · '20261001'.
  static DateTime? _date(Object? v) {
    if (v is DateTime) return DateTime(v.year, v.month, v.day);
    if (v is num) {
      final n = v.toInt();
      if (n >= 19000101 && n <= 21001231) return _ymd(n.toString());
      // 엑셀 날짜 숫자 (1900 기준 일 수)
      if (n > 20000 && n < 80000) {
        final d = DateTime(1899, 12, 30).add(Duration(days: n));
        return DateTime(d.year, d.month, d.day);
      }
      return null;
    }
    final t = _text(v);
    final m = RegExp(r'^(\d{4})[-./ ](\d{1,2})[-./ ](\d{1,2})\.?$').firstMatch(t);
    if (m != null) {
      return _valid(
        int.parse(m.group(1)!),
        int.parse(m.group(2)!),
        int.parse(m.group(3)!),
      );
    }
    if (RegExp(r'^\d{8}$').hasMatch(t)) return _ymd(t);
    return null;
  }

  static DateTime? _ymd(String s) => _valid(
    int.parse(s.substring(0, 4)),
    int.parse(s.substring(4, 6)),
    int.parse(s.substring(6, 8)),
  );

  static DateTime? _valid(int y, int m, int d) {
    if (y < 2000 || y > 2100 || m < 1 || m > 12 || d < 1 || d > 31) {
      return null;
    }
    final date = DateTime(y, m, d);
    return date.month == m ? date : null;
  }
}
