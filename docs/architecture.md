# 구현 구조

## 글씨 쓰는 소리

`PageEditor`는 이전과 현재 입력값을 읽어 확정된 한 글자를 찾는다. 한글 조합
범위가 다음 글자로 이동할 때에도 확정된 앞 글자만 처리한다. 저장 경로와 별도로
`WritingSound`가 짧은 합성 펜촉 음원 `assets/audio/pen-stroke.wav`를 재생한다.
플레이어 한 개로 소리를 내며 빠른 입력에서는 최소 간격을 둔다. 오디오 오류와
지연은 입력과 저장에 영향을 주지 않는다. `writingSound`는 기본 false인 설정으로
기존 SQLite·웹 설정과 동기화 병합에서 독립적으로 저장한다.

## 책별 꾸밈과 미리보기

`BookAppearance`는 표지·내지·꾸밈 변경값을 화면에 보관하고, 완료할 때
`LibraryController.saveBookAppearance`가 현재 책 메타데이터에 합쳐 한 번의 저장으로
보낸다. 쓰기 화면과 책장·목차·원문은 같은 책의 설정을 읽는다.
`Book.detailOverrides`에 없는 항목은 기존 `WritingStyle.bookDetails`에서 상속한다.
SQLite v10은 `books.detail_overrides`에 빈 JSON 객체를 기본값으로 추가한다. 웹·백업·
동기화에는 선택 필드 `detailOverrides`를 사용한다. 동기화는 책별 꾸밈의 표시·모양·색·위치를
각각 병합하며, 처음 바꾼 요소는 공통 기준의 기본 설정과 비교한다.

## 책장과 이어 쓰기

`CollectionSheet`는 책장을 먼저 열고 책 상세와 ‘내 글’로 연결한다. `Bookshelf`는
기존 린넨 표지, 종이 결, 책별 표지 설정을 사용하고 화면 폭에 맞춰 선반을 그린다.
제목 검색은 현재 책 목록을 필터링한다. 찾기와 상세 열기는 기록을 저장하지 않는다.
‘내 글’의 `WritingSheetPreview`는 첫 본문과 날짜를 읽어 노트의 내지와 현재 잉크·서체로
표시한다. 검색 결과는 본문에서 일치하는 위치를 사용한다.
보관함 안에서 책장과 기본 글 목록의 스크롤은 `PageStorage`에 각각 보관한다.

표지에서 본문을 열 때는 기존 페이지 이동과 저장 큐를 사용한다. 앱을 열었을 때
저장된 활성 쪽이 그 책에 속하면 그 위치를 복원한다. 사용 중에는 책마다 마지막으로
연 쪽을 기억한다. 현재 실행에서 위치를 모르는 책은 가장 최근에 추가된 기록의
마지막 쪽을 연다. 내용이 없는 책은 글을 쓰는 시점에 저장하는 기존 작성 흐름을 사용한다.

## 백업, 내보내기, 검색

`LibraryBackup`은 형식 식별자, 버전, 생성 시각과 라이브러리를 JSON에 담는다.
동기화 계정·기준 스냅샷과 기기별 마지막 내보내기 시각은 파일에 넣지 않는다.
가져올 때 구조와 참조를 확인한 뒤 현재 라이브러리에 추가한다. 내용이 일치하는
기존 항목을 재사용하고, 다른 내용이 같은 ID를 쓰면 책·기록·쪽의 참조를 새 ID로
연결한다. 같은 사본을 다시 가져오면 재사용한다. 새 스냅샷은 기존 순차 저장 큐로
저장하고 실패 시 다시 저장할 수 있다. SQLite는 한 트랜잭션으로 처리한다.
마지막 백업 내보내기 시각은 기기에만 저장한다. 웹에서는 브라우저에 다운로드를
요청한 시각이다. 파일 선택과 저장은 `file_picker`를 사용한다.

`writing_export.dart`는 필사 본문을 쪽 순서의 UTF-8 텍스트로, 책을 번들 한글
서체를 사용하는 A4 PDF로 만든다. `LibraryPassages`는 페이지 전체에서 문자열을
찾고 편집기와 같은 UTF-16 위치를 돌려준다. 결과 이동은 편집기의 스크롤만 조정한다.


## 쓰기 위치와 새 잉크의 표현

`WritingPen`은 실제 삽입 위치의 커서 영역 하단에서 2px 아래에 10×12px 펜촉을
그린다. 펜촉 끝은 삽입 위치의 가로 좌표를 가리키며 현재 펜 색을 불투명도 55%로 사용한다.
`penMotion` 값과 OS 동작 줄이기는 새로 확정된 글자의 일시적인 농도 효과를 제어한다.
효과는 실제 RenderEditable의 글꼴·배율·문자열로 한 번 배치한 TextPainter를
마지막 한 글자의 영역에만 겹쳐 그린다. 약 140ms 동안 추가 농도가 가라앉는다.
선택·스크롤·조합 입력·포커스 이동 때 남은 효과를 정리한다. 20,000자 초과
본문에서는 추가 글자 농도 효과를 생략한다. 입력값과 저장 경로를 읽기만 한다.

## 원문 가져오기와 보관 · 2026-11-11

`RegisteredOriginal`은 ID, 본문, 선택 출처로 구성된다. `Book.originals`에
책의 원문을 저장하고, 책 없이 등록한 원문은 `WritingRecord.originals`에 둔다.
SQLite v9에서 두 테이블에 기본값이 빈 목록인 `originals` 컬럼을 추가한다.
라이브러리 JSON은 선택 필드를 사용하며 백업에서 복원한다. 동기화는 원문 ID를
기준으로 추가 항목을 합친다. 책에 묶은 기록의 원문은 책 범위에서 조회한다.

원문 메모는 `RegisteredOriginal.reflection`에 본문과 선택 밑줄(UTF-16 범위)을
저장한다. 기존 SQLite v9의 원문 JSON 컬럼에 선택 필드를 추가하며, 웹 저장·백업도
같은 JSON을 쓴다. 기존 기록이나 쪽에서 가져온 원문에 메모를 쓸 때는 원래
메타데이터를 보존하고 같은 범위의 원문 목록에 결정적인 ID로 저장한다. 같은 메모를
동시에 다르게 수정하면 동기화에서 두 내용을 문단으로 보존한다.

원문 패널 안의 편집기는 저장 버튼을 사용하며 조합 중에는 저장을 쉬고 실패하면
입력을 유지한다. 메모 서체는 Google Fonts의 Nanum Pen Script를 SIL OFL 문서와 함께
번들에 둔다. [원본 서체와 라이선스](https://github.com/google/fonts/tree/main/ofl/nanumpenscript)

원문 읽기 패널은 `PaperBackdrop`, `SourceSlip`, `RecordDivider`와 필사
밑줄 스타일을 재사용한다. 책의 내지와 글꼴·펜·책의 디테일 설정을 전달한다.
쓰기 화면은 원문 일치 위치와 저장한 밑줄을 실제 본문의 UTF-16 위치로 연결한다.
`NotebookReflection`이 배치된 RenderEditable의 줄과 스크롤을 읽어 같은 종이에
화살표와 손글씨를 그린다. 노트에서 메모를 누르거나 선택 메뉴에서 느낀 점을
고르면 같은 페이지에 별도의 TextField를 열고 본문 컨트롤러와 선택은 보존한다.
다음 줄에 글이 있으면 연필 표시를 두고, 편집할 때만 종이 위에 겹쳐 띄운다.
조합이 끝난 메모는 기존 원문의 순차 저장 경로로 보내며, 메모를 모두 지우면
reflection만 제거한다. 저장에 실패하면 입력을 유지하고 같은 자리에서 재시도할 수 있다.

기존 `WritingRecord.source`, `sourceParagraph`, `WritingPage.passages`를 보존한다.
조회할 때 기존 기록 원문과 쪽의 원문·출처를 새 목록과 함께 표시하고, 같은 본문과
출처의 사본은 하나로 보여 준다. 이전 쪽의 UTF-16 구절 위치는 기존 편집 규칙을 따른다.

`originals.dart`는 쓰는 줄의 확정 문자열을 현재 범위에서 찾아 유일한 위치를 반환한다.
첫 단어 하나만 쓴 경우에는 원문 단어 양쪽 경계까지 일치해야 한다. 여러 단어를 쓰면
원문의 단어 시작에서 검색하고 마지막 단어는 입력 중인 접두어도 비교한다.
`TranscriptionGuidePainter`는 편집기 끝의 실제 커서 위치에 한 줄의 밑글씨를 그린다.
조합 중인 부분은 일치 판정에서 빼고, 편집기의 입력값·선택·조합을 변경하지 않는다.
하단 원문 패널은 일치한 위치를 강조해 스크롤하며 닫힐 때 편집기의 포커스를 복원한다.

`lib/source/`의 사진·수신함을 원문 등록 화면에서 사용한다. 받은 글은 전용 수신함에
보관하고, 선택한 책의 원문이나 책 없는 새 기록이 저장된 뒤 해당 항목만 삭제한다.
수신 ID를 등록한 원문 또는 기록 ID에 연결해 재시도 때 중복을 막는다.

사진은 인식기와 미리보기가 같은 픽셀을 사용하도록 크기와 방향을 통일한다.
실시간 읽기는 모바일 카메라 스트림이나 브라우저 후면 카메라에서 프레임을 하나씩
읽는다. 웹은 세션 동안 같은 인식 작업자를 쓰고 화면을 닫거나 숨기면 카메라와
작업자를 해제한다. 페이지는 감지한 네 모서리로 인식용 영상의 원근을 보정하고,
저장할 때 줄 위치를 전체 카메라 이미지의 좌표로 되돌린다. 사진 보관함에는 확정한
순간의 전체 프레임을 저장한다.
각 인식기는 문단·줄·단어와 왼쪽 위 기준의 정규화 좌표, 제공 가능한 인식 신뢰도를
반환한다. 페이지 모드는 명확히 분리된 두 단의 읽는 순서를 제안하며 순서를 직접
조정할 수 있다. 문단 모드는 선택한 단어들의 문자 범위를 사용해 구두점과 줄바꿈을
보존한다. 다시 인식할 때는 선택한 줄별 영역 밖을 흰색으로 가리고 잘라 보낸다.
페이지 검수에서 확정한 문단들을 빈 줄로 구분해 하나의 원문으로 저장한다.
필사 범위는 전체 원문의 UTF-16 시작과 끝으로 저장하며 밑글씨도 이 범위를 따른다.
페이지 원문은 확정된 글과 대응하는 줄의 UTF-16 범위와 정규화된 사진 좌표를 저장한다.
원문을 다시 열면 원본 사진에서 같은 좌표를 사용한다. 줄 좌표가 없는 이전 원문은
사진과 줄 번호를 함께 보며 범위를 정할 수 있다. 사진은 OCR용 이미지와 별도로 원래 바이트를 SHA-256으로
참조한다. 설치형 앱은 앱 지원 디렉터리, 웹은 IndexedDB에 보관한다.
동기화 스냅샷에는 사진 ID와 범위를 담고, 32MB 이내 JSON 백업은 현재 기기에 있는
사진도 포함한다. 복원 시 사진 해시를 확인하고 먼저 저장한 뒤 라이브러리를 합친다.

Android는 [ML Kit 한글 모델](https://developers.google.com/ml-kit/vision/text-recognition/v2/android)을
앱에 포함한다. iOS 16 이상은 [Apple Vision](https://developer.apple.com/documentation/vision/recognizing-text-in-images)으로
책 사진을 읽는다. iOS 공유 확장과 앱은 [App Group](https://docs.flutter.dev/platform-integration/ios/app-extensions)을
통해 텍스트 수신함을 사용한다. 서명 배포 시 두 대상에
`group.com.writinghuman.writingHuman` 프로비저닝이 필요하다.

웹은 촬영본이나 이미지 파일을 브라우저의 [Tesseract.js](https://github.com/naptha/tesseract.js/blob/master/docs/api.md)
작업자에서 한글 중심으로 인식한다. `tool/prepare_ocr.mjs`가 검증한 모델·엔진은
빌드와 함께 같은 출처에 둔다. 인식할 때만 받아오며 사진은 전송하지 않는다.
웹 인식에서 여러 줄이 같은 중앙 여백으로 나뉘면 좌우 단을 별도로 읽는다.
단 범위 밖의 제목과 쪽수는 전체 인식 결과에서 유지한다.
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

린넨 표지의 WebP는 천, 책등, 테두리를 담는다. 작은 표지와 큰 앞표지는 제목과
압화에 각각 다른 영역을 배정한다. 압화는 같은 선택값으로 그리고 어두운 천에서는
색의 밝기를 높인다. 현재 책의 책갈피, 날짜인의 간격, 제본 폭, 원문 목록의 구분표와
쪽수 문양은 각 화면의 크기에 맞춘다.

열 가지 독립 설정은 `data/book_detail_style.dart`의 BookDetailsStyle에 보관한다. 기존 ribbon/bookplate/sourceSlip/pencil/ornament/binding/dateStamp에 indexTab/recordDivider/pressedFlower가 추가됐다. BookDetailChoice의 enabled·variant·tone과 압화에 사용하는 optional placement를 기존 SQLite settings JSON과 웹 라이브러리에 저장한다. 이전 데이터에 새 키가 없으면 기본값을 읽는다. 동기화는 요소별 필드를 따로 병합한다.

`ui/book_detail_design.dart`는 요소별 이름·세 모양·네 색을 정의하고, `ui/book_detail_tools.dart`는 개별 미리보기·표시 스위치·모양/색 칩·해당 요소만 초기화를 제공한다. 설정 진입은 기존 쓰기 취향의 ‘책의 디테일’이다. 장식 숨김은 메타데이터를 지우지 않으며 평문 책 정보·원문·날짜를 유지한다. `paper_palette.dart`와 `ink_mark.dart`를 분리하여 종이 면과 장식이 서로를 가져오는 의존 순환을 제거했다. 자세한 조형·상태·경계는 [독립 설계](book-details-design.md)를 따른다.

`ui/book_details.dart`의 천 책갈피·직조 헤드밴드는 정적인 CustomPainter다. 종이쪽지·장서표·날짜인·판면 장식은 실제 Flutter 위젯으로 표시한다. 장식 그림은 IgnorePointer/ExcludeSemantics로 입력과 분리하고, 날짜·이름·조작부는 텍스트와 접근성 이름을 유지한다. 장서표는 보관함의 책 안쪽 스크롤 목록에 배치해 작은 화면에서도 넘쳐나지 않는다.

Book.owner는 저자와 별개인 장서표 이름이다. WritingPage.writtenOn은 생성 시 기기 현지 날짜의 YYYY-MM-DD이며, 과거 페이지는 null을 유지한다. WritingPage.pencilMarks는 UTF-16 start/end 목록이다. Library JSON 버전 1의 optional 필드로 추가했다. SQLite v4는 books.owner, pages.written_on, pages.pencil_marks를 ALTER TABLE로 추가하고, 데이터·선택·스크롤을 보존한다. 종이·펜·글꼴 설정과 분리된 기록 메타데이터다.

`ui/pencil_marks.dart`의 PencilTextController는 표시 span만 생성한다. composing 밑줄을 함께 표현하며, controller.value·selection·composing을 리스너에서 되쓰지 않는다. 구절 표시/부분 지우기는 LibraryController에서 저장하며 기존 편집기 키와 컨트롤러를 유지한다. 본문 수정은 공통 앞/뒤 문자열의 바깥에 남은 표시를 이동·분할하고, 바뀐 글자의 표시는 제거한다. emoji surrogate pair를 편집 경계에서 분리하지 않는다. 페이지 미리보기·넘김에도 같은 span 표현을 사용한다.

동기화에서는 장서표 이름을 책 제목/저자와 독립적으로 병합한다. 같은 본문 및 한쪽 본문 변경에서는 표시 범위를 대상 본문으로 이동한 뒤 3-way membership으로 병합하고, 본문 충돌 사본에도 날짜와 표시를 복사한다. 서버는 optional 이름·날짜·범위를 검증하며 이전 JSON도 허용한다. 책마다 마지막으로 펼친 쪽은 라이브러리의 선택 필드 `bookPositions`에 저장한다.
SQLite는 기존 `app_state.settings`에 담고 웹·백업은 라이브러리 JSON에 담는다.
이전 기록은 기존 활성 쪽부터 기억한다. 동기화는 책별로 위치를 병합하고,
백업을 합칠 때는 기존 위치를 유지하며 새로 들여온 책과 쪽의 ID를 연결한다.



Flutter 3.41.2 / Dart 3.11.0. iOS·Android는 sqflite, 웹 미리보기는 package:web의 localStorage. 하나의 Flutter 화면을 반응형으로 배치한다. 웹용 별도 HTML 모조 앱은 없다.

## 현재 작성 흐름

Workspace는 마지막 활성 페이지를 즉시 보여 주며, 기록이 없으면 저장하지 않은 WritingPage 초안을 표시한다. 탭/포커스/스크롤만으로는 저장하지 않는다. LibraryController.saveDraft가 첫 실제 입력 또는 원문 메모를 기존 초안과 같은 page/record ID로 저장한다. PageEditor의 키와 TextEditingController를 유지해 첫 한글 조합도 다시 설정하지 않는다. 오류 안내·원문 표시가 생겨도 writing-surface 키를 가진 Expanded를 유지한다.

책 안의 상단 ＋는 쪽 추가의 저장 경로를 사용한다. 빈 책의 초안은 첫 쪽으로만 저장한다.
책 밖에서 상단 ＋로 연 새 종이는 첫 입력까지 메모리 초안이다. 앱을 닫으면 쓰지 않은 초안만 사라지고 마지막 저장 글은 유지한다. 기존 글을 이후 새 책으로 묶을 때는 addBook + bindRecord로 같은 기록을 묶으며 빈 기록을 추가 생성하지 않는다. 데이터 형식과 DB 스키마는 바꾸지 않았다.

collection_sheet.dart는 필요할 때 여는 글/책 보관함이다. tools_screen.dart는 종이·잉크·글꼴과 펜/줄 가이드를 한 시트에서 독립 선택한다. 원문·페이지·동기화도 보조 시트이며 기존 계정 보호·저장 실패/재시도·기존 기기 기록 가져오기를 유지한다. 작성 화면은 폭 760 이하의 한 면으로 적응하고, 마케팅 배경과 휴대폰 프레임은 사용하지 않는다. 아래 첨부 이미지 개편 기록은 이전 UI 구조다.

현재 종이 화면은 paper.dart의 PaperBackdrop이 최대 폭 760의 연속된 면지·왼쪽 음영을 담당한다. 면지 소재는 24% 강도의 정적인 RepaintBoundary이며 입력/접근성 트리에서 제외한다. PageEditor는 별도 종이 카드 없이 실제 TextField와 읽기 전용 펜 레이어를 올린다. WritingGuides는 실제 본문 패딩·행 높이·스크롤을 읽어 줄 가이드를 그린다. writing_chrome.dart의 WritingHeader/WritingFooter가 최소 조작부를 담당한다. 작성 화면 상단에는 현재 책 제목이나 앱 이름을 양옆 버튼과 같은 높이로 표시한다. 포커스·키보드·크기 변경은 레이아웃만 조정하며 controller·selection·composing을 되쓰지 않는다.
안전 영역을 뺀 키보드 인셋만큼 편집기 하단을 줄이고 하단 조작부를 위로 옮긴다.
종이 여백과 본문의 마지막 글줄 아래를 터치하면 조합이 끝난 상태에서 입력 포커스를
해제한다. 마지막 글줄의 위치는 RenderEditable에서 읽고, 본문이나 선택 범위를 변경하지 않는다.
iOS 본문에서 탭과 길게 누르기는 RenderEditable의 좌표를 기준으로 삽입 위치와
단어 범위를 선택한다. iOS 웹의 투명한 본문 textarea는 포인터 대상에서 제외하고
포커스와 키보드 입력에 사용한다. 짧은 탭의 touchend에서 본문 textarea에 직접
포커스를 주고, 후속 마우스 클릭을 막아 입력 포커스를 유지한다. 조합 중에는 추가 터치 선택을 적용하지 않는다.
선택 쪽지는 EditableText의 툴바 앵커에 배치한다. 복사·잘라내기·붙여넣기는 Flutter의
선택 동작을 사용하며, 느낀 점은 선택한 UTF-16 범위에서 읽은 구절이 원문에서 한 번
일치할 때 기존 메모 편집을 연다.

- lib/data/model.dart: Book, WritingRecord(bookId nullable), WritingPage(recordId, number, text, selection, scroll), Library(activePageId, writing). 버전 1 JSON 및 참조 구조 검증.
- lib/data/library_controller.dart: 사용자 동작, 변경 스냅샷의 순차 저장, 저장 상태와 재시도. 저장 순서가 역전되지 않도록 Future 체인을 사용한다.
- lib/data/sqlite_store.dart: 네 개의 관계형 테이블, 외래 키, 현재 버전 7. 이전 버전 1~6의 파일을 자동 이전한다. 부모를 REPLACE로 삭제하지 않고 갱신한다. 각 스냅샷은 트랜잭션으로 저장한다.
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

모바일 경로: getDatabasesPath()/writing-human-v1.db. 웹 캐시는 origin·계정별로 분리된다. localhost와 배포 URL은 서버와 캐시를 공유하지 않는다. 배포 웹의 기록은 로그인한 같은 계정의 D1 스냅샷과 동기화하며 상세 정책은 docs/sync.md를 따른다. 웹 동시 수정은 서버 버전 확인과 충돌 보관 필사로 처리한다. 파일 백업은 기록 보관 메뉴에서 제공한다.

매 변경 시 전체 라이브러리 스냅샷을 저장하는 구현이므로 장편·대량 기록 성능은 아직 검증하지 않았다. 다음 저장 최적화에서는 변경된 페이지의 갱신으로 전환하되 저장 순서, 실패 표시, 페이지/커서 복원 보장을 유지해야 한다. 종료 직전 OS의 강제 프로세스 종료까지 저장을 보장한다고 주장하지 않는다. 저장 완료 표시 후 종료하는 흐름을 검증한다.

호스트의 실제 SQLite 파일 테스트를 위해서만 sqflite_common_ffi를 개발 의존성으로 사용한다. 해당 sqlite3 패키지의 문서에 따른 hooks.user_defines.sqlite3.source: system을 지정했다. 테스트용 네이티브 바이너리 다운로드의 무결성 오류를 우회하거나 검증을 끄지 않고 OS SQLite를 사용한다. 모바일의 실제 저장소는 sqflite다.

## 첨부 이미지에 맞춘 UI 개편

책장은 큰 카드 대신 세로 목록으로, 책 상세는 표지·진행선·목차/필사 기록/책 정보로 구성했다. 편집 화면은 접힌 원문 메모, 종이 페이지, Aa·펜·페이지·키보드 도구 막대를 사용한다. 모바일은 전체 화면이고 넓은 웹 화면에서는 같은 앱을 중앙의 좁은 프레임 안에 표시한다.

WritingStyle은 종이, 펜, 글꼴, 줄 가이드, 즐겨찾기를 독립적으로 보관한다. Library JSON 버전 1의 optional style 필드로 추가했으며 이전 웹 데이터는 기본값으로 읽는다. SQLite 스키마는 버전 2다. app_state.settings와 records.source 컬럼을 ALTER TABLE로 추가하고 기존 테이블·본문·마지막 위치는 삭제하지 않는다. 기록에 source 원문 메모가 추가됐다.

도구 화면은 기존 편집기 위에 표시한다. 선택 변경으로 TextEditingController를 새로 만들거나 본문/selection/composing을 덮어쓰지 않는다. 펜 선택은 잉크빛에 반영되며 종이·글꼴을 바꾸지 않는다.

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

## 표지의 회전과 뒷표지 위치 · 2026-11-13

Workspace는 표지의 기준 실제 페이지 ID와 앞·뒤 위치를 화면 상태로 관리한다.
마지막 저장 쪽에서 앞으로 넘기면 겉뒷표지가 종이를 덮는다. 새 쪽 추가는 기존
저장 큐를 거치고, PagesSheet에서 앞표지와 뒷표지로 각각 이동할 수 있다.

CoverHinge는 앞표지의 왼쪽 책등과 겉뒷표지의 오른쪽 책등을 회전축으로 사용한다.
뒷표지의 폭은 실제 종이와 같은 최대 760px이며, 앞표지는 전체 뷰포트를 사용한다.
뒷표지를 열 때는 종이 미리보기 위에서 표지가 움직인다. ‘마지막 장 펼치기’도
같은 회전을 사용하고 기존 편집기와 마지막 쪽을 복원한다. 효과를 끄거나 OS 동작
줄이기를 쓰면 회전을 생략한다.
