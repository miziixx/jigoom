class ChecklistItem {
  final String id;
  final String category;
  final String label;
  final String description;
  final bool isRequired;

  const ChecklistItem({
    required this.id,
    required this.category,
    required this.label,
    required this.description,
    this.isRequired = false,
  });
}

class ChecklistList {
  final String id;
  final String label;
  final List<ChecklistItem> items;
  const ChecklistList({required this.id, required this.label, required this.items});
}

const kChecklists = [
  ChecklistList(
    id: 'roadmap',
    label: 'APP ROADMAP',
    items: [
      ChecklistItem(id: 'rm_01', category: '기획', label: '앱의 목적 한 줄로 정하기', description: '"이 앱은 ___를 위한 앱이다"를 완성해야 합니다', isRequired: true),
      ChecklistItem(id: 'rm_02', category: '기획', label: '주요 사용자가 누구인지 정하기', description: '나 혼자 쓸 건지, 다른 사람도 쓸 건지 결정합니다', isRequired: true),
      ChecklistItem(id: 'rm_03', category: '기획', label: '핵심 기능 3가지 이하로 줄이기', description: '처음부터 기능이 너무 많으면 완성하기 어렵습니다', isRequired: true),
      ChecklistItem(id: 'rm_04', category: '설계', label: '화면 흐름 손으로 그려보기', description: '어떤 화면에서 어떤 화면으로 가는지 메모지에 그립니다', isRequired: true),
      ChecklistItem(id: 'rm_05', category: '설계', label: '저장할 데이터 목록 정하기', description: '앱이 저장해야 하는 정보가 무엇인지 적어봅니다', isRequired: true),
      ChecklistItem(id: 'rm_06', category: '설계', label: '폴더/파일 구조 계획하기', description: '코드를 어떻게 나눌지 대략적으로 정합니다'),
      ChecklistItem(id: 'rm_07', category: '개발', label: '기본 저장/불러오기 완성하기', description: '데이터가 저장되고 앱을 껐다 켜도 남아있는지 확인합니다', isRequired: true),
      ChecklistItem(id: 'rm_08', category: '개발', label: '핵심 기능 하나씩 완성하기', description: '한 번에 다 하려 하지 말고 하나 완성 후 다음으로 넘어갑니다', isRequired: true),
      ChecklistItem(id: 'rm_09', category: '개발', label: '추가/수정/삭제 모두 동작 확인', description: '데이터를 만들고, 고치고, 지우는 기능이 모두 작동하는지 확인합니다', isRequired: true),
      ChecklistItem(id: 'rm_10', category: '개발', label: '앱이 갑자기 꺼지지 않는지 확인', description: '다양한 상황에서 앱이 튕기지 않는지 테스트합니다', isRequired: true),
      ChecklistItem(id: 'rm_11', category: '다듬기', label: '자주 쓰는 동선이 편한지 확인', description: '핵심 기능까지 버튼 3번 이내로 도달하는지 확인합니다'),
      ChecklistItem(id: 'rm_12', category: '다듬기', label: '글씨 크기와 색상 통일하기', description: '화면마다 글씨 스타일이 제각각이면 정돈합니다'),
      ChecklistItem(id: 'rm_13', category: '다듬기', label: '오래된 코드/주석 정리하기', description: '쓰지 않는 코드를 지워서 파일을 깔끔하게 만듭니다'),
      ChecklistItem(id: 'rm_14', category: '테스트', label: '실제 폰에서 하루 이상 써보기', description: '에뮬레이터가 아닌 실제 기기로 실제 상황에서 사용해봅니다', isRequired: true),
      ChecklistItem(id: 'rm_15', category: '테스트', label: '다른 사람에게 써보게 하기', description: '만든 사람 외에 다른 사람이 헷갈리는 부분을 찾아냅니다'),
      ChecklistItem(id: 'rm_16', category: '출시', label: '앱 이름과 버전 번호 확인', description: '앱 이름, 버전(예: 1.0.0), 패키지 이름이 맞는지 확인합니다', isRequired: true),
      ChecklistItem(id: 'rm_17', category: '출시', label: '개인정보 처리방침 준비', description: '앱이 수집하는 정보가 있으면 방침 문서를 만들어야 합니다', isRequired: true),
      ChecklistItem(id: 'rm_18', category: '출시', label: '스토어 등록 정보 작성', description: '앱 설명, 스크린샷, 아이콘을 준비합니다', isRequired: true),
      ChecklistItem(id: 'rm_19', category: '출시', label: '최종 빌드(릴리즈) 생성', description: '배포용 APK/AAB를 만들고 설치 확인합니다', isRequired: true),
      ChecklistItem(id: 'rm_20', category: '운영', label: '사용 중 오류 발생 시 기록 방법 정하기', description: '실사용 중 문제가 생기면 어떻게 알고 고칠지 계획합니다'),
      ChecklistItem(id: 'rm_21', category: '운영', label: '다음 버전 기능 목록 만들기', description: '출시 후 추가할 기능 아이디어를 미리 모아둡니다'),
    ],
  ),
  ChecklistList(
    id: 'workflow',
    label: 'WORKFLOW',
    items: [
      ChecklistItem(id: 'wf_01', category: '시작', label: '오늘 고칠 것 한 가지만 정하기', description: '여러 개를 동시에 건드리면 뭐가 문제인지 모릅니다', isRequired: true),
      ChecklistItem(id: 'wf_02', category: '시작', label: '건드리지 말아야 할 파일 확인', description: '실수로 바꾸면 안 되는 파일을 미리 머릿속에 새깁니다', isRequired: true),
      ChecklistItem(id: 'wf_03', category: '시작', label: '현재 git 상태 확인', description: '`git status`로 변경된 파일이 없는 깨끗한 상태인지 확인합니다'),
      ChecklistItem(id: 'wf_04', category: '작업', label: '변경할 파일만 수정하기', description: '필요 없는 파일까지 고치지 않았는지 확인합니다', isRequired: true),
      ChecklistItem(id: 'wf_05', category: '작업', label: '기존 기능이 그대로인지 확인', description: '고친 것 이외의 기능이 망가지지 않았는지 확인합니다', isRequired: true),
      ChecklistItem(id: 'wf_06', category: '확인', label: 'flutter analyze 실행', description: '경고/오류가 늘어나지 않았는지 확인합니다', isRequired: true),
      ChecklistItem(id: 'wf_07', category: '확인', label: '실제 기기에서 직접 눌러보기', description: '에뮬레이터가 아닌 실제 폰에서 바뀐 기능을 확인합니다', isRequired: true),
      ChecklistItem(id: 'wf_08', category: '확인', label: '엣지 케이스 생각해보기', description: '빈 화면, 데이터 없을 때, 긴 텍스트 등 특이한 상황을 눌러봅니다'),
      ChecklistItem(id: 'wf_09', category: '마무리', label: '변경 내용 한 줄로 기록하기', description: '무엇을 왜 고쳤는지 짧게 적어둡니다 (CHANGELOG 또는 메모)', isRequired: true),
      ChecklistItem(id: 'wf_10', category: '마무리', label: '다음에 할 작업 미리 적어두기', description: '오늘 작업하다 발견한 다음 할 일을 잊기 전에 기록합니다'),
    ],
  ),
  ChecklistList(
    id: 'release',
    label: 'RELEASE CHECK',
    items: [
      ChecklistItem(id: 'rc_01', category: '앱 정보', label: '앱 이름이 맞는지 확인', description: 'AndroidManifest / pubspec에서 앱 이름이 원하는 이름인지 확인합니다', isRequired: true),
      ChecklistItem(id: 'rc_02', category: '앱 정보', label: '버전 번호 올바른지 확인', description: 'pubspec.yaml의 version이 이전 출시보다 높은지 확인합니다', isRequired: true),
      ChecklistItem(id: 'rc_03', category: '앱 정보', label: '패키지 이름(앱 ID) 확인', description: 'com.example.xxx가 아닌 실제 앱 ID로 되어 있는지 확인합니다', isRequired: true),
      ChecklistItem(id: 'rc_04', category: '앱 정보', label: '앱 아이콘 정상 표시 확인', description: '런처에서 아이콘이 깨지거나 기본 아이콘이 아닌지 확인합니다', isRequired: true),
      ChecklistItem(id: 'rc_05', category: '권한', label: '사용하는 권한 목록 확인', description: '실제로 쓰는 권한만 선언되어 있는지 확인합니다', isRequired: true),
      ChecklistItem(id: 'rc_06', category: '권한', label: '권한 요청 문구가 자연스러운지 확인', description: '사용자에게 보이는 권한 설명이 이해하기 쉬운지 확인합니다'),
      ChecklistItem(id: 'rc_07', category: '법적 사항', label: '개인정보 처리방침 URL 동작 확인', description: '스토어에 등록할 방침 링크가 열리는지 확인합니다', isRequired: true),
      ChecklistItem(id: 'rc_08', category: '법적 사항', label: '수집하는 정보 목록이 정확한지 확인', description: '방침에 쓴 내용과 앱이 실제로 수집하는 정보가 일치하는지 확인합니다', isRequired: true),
      ChecklistItem(id: 'rc_09', category: '데이터', label: '앱 삭제 시 데이터가 남는지 확인', description: '기기에 개인 데이터가 남아야 하는지/지워져야 하는지 의도대로 동작하는지 확인합니다'),
      ChecklistItem(id: 'rc_10', category: '데이터', label: '앱 업데이트 후 기존 데이터 유지 확인', description: '이전 버전 데이터가 새 버전에서도 정상 로드되는지 확인합니다', isRequired: true),
      ChecklistItem(id: 'rc_11', category: 'UI', label: '작은 화면(360dp)에서 깨지지 않는지 확인', description: '화면이 작은 폰에서도 버튼/텍스트가 잘리지 않는지 확인합니다', isRequired: true),
      ChecklistItem(id: 'rc_12', category: 'UI', label: '텍스트가 너무 크게 설정된 환경에서 확인', description: '접근성 설정에서 글씨 크기를 크게 했을 때 UI가 무너지지 않는지 확인합니다'),
      ChecklistItem(id: 'rc_13', category: '기능', label: '알림/일정 기능 정상 동작 확인', description: '알림이 설정한 시각에 오는지, 일정이 표시되는지 확인합니다'),
      ChecklistItem(id: 'rc_14', category: '기능', label: '앱 강제 종료 후 데이터 유지 확인', description: '갑자기 꺼진 후에도 데이터가 사라지지 않는지 확인합니다', isRequired: true),
      ChecklistItem(id: 'rc_15', category: '빌드', label: '릴리즈 APK/AAB 빌드 성공 확인', description: '디버그가 아닌 릴리즈 빌드가 오류 없이 생성되는지 확인합니다', isRequired: true),
      ChecklistItem(id: 'rc_16', category: '빌드', label: '릴리즈 빌드를 새 기기에 설치 확인', description: '이미 설치된 기기가 아닌 새 기기에 APK를 올려 테스트합니다', isRequired: true),
      ChecklistItem(id: 'rc_17', category: '빌드', label: '서명(키스토어) 설정 확인', description: '릴리즈 빌드에 올바른 키스토어가 적용되어 있는지 확인합니다', isRequired: true),
      ChecklistItem(id: 'rc_18', category: '스토어', label: '스토어 앱 설명문 오탈자 확인', description: '등록할 앱 설명에 맞춤법 오류가 없는지 확인합니다'),
      ChecklistItem(id: 'rc_19', category: '스토어', label: '스크린샷이 최신 UI인지 확인', description: '실제 앱과 다른 오래된 스크린샷을 올리지 않았는지 확인합니다'),
      ChecklistItem(id: 'rc_20', category: '최종', label: 'QA 체크리스트 PASS 기록 확인', description: 'DEV Center QA 탭에서 모든 항목을 확인했는지 점검합니다', isRequired: true),
    ],
  ),
];
