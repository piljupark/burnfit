/// 가입 동의 문구 (개인정보보호위원회 표준 동의서 형식: 목적 · 항목 · 보유 기간 · 거부 권리와 불이익).
///
/// - 문구를 바꾸면 [version]을 올린다 → 이미 동의한 사용자도 다음 실행 때 다시 동의한다
///   (`startRouteFor`가 동의 화면으로 보낸다).
/// - 건강 정보는 민감정보라 개인정보 동의와 **따로** 받는다 (회원만).
/// - 2026-10-13 1판: 표준 문구에 앱 실제 내용을 채운 것. 말투는 '~합니다'(2026-10-14, 내용 같아 판 유지). 센터 · 법무 확인 뒤 확정한다
///   (`[센터명]` 자리 · 보관 기간 · 국외 이전).
class ConsentTerms {
  ConsentTerms._();

  /// 지금 동의서 판. 사용자 문서 `consents.version`과 비교한다.
  static const int version = 1;

  static const String versionLabel = '1판 (2026-10-13)';

  static const privacy = ConsentDocument(
    title: '개인정보 수집 · 이용',
    summary: '이름 · 이메일 · 휴대폰 · 생년월일 · 성별 · 운동 · 식단 기록',
    intro: '센터 회원 관리와 PT 지도를 위해 아래와 같이 개인정보를 수집 · 이용합니다.',
    rows: [
      ConsentRow(
        items: '이름, 이메일, 비밀번호, 휴대폰 번호',
        purpose: '가입 · 로그인, 본인 확인, 센터 명단과 맞추기',
      ),
      ConsentRow(items: '생년월일, 성별', purpose: '운동 · 식단 지도, 신체 정보 계산'),
      ConsentRow(
        items: '운동 기록, 식단 사진 · 메모, PT 일정 · 이용 내역',
        purpose: '기록 보관, 트레이너 피드백, PT 관리',
      ),
      ConsentRow(items: '기기 알림 정보(푸시 토큰)', purpose: '일정 · 피드백 알림'),
    ],
    retention:
        '회원 탈퇴 시까지 보관하며, 탈퇴 시 지체 없이 파기합니다. 단, PT 계약 · 이용 내역은 분쟁 대응을 위해 '
        '개인을 알아볼 수 없도록 처리하여 3년간 보관한 뒤 파기합니다.',
    viewers: '본인, 담당 트레이너, 센터 관리자 (휴대폰 번호는 본인과 센터 관리자만 열람합니다)',
    refusal: '동의를 거부할 권리가 있습니다. 다만 동의하지 않으면 회원 가입이 제한됩니다.',
  );

  static const health = ConsentDocument(
    title: '건강 정보 수집 · 이용',
    summary: '키 · 몸무게 · 인바디 · 체성분 (민감정보)',
    intro:
        '트레이너의 운동 · 식단 지도에 필요한 건강 정보를 수집 · 이용합니다. '
        '건강 정보는 민감정보로, 개인정보 수집 · 이용과 별도로 동의를 받습니다.',
    rows: [
      ConsentRow(items: '키, 몸무게, 골격근량, 체지방', purpose: '신체 변화 기록, PT 지도'),
      ConsentRow(
        items: '인바디 측정값 (체성분, 기초대사량 등)',
        purpose: '체성분 변화 확인, 식단 목표 정하기',
      ),
    ],
    retention: '회원 탈퇴 시까지 보관하며, 탈퇴 시 지체 없이 파기합니다.',
    viewers: '본인, 담당 트레이너, 센터 관리자. 다른 센터와 외부에는 제공하지 않습니다.',
    refusal: '동의를 거부할 권리가 있습니다. 다만 PT 지도에 반드시 필요한 정보이므로 동의하지 않으면 회원 가입이 제한됩니다.',
  );

  /// 처리를 맡기는 곳 (전문 아래 공통).
  static const String processor = '서비스 운영을 위해 Google(Firebase)에 정보의 저장과 처리를 위탁합니다.';
}

class ConsentDocument {
  final String title;

  /// 동의 줄 아래 한 줄 요약
  final String summary;
  final String intro;
  final List<ConsentRow> rows;
  final String retention;
  final String viewers;
  final String refusal;

  const ConsentDocument({
    required this.title,
    required this.summary,
    required this.intro,
    required this.rows,
    required this.retention,
    required this.viewers,
    required this.refusal,
  });
}

class ConsentRow {
  final String items;
  final String purpose;

  const ConsentRow({required this.items, required this.purpose});
}
