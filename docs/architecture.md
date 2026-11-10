# 구현 구조

Flutter 3.41.2 / Dart 3.11.0. iOS·Android는 sqflite, 웹 미리보기는 package:web의 localStorage. 하나의 Flutter 화면을 반응형으로 배치한다. 웹용 별도 HTML 모조 앱은 없다.

## 현재 작성 흐름

Workspace는 마지막 활성 페이지를 즉시 보여 주며, 기록이 없으면 저장하지 않은 WritingPage 초안을 표시한다. 탭/포커스/스크롤만으로는 저장하지 않는다. LibraryController.saveDraft가 첫 실제 입력 또는 원문 메모를 기존 초안과 같은 page/record ID로 저장한다. PageEditor의 키와 TextEditingController를 유지해 첫 한글 조합도 다시 설정하지 않는다. 오류 안내·원문 표시가 생겨도 writing-surface 키를 가진 Expanded를 유지한다.

새 종이는 첫 입력까지 메모리 초안이다. 앱을 닫으면 쓰지 않은 초안만 사라지고 마지막 저장 글은 유지한다. 기존 글을 이후 새 책으로 묶을 때는 addBook + bindRecord로 같은 기록을 묶으며 빈 기록을 추가 생성하지 않는다. 데이터 형식과 DB 스키마는 바꾸지 않았다.

collection_sheet.dart는 필요할 때 여는 글/책 보관함이다. tools_screen.dart는 종이·잉크·글꼴과 펜/줄 가이드를 한 시트에서 독립 선택한다. 원문·페이지·동기화도 보조 시트이며 기존 계정 보호·저장 실패/재시도·기존 기기 기록 가져오기를 유지한다. 작성 화면은 폭 760 이하의 한 면으로 적응하고, 마케팅 배경과 휴대폰 프레임은 사용하지 않는다. 아래 첨부 이미지 개편 기록은 이전 UI 구조다.

현재 종이 화면은 paper.dart의 PaperBackdrop이 최대 폭 760의 연속된 면지·왼쪽 음영을 담당한다. 면지 소재는 24% 강도의 정적인 RepaintBoundary이며 입력/접근성 트리에서 제외한다. PageEditor는 별도 종이 카드 없이 실제 TextField와 읽기 전용 펜 레이어를 올린다. WritingGuides는 실제 본문 패딩·행 높이·스크롤을 읽어 줄 가이드를 그린다. writing_chrome.dart의 WritingHeader/WritingFooter가 최소 조작부를 담당한다. 브랜드 이름은 책과 구분하고 작은 투명 잉크 표식을 사용한다. 포커스·키보드·크기 변경은 레이아웃만 조정하며 controller·selection·composing을 되쓰지 않는다.

- lib/data/model.dart: Book, WritingRecord(bookId nullable), WritingPage(recordId, number, text, selection, scroll), Library(activePageId, writing). 버전 1 JSON 및 참조 구조 검증.
- lib/data/library_controller.dart: 사용자 동작, 변경 스냅샷의 순차 저장, 저장 상태와 재시도. 저장 순서가 역전되지 않도록 Future 체인을 사용한다.
- lib/data/sqlite_store.dart: 네 개의 관계형 테이블, 외래 키, 현재 버전 3. 이전 버전 1·2의 파일을 자동 이전한다. 부모를 REPLACE로 삭제하지 않고 갱신한다. 각 스냅샷은 트랜잭션으로 저장한다.
- lib/data/web_store.dart: 버전 1 단일 키 writing-human.library.v1. 동기·원자적인 setItem을 호출하며 할당량/접근 오류는 UI까지 전달한다. 모바일의 SQLite와 저장 구현은 다르다.
- lib/main.dart: 저장소를 연 뒤 기존 기록을 읽는다. 실패하면 복구 화면을 표시하며 빈 라이브러리로 대체하지 않는다.
- lib/ui/workspace.dart: 책장, 책 생성, 편집. 본문 controller는 페이지마다 한 번 생성하고 입력 중 되쓰지 않는다. TextEditingValue를 관찰해서 조합 중 텍스트도 보관하되 IME composing 영역은 재실행 시 복원하지 않는다. 선택 영역은 UTF-16 offset이며 복원 시 범위를 제한한다.
- lib/ui/paper.dart: 공통 종이/잉크 팔레트, 면지 이미지와 얕은 왼쪽 음영, 잉크 표식, 줄 가이드와 보관함의 린넨 표지. 소재는 RepaintBoundary로 편집과 분리하며 포인터·접근성 트리에서 제외한다. 애니메이션은 없다. lib/ui/writing_chrome.dart는 상단/하단의 실제 조작부를 담당한다. 소재 경로와 프롬프트는 docs/visual-assets.md를 따른다.

## 개발 중 서체 연결

WritingHumanDevelopment family를 pubspec.yaml에 등록했다. 0.006은 현대 한글 11,172자·자모·ASCII·문장부호를 담은 실제 TTF이며 반복 자모를 TrueType composite으로 공유한다. OpenType ccmp는 현대 초성+중성 및 받침을 완성형과 같은 윤곽으로 조합한다. 본문은 기존
TextField와 TextEditingController를 유지하고 TextStyle의 family/fallback만
바꾼다. 개발 TTF의 미지원 글자는 NanumMyeongjo → NanumGothic → 플랫폼
대체 글꼴로 표시한다. 문자열·선택 영역·composing을 나누거나 다시 설정하지 않는다.

WritingStyle.useDevelopmentTypeface는 기본 false인 optional JSON bool이다.
기존 fontIndex 0–2와 DB 버전 3을 유지하여 예전 데이터의 선택을 바꾸지 않는다.
동기화 병합에서는 fontIndex와 개발 서체 여부를 한 선택으로 처리하며 종이·펜과
독립적으로 합친다. 서버는 optional bool의 타입을 검증한다. 기존 서버도 style의
추가 필드를 보존하므로 인증이나 요청 구조 변경은 없다.

`?demo=typeface`는 DemoStore에서 개발 서체 선택만 활성화한 합성 예시다.
실제 기록에 적용하려면 사용자가 쓰기 도구에서 선택한다.

## 저장과 복원

본문, 선택 영역, 본문의 스크롤 변경마다 저장 요청을 큐에 넣는다. 마지막 열린 페이지와 책장/편집 화면 여부도 저장한다. 스크롤은 초기 레이아웃 후 유효 범위로 복원한다. 마지막 위치는 자동 스크롤이나 포커스로 덮어쓰지 않는다. 페이지에 키보드를 자동 표시하지 않아 복원 직후 글을 읽을 수 있다.

모바일 경로: getDatabasesPath()/writing-human-v1.db. 웹 캐시는 origin·계정별로 분리된다. localhost와 배포 URL은 서버와 캐시를 공유하지 않는다. 배포 웹의 기록은 로그인한 같은 계정의 D1 스냅샷과 동기화하며 상세 정책은 docs/sync.md를 따른다. 웹 동시 수정은 서버 버전 확인과 충돌 보관 필사로 처리한다. 백업 파일의 내보내기·복원은 후속 범위다.

매 변경 시 전체 라이브러리 스냅샷을 저장하는 구현이므로 장편·대량 기록 성능은 아직 검증하지 않았다. 다음 저장 최적화에서는 변경된 페이지의 갱신으로 전환하되 저장 순서, 실패 표시, 페이지/커서 복원 보장을 유지해야 한다. 종료 직전 OS의 강제 프로세스 종료까지 저장을 보장한다고 주장하지 않는다. 저장 완료 표시 후 종료하는 흐름을 검증한다.

호스트의 실제 SQLite 파일 테스트를 위해서만 sqflite_common_ffi를 개발 의존성으로 사용한다. 해당 sqlite3 패키지의 문서에 따른 hooks.user_defines.sqlite3.source: system을 지정했다. 테스트용 네이티브 바이너리 다운로드의 무결성 오류를 우회하거나 검증을 끄지 않고 OS SQLite를 사용한다. 모바일의 실제 저장소는 sqflite다.

## 첨부 이미지에 맞춘 UI 개편

책장은 큰 카드 대신 세로 목록으로, 책 상세는 표지·진행선·목차/필사 기록/책 정보로 구성했다. 편집 화면은 접힌 원문 메모, 종이 페이지, Aa·펜·페이지·키보드 도구 막대를 사용한다. 모바일은 전체 화면이고 넓은 웹 화면에서는 같은 앱을 중앙의 좁은 프레임 안에 표시한다.

WritingStyle은 종이, 펜, 글꼴, 줄 가이드, 즐겨찾기를 독립적으로 보관한다. Library JSON 버전 1의 optional style 필드로 추가했으며 이전 웹 데이터는 기본값으로 읽는다. SQLite 스키마는 버전 2다. app_state.settings와 records.source 컬럼을 ALTER TABLE로 추가하고 기존 테이블·본문·마지막 위치는 삭제하지 않는다. 기록에 source 원문 메모가 추가됐다.

도구 화면은 기존 편집기 위에 표시한다. 선택 변경으로 TextEditingController를 새로 만들거나 본문/selection/composing을 덮어쓰지 않는다. 펜 선택은 잉크빛에 반영되며 종이·글꼴을 바꾸지 않는다. 쓰기 소리는 준비 중이다.

## 입력 위치를 따르는 펜

lib/ui/writing_pen.dart는 TextEditingController·FocusNode·ScrollController를 읽기만 하는 장식 위젯이다. 한 프레임에 하나로 합친 post-frame callback에서 실제 RenderEditable의 getLocalRectForCaret를 읽고, global/local 좌표 변환으로 FittedBox·본문 패딩·스크롤·글자 크기를 반영한다. 텍스트 길이로 펜 위치를 추측하지 않는다.

일반 확정 입력은 최대 130ms 동안 위치를 따라가며 미세한 회전과 들림을 표현한다. 줄바꿈·큰 붙여넣기·스크롤·커서 탭은 긴 궤적을 그리지 않고 새 위치로 옮긴다. composing이 유효한 동안 위치만 즉시 표시하며 흔들림/보간은 멈춘다. 선택 영역이 펼쳐져 있거나 커서가 보이지 않거나 포커스를 잃으면 추적 펜을 숨긴다. OS disableAnimations 또는 TickerMode 비활성화 시에도 숨긴다. 지속 반복 애니메이션은 없다.

펜 레이어는 IgnorePointer·ExcludeSemantics·RepaintBoundary로 입력과 분리한다. 새 TextEditingController를 만들거나 TextEditingValue·selection·composing·focus·scroll을 되쓰지 않는다. WritingStyle.penMotion은 기본 true인 optional JSON 값으로 기존 SQLite settings 및 웹 저장/동기화에 보관하며 DB 스키마를 바꾸지 않는다. sync/merge.dart에서 다른 도구 값과 독립적으로 병합한다.

?demo=reference와 빈 책장의 ‘예시 책장 둘러보기’는 DemoStore를 사용하는 명시적인 예시 화면이다. 사용자 SQLite/localStorage를 쓰지 않는다. 예시 페이지 수와 문장은 레퍼런스 외관 확인용이며 실제 사용자 기록이나 책 원문 전체가 아니다. 예시 화면에 비영구 저장 안내를 표시하고 나의 책장으로 돌아갈 수 있다.

## 동기화 추가

lib/sync/의 조건부 팩토리는 웹의 계정 세션과 계정별 localStorage를 연결한다. SyncCoordinator가 로컬 저장 후 원격 버전 확인·병합·재시도를 수행한다. server/index.mjs는 Sites 사용자 식별과 D1의 조건부 갱신을 사용한다. 서버 서비스 자격 증명을 클라이언트에 포함하지 않는다. SQLite 스키마는 sync_state를 추가한 버전 3이다. docs/sync.md에 병합·계정 변경·마지막 위치·IME 규칙과 설치형 앱의 현재 한계를 기록했다.

GitHub Pages 등 정적 호스팅은 `WRITING_HUMAN_LOCAL_ONLY=true` 빌드에서 세션·동기화 클라이언트 생성 전에 WebLibraryStore만 반환한다. 기본 빌드는 기존 계정 동기화를 유지한다. Pages 산출물은 build/github-pages로 분리하며 Sites Worker·D1 배포와 섞지 않는다. docs/github-pages.md에 실행·배포 절차와 현재 접근 권한 한계를 기록한다.
