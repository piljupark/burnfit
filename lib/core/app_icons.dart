import 'package:flutter/widgets.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

/// 앱 아이콘 — Phosphor 하나로 통일한다.
///
/// - 기본은 Light. 켜진 상태(선택된 탭, 좋아요함, 재생 중)만 Fill.
/// - 14px 이하 배지 안 체크만 Bold([checkBold]).
/// - 색은 ink(보조 위치는 body/mute). 아이콘에 accent·danger를 입히지 않는다
///   (파괴적 행의 아이콘은 라벨과 같이 danger).
/// - Material Icons·Iconsax·이모지를 섞지 않는다. 여기 없는 아이콘은 PhosphorIconsLight에서 고른다.
class AppIcons {
  AppIcons._();

  // ── 탭 (Light / Fill 짝) ───────────────────────────────────────────────────
  static const IconData home = PhosphorIconsLight.house;
  static const IconData homeFill = PhosphorIconsFill.house;
  static const IconData workout = PhosphorIconsLight.barbell;
  static const IconData workoutFill = PhosphorIconsFill.barbell;
  static const IconData calendar = PhosphorIconsLight.calendarBlank;
  static const IconData calendarFill = PhosphorIconsFill.calendarBlank;
  static const IconData profile = PhosphorIconsLight.userCircle;
  static const IconData profileFill = PhosphorIconsFill.userCircle;
  static const IconData members = PhosphorIconsLight.users;
  static const IconData membersFill = PhosphorIconsFill.users;
  static const IconData trainers = PhosphorIconsLight.identificationBadge;
  static const IconData trainersFill = PhosphorIconsFill.identificationBadge;

  // ── 탐색 · 공통 행동 ───────────────────────────────────────────────────────
  static const IconData back = PhosphorIconsLight.caretLeft;
  static const IconData forward = PhosphorIconsLight.caretRight;
  static const IconData chevronDown = PhosphorIconsLight.caretDown;
  static const IconData chevronUp = PhosphorIconsLight.caretUp;
  static const IconData close = PhosphorIconsLight.x;
  static const IconData add = PhosphorIconsLight.plus;
  static const IconData remove = PhosphorIconsLight.minus;
  static const IconData more = PhosphorIconsLight.dotsThree;
  static const IconData edit = PhosphorIconsLight.pencilSimple;
  static const IconData trash = PhosphorIconsLight.trash;
  static const IconData search = PhosphorIconsLight.magnifyingGlass;
  static const IconData refresh = PhosphorIconsLight.arrowClockwise;
  static const IconData undo = PhosphorIconsLight.arrowCounterClockwise;
  static const IconData check = PhosphorIconsLight.check;
  static const IconData checkBold = PhosphorIconsBold.check;
  static const IconData theme = PhosphorIconsLight.circleHalf;
  static const IconData checkCircle = PhosphorIconsLight.checkCircle;
  static const IconData checkCircleFill = PhosphorIconsFill.checkCircle;
  static const IconData circle = PhosphorIconsLight.circle;
  static const IconData filter = PhosphorIconsLight.funnelSimple;
  static const IconData sort = PhosphorIconsLight.sortAscending;
  static const IconData share = PhosphorIconsLight.shareNetwork;
  static const IconData link = PhosphorIconsLight.linkSimple;
  static const IconData download = PhosphorIconsLight.downloadSimple;
  static const IconData upload = PhosphorIconsLight.uploadSimple;
  static const IconData settings = PhosphorIconsLight.gear;
  static const IconData signOut = PhosphorIconsLight.signOut;
  static const IconData info = PhosphorIconsLight.info;
  static const IconData warning = PhosphorIconsLight.warningCircle;
  static const IconData lock = PhosphorIconsLight.lockSimple;
  static const IconData eye = PhosphorIconsLight.eye;
  static const IconData eyeSlash = PhosphorIconsLight.eyeSlash;
  static const IconData email = PhosphorIconsLight.envelopeSimple;
  static const IconData phone = PhosphorIconsLight.phone;

  // ── 도메인 ─────────────────────────────────────────────────────────────────
  static const IconData bell = PhosphorIconsLight.bell;
  static const IconData meal = PhosphorIconsLight.forkKnife;
  static const IconData feedback = PhosphorIconsLight.chatCircleText;
  static const IconData note = PhosphorIconsLight.notePencil;
  static const IconData clipboard = PhosphorIconsLight.clipboardText;
  static const IconData chart = PhosphorIconsLight.chartLine;
  static const IconData chartBar = PhosphorIconsLight.chartBar;
  static const IconData dashboard = PhosphorIconsLight.squaresFour;
  static const IconData clock = PhosphorIconsLight.clock;
  static const IconData timer = PhosphorIconsLight.timer;
  static const IconData calendarCheck = PhosphorIconsLight.calendarCheck;
  static const IconData calendarPlus = PhosphorIconsLight.calendarPlus;
  static const IconData cardio = PhosphorIconsLight.personSimpleRun;
  static const IconData inbody = PhosphorIconsLight.scales;
  static const IconData heartbeat = PhosphorIconsLight.heartbeat;
  static const IconData fire = PhosphorIconsLight.flame;
  static const IconData trendUp = PhosphorIconsLight.trendUp;
  static const IconData trendDown = PhosphorIconsLight.trendDown;
  static const IconData camera = PhosphorIconsLight.camera;
  static const IconData image = PhosphorIconsLight.image;
  static const IconData userPlus = PhosphorIconsLight.userPlus;
  static const IconData user = PhosphorIconsLight.user;
  static const IconData center = PhosphorIconsLight.buildings;
  static const IconData archive = PhosphorIconsLight.archive;
  static const IconData play = PhosphorIconsFill.play;
  static const IconData pause = PhosphorIconsLight.pause;
  static const IconData stop = PhosphorIconsLight.stop;
  static const IconData target = PhosphorIconsLight.target;
  static const IconData list = PhosphorIconsLight.listBullets;
  static const IconData heart = PhosphorIconsLight.heart;
  static const IconData heartFill = PhosphorIconsFill.heart;
}
