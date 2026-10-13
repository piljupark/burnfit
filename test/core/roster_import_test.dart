import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pt_solution_v2/core/roster_import.dart';

const _trainers = [
  (uid: 't1', name: '박코치'),
  (uid: 't2', name: '최코치'),
  (uid: 't3', name: '최코치'),
];

List<RosterPreviewRow> _check(
  List<List<Object?>> table, {
  String role = 'member',
  Map<String, String> joined = const {},
}) => RosterImport.check(
  table,
  role: role,
  centerId: 'c1',
  trainers: _trainers,
  joinedPhones: joined,
);

const _header = ['구분', '이름', '휴대폰', '담당 트레이너', 'PT 횟수', '시작일', '종료일'];

void main() {
  group('CSV 읽기', () {
    test('큰따옴표 칸 · 줄바꿈 · BOM', () {
      final rows = RosterImport.readTable(
        Uint8List.fromList(
          utf8.encode('﻿이름,휴대폰\r\n"김, 민지",010-1234-5678\n"따옴""표",01011112222'),
        ),
        '명단.csv',
      );
      expect(rows, [
        ['이름', '휴대폰'],
        ['김, 민지', '010-1234-5678'],
        ['따옴"표', '01011112222'],
      ]);
    });

    test('UTF-8이 아니면 안내', () {
      expect(
        () => RosterImport.readTable(
          Uint8List.fromList([0xC0, 0xCC, 0xB8, 0xA7]),
          'a.csv',
        ),
        throwsA(isA<RosterFileException>()),
      );
    });

    test('모르는 확장자', () {
      expect(
        () => RosterImport.readTable(Uint8List(0), 'a.txt'),
        throwsA(isA<RosterFileException>()),
      );
    });
  });

  test('엑셀 읽기: 숫자로 바뀐 번호 · 날짜 칸', () {
    final book = Excel.createExcel();
    final sheet = book[book.getDefaultSheet()!];
    sheet.appendRow([for (final h in _header) TextCellValue(h)]);
    sheet.appendRow([
      TextCellValue('회원'),
      TextCellValue('이서준'),
      IntCellValue(1012345678),
      TextCellValue('박코치'),
      IntCellValue(10),
      DateCellValue(year: 2026, month: 10, day: 1),
      DateCellValue(year: 2027, month: 1, day: 31),
    ]);
    final table = RosterImport.readTable(
      Uint8List.fromList(book.encode()!),
      '명단.xlsx',
    );
    final rows = _check(table);
    expect(rows.single.check, RosterCheck.ready);
    final e = rows.single.entry!;
    expect(e.phone, '010-1234-5678');
    expect(e.id, '01012345678');
    expect(e.trainerId, 't1');
    expect(e.ptTotal, 10);
    expect(e.ptStart, DateTime(2026, 10, 1));
    expect(e.ptEnd, DateTime(2027, 1, 31));
    expect(rows.single.message, '박코치 · PT 10회 (2026-10-01 ~ 2027-01-31)');
  });

  group('줄 검사', () {
    test('머리줄이 없으면 기본 순서 (이름 · 휴대폰 · 담당 · 횟수 · 시작 · 종료)', () {
      final rows = _check([
        ['김민지', '010-2222-3333'],
        ['이서준', '010-2222-4444', '박코치', 10],
      ]);
      expect(rows[0].entry!.role, 'member');
      expect(rows[0].message, '담당 없음 · PT 없음');
      expect(rows[1].entry!.trainerId, 't1');
      expect(rows[1].entry!.ptTotal, 10);
    });

    test('트레이너 탭: 이름 · 휴대폰만 쓰고 담당 · PT 칸은 무시', () {
      final rows = _check(role: 'trainer', [
        ['이름', '휴대폰', '담당 트레이너', 'PT 횟수'],
        ['정코치', '010-4444-5555', '박코치', 10],
      ]);
      final e = rows.single.entry!;
      expect(e.role, 'trainer');
      expect(e.trainerId, isNull);
      expect(e.ptTotal, isNull);
      expect(rows.single.message, '트레이너');
    });

    test("'구분' 칸이 있으면 다른 탭의 줄은 확인 필요", () {
      final member = _check([
        ['구분', '이름', '휴대폰'],
        ['회원', '김민지', '010-2222-3333'],
        ['트레이너', '정코치', '010-4444-5555'],
        ['', '빈구분', '010-4444-6666'],
      ]);
      expect(member[0].check, RosterCheck.ready);
      expect(member[1].message, '트레이너 줄은 트레이너 탭에서 올려 주세요');
      expect(member[2].check, RosterCheck.ready);
      final trainer = _check(role: 'trainer', [
        ['구분', '이름', '휴대폰'],
        ['회원', '김민지', '010-2222-3333'],
      ]);
      expect(trainer.single.message, '회원 줄은 회원 탭에서 올려 주세요');
    });

    test('머리줄 순서가 달라도 칸 이름으로 찾는다', () {
      final rows = _check([
        ['휴대폰', '이름', '횟수'],
        ['010-2222-3333', '김민지', '20회'],
      ]);
      expect(rows.single.entry!.name, '김민지');
      expect(rows.single.entry!.ptTotal, 20);
    });

    test('가입됨 · 확인 필요', () {
      final rows = _check(
        [
          _header,
          ['회원', '가입자', '010-9999-0000'],
          ['회원', '번호틀림', '02-123-4567'],
          ['회원', '중복일', '010-1111-2222'],
          ['회원', '중복이', '01011112222'],
          ['회원', '없는코치', '010-3333-4444', '김코치'],
          ['회원', '같은이름', '010-3333-5555', '최코치'],
          ['회원', '횟수틀림', '010-3333-6666', '', '0'],
          ['회원', '기간만', '010-3333-7777', '', '', '2026-10-01'],
          ['회원', '거꾸로', '010-3333-8888', '', 10, '2026-10-01', '2026-09-01'],
          ['손님', '구분틀림', '010-3333-9999'],
          ['회원', '김', '010-4444-0000'],
          ['회원', '날짜틀림', '010-4444-1111', '', 10, '10월 1일'],
        ],
        joined: {'010-9999-0000': '가입자'},
      );
      expect(rows[0].check, RosterCheck.joined);
      final problems = rows.skip(1).toList();
      expect(problems.every((r) => r.check == RosterCheck.problem), isTrue);
      expect(problems.map((r) => r.message).toList(), [
        '휴대폰 번호 형식을 확인해 주세요',
        '같은 번호가 2줄 있어요',
        '같은 번호가 2줄 있어요',
        "'김코치' 트레이너가 센터에 없어요",
        "'최코치' 이름의 트레이너가 둘 이상이에요",
        'PT 횟수는 1~500 숫자로 적어 주세요',
        '기간이 있으면 PT 횟수도 적어 주세요',
        '종료일이 시작일보다 앞서요',
        "구분은 '회원'이나 '트레이너'로 적어 주세요",
        '이름을 확인해 주세요 (2~30자)',
        '시작일 형식을 확인해 주세요 (2026-10-01)',
      ]);
      // 줄 번호는 파일 그대로 (머리줄 1)
      expect(problems.first.line, 3);
    });

    test('날짜 여러 형식', () {
      final rows = _check([
        _header,
        ['회원', '가나', '010-1000-0001', '', 1, '2026.10.01', '20261231'],
        ['회원', '다라', '010-1000-0002', '', 1, '2026/10/1', 46387],
      ]);
      expect(rows[0].entry!.ptStart, DateTime(2026, 10, 1));
      expect(rows[0].entry!.ptEnd, DateTime(2026, 12, 31));
      expect(rows[1].entry!.ptStart, DateTime(2026, 10, 1));
      // 엑셀 날짜 숫자
      expect(rows[1].entry!.ptEnd, DateTime(2026, 12, 31));
    });

    test('빈 파일 · 이름 칸 없는 머리줄', () {
      expect(() => _check([[], ['', '']]), throwsA(isA<RosterFileException>()));
      expect(
        () => _check([
          ['휴대폰', '메모'],
          ['010-1111-2222', 'x'],
        ]),
        throwsA(isA<RosterFileException>()),
      );
    });
  });
}
