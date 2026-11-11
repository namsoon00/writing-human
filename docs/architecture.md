# 구현 구조

## 원문 가져오기와 보관 · 2026-11-11

`lib/source/`는 이미지 선택·문자 인식·수신함을 플랫폼별로 연결한다.
`SourceImportSheet`는 원문 편집을 별도 입력기에 두고, 사용자 확인 후 기존
`TranscriptionRecord.source`에 저장한다. 책·기록·쪽 구조나 저장 버전은 그대로다.
`SourceReading`은 기록의 원문을 빈 줄에서 나누고 본문 편집기 위에 읽기 전용으로
그린다. 문단 선택은 기록별 화면 상태이며 저장 큐를 사용하지 않는다. 문단을 넘길 때
읽기 영역의 높이와 편집기 키를 유지하고, 한글 조합 중에는 문단 화살표를 비활성화한다.
따라 쓰기에서는 현재 문단과 시작 시점의 본문을 화면 상태에 두고,
`TranscriptionGuidePainter`가 실제 편집기의 끝 위치와 스크롤을 읽어
남은 원문을 그린다. 조합 중인 글자 자리에는 밑글씨를 그리지 않는다.
편집기의 컨트롤러와 저장 경로는 본문만 다루며, 밑글씨는 입력과 접근성 조작을 가로채지 않는다.
조합 입력과 저장 대기, 편집 중인 쪽 또는 계정이 바뀌는 경우를 확인한다.
받은 글은 전용 수신함에 먼저 보관한다. 확인해서 새 기록을 저장한 뒤 해당 항목만
삭제한다. 저장 실패 시 재시도하고, 수신 ID를 새 기록 ID에 연결해 중복을 막는다.

Android는 [ML Kit 한글 모델](https://developers.google.com/ml-kit/vision/text-recognition/v2/android)을
앱에 포함한다. iOS 16 이상은 [Apple Vision](https://developer.apple.com/documentation/vision/recognizing-text-in-images)으로
책 사진을 읽는다. iOS 공유 확장과 앱은 [App Group](https://docs.flutter.dev/platform-integration/ios/app-extensions)을
통해 텍스트 수신함을 사용한다. 서명 배포 시 두 대상에
`group.com.writinghuman.writingHuman` 프로비저닝이 필요하다.

웹은 촬영본이나 이미지 파일을 브라우저의 [Tesseract.js](https://github.com/naptha/tesseract.js/blob/master/docs/api.md)
작업자에서 한글 중심으로 인식한다. `tool/prepare_ocr.mjs`가 검증한 모델·엔진은
빌드와 함께 같은 출처에 둔다. 인식할 때만 받아오며 사진은 전송하지 않는다.
로컬 웹 실행은 `node tool/prepare_ocr.mjs` 후
`flutter run -d chrome --dart-define=WRITING_HUMAN_LOCAL_ONLY=true`를 사용한다.
GitHub Pages·Sites의 빌드 스크립트에는 준비 단계가 포함된다.

## 색인 탭·구분표·압화의 표현과 저장 · 2026-11-11

`ui/reading_details.dart`가 종이·천·반달 탭, 구분표, 식물 세 가지를 정적인 벡터로 그린다.
보관함의 실제 탭은 `Book.id`로 책을 열고 최소 48px 조작 영역과 접근성 이름을 제공한다.
표지의 작은 탭과 압화·구분표는 장식이다. 구분표는 책 안쪽 기록 행 사이에만 그리며,
압화는 제목이나 이름과 분리된 아래쪽 영역을 쓴다. PageEditor와 입력 컨트롤러는 변경하지 않는다.

SQLite v5는 `books.index_label`을 기본 빈 문자열의 optional 책 메타데이터로 이전한다.
책 제목·저자·소유자와 별개인 `Book.indexLabel`을 웹 JSON v1과 동기화에도 보관한다.
빈 이름은 화면에서 실제 책 제목으로 표시한다. 설정과 탭 이름 저장에는 기존 큐·오류·재시도를
사용한다. 서버 검증은 새 스타일 및 이름을 허용하고 잘못된 타입·범위를 거부한다.
새 동기화 클라이언트를 비공개 사이트에 게시할 때는 검증 서버도 함께 갱신해야 한다.
GitHub Pages는 로컬 전용이며 비공개 Sites의 설정과 배포를 유지한다.

## 기존 일곱 요소의 재료 표현 · 2026-11-10

book_details.dart의 재질은 고정된 수식과 CustomPainter로 그린다. 무작위 값·반복 애니메이션·사용자 기록 변경은 없다. 작은 책갈피의 끝 깊이를 비례로 제한하고, 쪽지의 재질 그림은 실제 입력 위젯 뒤에 둔다. InkMark의 optional color는 장서표에만 사용하고 기본 브랜드 표식은 유지한다. 장서표 이름 편집은 기존 콜백·저장 경로를 쓰며 접근성 툴팁과 48px 터치 영역을 유지한다. 메타데이터 색의 명암비를 모든 종이·쪽지 바탕에서 검사한다. JSON/SQLite/서버 스키마는 바꾸지 않는다.


## 본문 입력 커서 표시 · 2026-11-10

PageEditor의 실제 TextField에 showCursor: false를 적용한다. readOnly나 입력
비활성화로 대체하지 않는다. RenderEditable의 논리적 입력 위치는 유지되므로
WritingPen은 getLocalRectForCaret를 읽어 같은 위치를 따라간다. 포커스·선택·
composing·스크롤·저장 리스너를 수정하지 않으며 OS의 조합/선택 표시도 유지한다.

## 일반 저장소로 통일한 앱 진입

main은 URL에 따라 DemoStore를 선택하지 않고 항상 실제 저장소의 Bootstrap을 연다.
entry_location.dart는 이전 reference/typeface 데모 매개변수만 제거하며 다른 쿼리·
fragment·origin을 유지한다. 웹의 history 정리가 제한되어도 실제 저장소 열기는 계속한다.
Workspace와 CollectionSheet의 데모 화면·비영구 안내·데모로 이동하는 메뉴를 제거했다.
DemoStore는 명시적으로 주입하는 개발 검증용 fixture로만 남으며 사용자 진입점과 연결하지 않는다.
기존 저장 내용·선택·스크롤·계정 보호·읽기/쓰기 실패 처리는 동일하다.

## 책의 물성과 독서 흔적

열 가지 독립 설정은 `data/book_detail_style.dart`의 BookDetailsStyle에 보관한다. 기존 ribbon/bookplate/sourceSlip/pencil/ornament/binding/dateStamp에 indexTab/recordDivider/pressedFlower가 추가됐다. BookDetailChoice의 enabled·variant·tone과 압화에 사용하는 optional placement를 기존 SQLite settings JSON과 웹 라이브러리에 저장한다. 이전 데이터에 새 키가 없으면 기본값을 읽는다. 동기화는 요소별 필드를 따로 병합한다.

`ui/book_detail_design.dart`는 요소별 이름·세 모양·네 색을 정의하고, `ui/book_detail_tools.dart`는 개별 미리보기·표시 스위치·모양/색 칩·해당 요소만 초기화를 제공한다. 설정 진입은 기존 쓰기 취향의 ‘책의 디테일’이다. 장식 숨김은 메타데이터를 지우지 않으며 평문 책 정보·원문·날짜를 유지한다. `paper_palette.dart`와 `ink_mark.dart`를 분리하여 종이 면과 장식이 서로를 가져오는 의존 순환을 제거했다. 자세한 조형·상태·경계는 [독립 설계](book-details-design.md)를 따른다.

`ui/book_details.dart`의 천 책갈피·직조 헤드밴드는 정적인 CustomPainter다. 종이쪽지·장서표·날짜인·판면 장식은 실제 Flutter 위젯으로 표시한다. 장식 그림은 IgnorePointer/ExcludeSemantics로 입력과 분리하고, 날짜·이름·조작부는 텍스트와 접근성 이름을 유지한다. 장서표는 보관함의 책 안쪽 스크롤 목록에 배치해 작은 화면에서도 넘쳐나지 않는다.

Book.owner는 저자와 별개인 장서표 이름이다. WritingPage.writtenOn은 생성 시 기기 현지 날짜의 YYYY-MM-DD이며, 과거 페이지는 null을 유지한다. WritingPage.pencilMarks는 UTF-16 start/end 목록이다. Library JSON 버전 1의 optional 필드로 추가했다. SQLite v4는 books.owner, pages.written_on, pages.pencil_marks를 ALTER TABLE로 추가하고, 데이터·선택·스크롤을 보존한다. 종이·펜·글꼴 설정과 분리된 기록 메타데이터다.

`ui/pencil_marks.dart`의 PencilTextController는 표시 span만 생성한다. composing 밑줄을 함께 표현하며, controller.value·selection·composing을 리스너에서 되쓰지 않는다. 구절 표시/부분 지우기는 LibraryController에서 저장하며 기존 편집기 키와 컨트롤러를 유지한다. 본문 수정은 공통 앞/뒤 문자열의 바깥에 남은 표시를 이동·분할하고, 바뀐 글자의 표시는 제거한다. emoji surrogate pair를 편집 경계에서 분리하지 않는다. 페이지 미리보기·넘김에도 같은 span 표현을 사용한다.

동기화에서는 장서표 이름을 책 제목/저자와 독립적으로 병합한다. 같은 본문 및 한쪽 본문 변경에서는 표시 범위를 대상 본문으로 이동한 뒤 3-way membership으로 병합하고, 본문 충돌 사본에도 날짜와 표시를 복사한다. 서버는 optional 이름·날짜·범위를 검증하며 이전 JSON도 허용한다. 현재 위치의 책갈피 표시는 기존 activePageId를 읽으며 별도의 책별 책갈피 데이터를 만들지 않는다.



Flutter 3.41.2 / Dart 3.11.0. iOS·Android는 sqflite, 웹 미리보기는 package:web의 localStorage. 하나의 Flutter 화면을 반응형으로 배치한다. 웹용 별도 HTML 모조 앱은 없다.

## 현재 작성 흐름

Workspace는 마지막 활성 페이지를 즉시 보여 주며, 기록이 없으면 저장하지 않은 WritingPage 초안을 표시한다. 탭/포커스/스크롤만으로는 저장하지 않는다. LibraryController.saveDraft가 첫 실제 입력 또는 원문 메모를 기존 초안과 같은 page/record ID로 저장한다. PageEditor의 키와 TextEditingController를 유지해 첫 한글 조합도 다시 설정하지 않는다. 오류 안내·원문 표시가 생겨도 writing-surface 키를 가진 Expanded를 유지한다.

새 종이는 첫 입력까지 메모리 초안이다. 앱을 닫으면 쓰지 않은 초안만 사라지고 마지막 저장 글은 유지한다. 기존 글을 이후 새 책으로 묶을 때는 addBook + bindRecord로 같은 기록을 묶으며 빈 기록을 추가 생성하지 않는다. 데이터 형식과 DB 스키마는 바꾸지 않았다.

collection_sheet.dart는 필요할 때 여는 글/책 보관함이다. tools_screen.dart는 종이·잉크·글꼴과 펜/줄 가이드를 한 시트에서 독립 선택한다. 원문·페이지·동기화도 보조 시트이며 기존 계정 보호·저장 실패/재시도·기존 기기 기록 가져오기를 유지한다. 작성 화면은 폭 760 이하의 한 면으로 적응하고, 마케팅 배경과 휴대폰 프레임은 사용하지 않는다. 아래 첨부 이미지 개편 기록은 이전 UI 구조다.

현재 종이 화면은 paper.dart의 PaperBackdrop이 최대 폭 760의 연속된 면지·왼쪽 음영을 담당한다. 면지 소재는 24% 강도의 정적인 RepaintBoundary이며 입력/접근성 트리에서 제외한다. PageEditor는 별도 종이 카드 없이 실제 TextField와 읽기 전용 펜 레이어를 올린다. WritingGuides는 실제 본문 패딩·행 높이·스크롤을 읽어 줄 가이드를 그린다. writing_chrome.dart의 WritingHeader/WritingFooter가 최소 조작부를 담당한다. 브랜드 이름은 책과 구분하고 작은 투명 잉크 표식을 사용한다. 포커스·키보드·크기 변경은 레이아웃만 조정하며 controller·selection·composing을 되쓰지 않는다.

- lib/data/model.dart: Book, WritingRecord(bookId nullable), WritingPage(recordId, number, text, selection, scroll), Library(activePageId, writing). 버전 1 JSON 및 참조 구조 검증.
- lib/data/library_controller.dart: 사용자 동작, 변경 스냅샷의 순차 저장, 저장 상태와 재시도. 저장 순서가 역전되지 않도록 Future 체인을 사용한다.
- lib/data/sqlite_store.dart: 네 개의 관계형 테이블, 외래 키, 현재 버전 5. 이전 버전 1·2·3·4의 파일을 자동 이전한다. 부모를 REPLACE로 삭제하지 않고 갱신한다. 각 스냅샷은 트랜잭션으로 저장한다.
- lib/data/web_store.dart: 버전 1 단일 키 writing-human.library.v1. 동기·원자적인 setItem을 호출하며 할당량/접근 오류는 UI까지 전달한다. 모바일의 SQLite와 저장 구현은 다르다.
- lib/main.dart: 저장소를 연 뒤 기존 기록을 읽는다. 실패하면 복구 화면을 표시하며 빈 라이브러리로 대체하지 않는다.
- lib/ui/workspace.dart: 책장, 책 생성, 편집. 본문 controller는 페이지마다 한 번 생성하고 입력 중 되쓰지 않는다. TextEditingValue를 관찰해서 조합 중 텍스트도 보관하되 IME composing 영역은 재실행 시 복원하지 않는다. 선택 영역은 UTF-16 offset이며 복원 시 범위를 제한한다.
- lib/ui/paper.dart: 공통 종이/잉크 팔레트, 면지 이미지와 얕은 왼쪽 음영, 잉크 표식, 줄 가이드와 보관함의 린넨 표지. 소재는 RepaintBoundary로 편집과 분리하며 포인터·접근성 트리에서 제외한다. 애니메이션은 없다. lib/ui/writing_chrome.dart는 상단/하단의 실제 조작부를 담당한다. 소재 경로와 프롬프트는 docs/visual-assets.md를 따른다.

## 글씨 가독성

`ui/typography.dart`의 ReadingTextScaler는 기존 글자 크기를 1.2배로, 일반 최소 문구를
14px로 올린 후 OS TextScaler에 전달한다. 시스템의 비선형 확대를 선형 값으로 치환하지
않는다. 0 크기는 유지하며 설정 저장이나 편집 값 변경은 없다. 본문·줄 가이드·펜 위치는
같은 MediaQuery 척도로 실제 레이아웃을 읽는다. 작은 표지 썸네일은 중복 장식 텍스트를
비례 크기로 유지한다. 날짜 안내 행은 Wrap으로 바꿔 접근성 확대에서도 넘치지 않는다.

서체는 `source/reading-v007.json`의 6 디자인 단위 바깥 윤곽 확대로 실제 TTF를 재생성했다.
공통 자모 공유·advance·cmap·NFC/NFD 조판을 유지한다. 단순 가짜 굵기나 이미지 텍스트가 아니다.

## 개발 중 서체 연결

WritingHumanDevelopment family를 pubspec.yaml에 등록했다. 0.007은 현대 한글 11,172자·자모·ASCII·문장부호를 담은 실제 TTF이며 반복 자모를 TrueType composite으로 공유한다. OpenType ccmp는 현대 초성+중성 및 받침을 완성형과 같은 윤곽으로 조합한다. 본문은 기존
TextField와 TextEditingController를 유지하고 TextStyle의 family/fallback만
바꾼다. 개발 TTF의 미지원 글자는 NanumMyeongjo → NanumGothic → 플랫폼
대체 글꼴로 표시한다. 문자열·선택 영역·composing을 나누거나 다시 설정하지 않는다.

WritingStyle.useDevelopmentTypeface는 기본 true다. 전체 TextTheme와 명시적 UI 제목도
WritingHumanDevelopment + NanumMyeongjo/NanumGothic 대체 체인을 사용한다.
기존 설정은 typefaceDefaultsVersion이 없으면 쓰는 인간체로 한 번 전환한다.
새 저장에는 typefaceDefaultsVersion: 1을 기록해 이후 명시적으로 선택한 다른 본문
글꼴도 저장·복원한다. 본문·선택·스크롤·종이·잉크와 fontIndex 0–2, DB 버전은 유지한다.
동기화 병합에서는 fontIndex와 개발 서체 여부를 한 선택으로 처리하며 종이·펜과
독립적으로 합친다. 서버는 optional bool의 타입을 검증한다. 기존 서버도 style의
추가 필드를 보존하므로 인증이나 요청 구조 변경은 없다.

일반 주소·빈 종이·기존 페이지·보관함·도구·대화상자에 쓰는 인간체를 기본 적용한다.
이전 데모 주소도 같은 실제 기록·기본 글꼴로 열린다.

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

DemoStore와 합성 문장은 개발 검증용으로만 남는다. 일반 앱에 예시 진입점이나 합성 기록 자동 생성은 없다.

## 동기화 추가

lib/sync/의 조건부 팩토리는 웹의 계정 세션과 계정별 localStorage를 연결한다. SyncCoordinator가 로컬 저장 후 원격 버전 확인·병합·재시도를 수행한다. server/index.mjs는 Sites 사용자 식별과 D1의 조건부 갱신을 사용한다. 서버 서비스 자격 증명을 클라이언트에 포함하지 않는다. SQLite 스키마는 sync_state를 추가한 버전 3이다. docs/sync.md에 병합·계정 변경·마지막 위치·IME 규칙과 설치형 앱의 현재 한계를 기록했다.

GitHub Pages 등 정적 호스팅은 `WRITING_HUMAN_LOCAL_ONLY=true` 빌드에서 세션·동기화 클라이언트 생성 전에 WebLibraryStore만 반환한다. 기본 빌드는 기존 계정 동기화를 유지한다. Pages 산출물은 build/github-pages로 분리하며 Sites Worker·D1 배포와 섞지 않는다. docs/github-pages.md에 실행·배포 절차와 현재 접근 권한 한계를 기록한다.

## 페이지 전환 · 2026-11-10

PageTurnView는 Scaffold 본문 전체를 감싸 상단 브랜드·본문·하단 도구를
한 장으로 넘긴다. 실제 PageEditor는 하나다. 떠나는 화면의 마지막 paint layer만
메모리 이미지로 읽어 360ms 곡선 클립·종이 뒷면·그림자를 덧댄다. 장식은
IgnorePointer/ExcludeSemantics이며 이전 편집기의 포커스·저장 리스너를 복제하지 않는다.
같은 page ID의 첫 저장·도구 변경에는 전환하지 않는다. 새 쪽 입력은 연출을
즉시 끝낸다. OS disableAnimations, 비활성 TickerMode, 20,000자 초과 본문은
연출을 생략해 입력과 기록을 우선한다. 스냅샷은 최대 배율 2·약 200만 픽셀로
제한하며 PNG 인코딩·디스크 저장·업로드를 하지 않는다. 전환 완료·입력·빠른 역방향
전환·키보드/화면 크기 변경·dispose 때 이미지를 해제한다. 화면 캡처가 불가능하면
이동은 즉시 완료한다. 컨트롤러가 바뀌면 이전 계정의 장식을 재사용하지 않는다.

Workspace는 조합 입력·계정 잠금·중복 이동을 검사하고 현재 저장 큐가 끝난 뒤
이동한다. 실패하면 현재 쪽에 머문다. 시트의 쪽 선택은 route.completed 이후에
실행하고 그동안 계정/컨트롤러/현재 쪽이 바뀌면 취소한다. PagesSheet는 본문
일부만 담은 읽기 전용 미리보기다. 입력 리스너가 본문·selection·composing을
다시 설정하지 않는다. 명시적인 빈 페이지 추가에만 saveDraft(keepBlank: true)를
사용하며 기존 JSON/SQLite 구조와 도구 설정을 유지한다.

## 쪽수와 종이 스와이프 · 2026-11-10

WritingFooter는 64px 기본 높이 한 줄로 도구·쪽수·더 보기/완료를 배치하고
쪽수 아래 작은 저장 상태를 유지한다. 이전/다음/추가 버튼은 없다. 현재 번호를
누르면 PagesSheet가 열리고, 접근성 레이블은 현재/전체 쪽수와 증감 동작을 제공한다.

PaperSwipe는 수평 드래그로 한 번에 한 쪽만 넘긴다. 마지막 쪽의 다음 동작은
기존 _appendPage와 실제 저장 큐를 사용한다. 64px 이동 또는 36px 이상/500px/s
flick에만 반응하고 강한 역방향 마무리는 취소한다. 본문과 스크롤을 재배치하지 않는다.

읽기 상태의 종이는 수평 recognizer를 본문의 pan recognizer보다 먼저 등록해
가로 넘김을 구분한다. 세로 스크롤·탭·길게 누르기는 기존 편집기 recognizer가
처리한다. 포인터를 재생하거나 controller.value/selection/composing을 쓰지 않는다.
입력 포커스가 있으면 종이 본문의 넘김은 비활성화하고, 쪽수 영역에서만 넘긴다.
본문의 마우스 드래그는 기본 선택에 맡기며 쪽수는 마우스/트랙패드도 받는다.
조합 입력·저장 오류·계정 잠금·중복 이동 보호와 전체 화면 PageTurnView를 유지한다.

## 드래그에 따라 드러나는 옆 장과 앞표지

PageTurnView는 포인터의 수평 이동을 종이 너비(최대 760px)로 나누고, 진행률을
0~1로 제한한다. 이동한 폭에만 옆 장을 그리고 남은 폭에는 현재 편집기를 유지한다.
PageReadPreview는 옆 장의 저장된 본문·선택한 글꼴·펜 색·밑줄·스크롤을 읽어
그리는 읽기 전용 위젯이다. 드래그 중에는 새 입력기나 저장 요청이 생기지 않는다.
손을 떼면 너비의 32% 또는 36px 이상/500px/s의 같은 방향 동작에서 한 장을 확정하고,
부족하거나 강하게 되돌린 동작은 원위치로 돌아간다. 동작 줄이기에서는 정리 애니메이션을
생략한다. 활성 한글 조합·저장 오류·회전 등의 기존 보호를 유지한다. 웹의 접근성
textarea에서 브라우저가 포인터를 가로채지 않도록 touch-action을 지정하고,
가로 넘김과 세로 스크롤은 Flutter에서 구분한다.

책은 보관함의 기록 순서와 각 기록의 쪽 순서로 연결한다. 화면의 연속 쪽수는
기록별 저장 번호를 바꾸지 않는다. 표지는 첫 페이지 앞의 화면 상태라서 책의
쪽수에 포함되거나 SQLite/웹 저장소에 기록되지 않는다. 다시 열 때는 기존
방식대로 마지막 실제 페이지를 복원한다. 끝 장을 넘겨 새 장을 추가하는 동작만
기존 저장 큐를 거친다.

## 종이 모서리, 단면, 넘김 소리 · 2026-11-11

읽기 화면 아래쪽 바깥에서 시작한 가로 드래그는 현재 종이와 읽기 전용 미리보기를
서로 보완하는 곡선으로 자른다. 종이 뒷면은 별도 페인터로 그린다. 중앙 및 쪽수
드래그는 기존 수평 진행률을 사용한다. 넘김 효과를 끄거나 OS 동작 줄이기가
활성화되면 화면 연출을 생략하고 같은 제스처 판정과 저장 큐를 사용한다.

책의 페이지 단면은 실제 앞뒤 쪽 수로 계산하는 장식이다. SQLite v6는
`books.cover_index`와 `books.paper_index`를 nullable 컬럼으로 추가한다. 기존 책은
종전 표지와 기본 내지를 사용한다. JSON의 같은 선택 값과 전역 넘김 설정은
기존 데이터에서 생략 가능하며 각각 독립적으로 동기화 병합한다. 펜·글꼴과
책 → 필사 → 페이지 구조를 유지한다.

넘김 소리는 명시적으로 켠 경우에 한해 새 위치의 저장 큐가 끝난 뒤 재생한다.
샘플은 OwlStorm의 CC0 녹음 [Page Turn (1)](https://freesound.org/people/OwlStorm/sounds/151220/)을
`assets/audio/page-turn.mp3`로 번들에 포함한다.
