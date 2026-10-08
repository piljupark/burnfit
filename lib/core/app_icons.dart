import 'package:flutter/widgets.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

/// 앱 아이콘 — Phosphor 하나로 통일한다.
///
/// - 기본은 Regular (선 1.5 — 시안 아이콘 선 1.8~2에 가장 가깝다). 켜진 상태(선택된 탭, 좋아요함, 재생 중)만 Fill.
/// - 14px 이하 배지 안 체크만 Bold([checkBold]).
/// - 색은 ink(보조 위치는 body/mute). 아이콘에 accent·danger를 입히지 않는다
///   (파괴적 행의 아이콘은 라벨과 같이 danger).
/// - Material Icons·Iconsax·이모지를 섞지 않는다. 여기 없는 아이콘은 PhosphorIconsRegular에서 고른다.
class AppIcons {
  AppIcons._();

  // ── 탭 (Regular / Fill 짝) ───────────────────────────────────────────────────
  static const IconData home = PhosphorIconsRegular.house;
  static const IconData homeFill = PhosphorIconsFill.house;
  static const IconData workout = PhosphorIconsRegular.barbell;
  static const IconData workoutFill = PhosphorIconsFill.barbell;
  static const IconData calendar = PhosphorIconsRegular.calendarBlank;
  static const IconData calendarFill = PhosphorIconsFill.calendarBlank;
  static const IconData profile = PhosphorIconsRegular.user;
  static const IconData profileFill = PhosphorIconsFill.user;
  static const IconData members = PhosphorIconsRegular.users;
  static const IconData membersFill = PhosphorIconsFill.users;
  static const IconData trainers = PhosphorIconsRegular.identificationBadge;
  static const IconData trainersFill = PhosphorIconsFill.identificationBadge;

  // ── 탐색 · 공통 행동 ───────────────────────────────────────────────────────
  static const IconData back = PhosphorIconsRegular.caretLeft;
  static const IconData forward = PhosphorIconsRegular.caretRight;
  static const IconData chevronDown = PhosphorIconsRegular.caretDown;
  static const IconData chevronUp = PhosphorIconsRegular.caretUp;
  static const IconData close = PhosphorIconsRegular.x;
  static const IconData add = PhosphorIconsRegular.plus;
  static const IconData remove = PhosphorIconsRegular.minus;
  static const IconData more = PhosphorIconsRegular.dotsThree;
  static const IconData edit = PhosphorIconsRegular.pencilSimple;
  static const IconData trash = PhosphorIconsRegular.trash;
  static const IconData search = PhosphorIconsRegular.magnifyingGlass;
  static const IconData refresh = PhosphorIconsRegular.arrowClockwise;
  static const IconData undo = PhosphorIconsRegular.arrowCounterClockwise;
  static const IconData check = PhosphorIconsRegular.check;
  static const IconData checkBold = PhosphorIconsBold.check;

  /// 목록 줄 끝·월 이동 화살표 (시안 선 2~2.2에 맞춰 Bold)
  static const IconData chevronLeftBold = PhosphorIconsBold.caretLeft;
  static const IconData chevronRightBold = PhosphorIconsBold.caretRight;
  static const IconData theme = PhosphorIconsRegular.circleHalf;
  static const IconData checkCircle = PhosphorIconsRegular.checkCircle;
  static const IconData checkCircleFill = PhosphorIconsFill.checkCircle;
  static const IconData circle = PhosphorIconsRegular.circle;
  static const IconData filter = PhosphorIconsRegular.funnelSimple;
  static const IconData sort = PhosphorIconsRegular.sortAscending;
  static const IconData share = PhosphorIconsRegular.shareNetwork;
  static const IconData link = PhosphorIconsRegular.linkSimple;
  static const IconData download = PhosphorIconsRegular.downloadSimple;
  static const IconData upload = PhosphorIconsRegular.uploadSimple;
  static const IconData settings = PhosphorIconsRegular.gear;
  static const IconData signOut = PhosphorIconsRegular.signOut;
  static const IconData info = PhosphorIconsRegular.info;
  static const IconData warning = PhosphorIconsRegular.warningCircle;
  static const IconData lock = PhosphorIconsRegular.lockSimple;
  static const IconData eye = PhosphorIconsRegular.eye;
  static const IconData eyeSlash = PhosphorIconsRegular.eyeSlash;
  static const IconData email = PhosphorIconsRegular.envelopeSimple;
  static const IconData phone = PhosphorIconsRegular.phone;

  // ── 도메인 ─────────────────────────────────────────────────────────────────
  static const IconData bell = PhosphorIconsRegular.bell;
  static const IconData megaphone = PhosphorIconsRegular.megaphone;
  static const IconData meal = PhosphorIconsRegular.bowlSteam;
  static const IconData feedback = PhosphorIconsRegular.chatText;
  static const IconData note = PhosphorIconsRegular.notePencil;
  static const IconData clipboard = PhosphorIconsRegular.clipboardText;
  static const IconData chart = PhosphorIconsRegular.chartLine;
  static const IconData chartBar = PhosphorIconsRegular.chartBar;
  static const IconData dashboard = PhosphorIconsRegular.squaresFour;
  static const IconData clock = PhosphorIconsRegular.clock;
  static const IconData timer = PhosphorIconsRegular.timer;
  static const IconData calendarCheck = PhosphorIconsRegular.calendarCheck;
  static const IconData calendarPlus = PhosphorIconsRegular.calendarPlus;
  static const IconData cardio = PhosphorIconsRegular.personSimpleRun;
  static const IconData inbody = PhosphorIconsRegular.scales;
  static const IconData heartbeat = PhosphorIconsRegular.heartbeat;
  static const IconData fire = PhosphorIconsRegular.flame;
  static const IconData trendUp = PhosphorIconsRegular.trendUp;
  static const IconData trendDown = PhosphorIconsRegular.trendDown;
  static const IconData camera = PhosphorIconsRegular.camera;
  static const IconData image = PhosphorIconsRegular.image;
  static const IconData userPlus = PhosphorIconsRegular.userPlus;
  static const IconData user = PhosphorIconsRegular.user;
  static const IconData center = PhosphorIconsRegular.buildings;
  static const IconData archive = PhosphorIconsRegular.archive;
  static const IconData play = PhosphorIconsFill.play;
  static const IconData pause = PhosphorIconsRegular.pause;
  static const IconData stop = PhosphorIconsRegular.stop;
  static const IconData target = PhosphorIconsRegular.target;
  static const IconData list = PhosphorIconsRegular.listBullets;
  static const IconData heart = PhosphorIconsRegular.heart;
  static const IconData heartFill = PhosphorIconsFill.heart;
}
