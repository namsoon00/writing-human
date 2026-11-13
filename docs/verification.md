# 검증 기록

## 2026-11-14 · 원문과 통합 메뉴

- 게시 작업본에서 Dart 포맷 94개, 정적 분석과 Flutter 테스트 125개를 통과했다.
- 왼쪽 원문, 가운데 쪽수, 오른쪽 메뉴 위치와 메뉴에서 책에 넣기, 쓰기 설정 변경,
  동기화 연결을 확인했다. 합성 데이터로 필사 화면과 메뉴를 렌더링했다.
- 실제 iPhone 인앱 브라우저는 미검증이다.
- [GitHub Pages 실행 43511686139](https://github.com/namsoon00/writing-human/actions/runs/43511686139)의
  검사·빌드·게시가 성공했다. 공개 웹 번들에서 메뉴의 책 이동 레이블을 확인했다.

## 2026-11-13 · 책장 검색 중 키보드와 포커스

- 게시 작업본에서 Dart 포맷 94개, 정적 분석, Flutter 테스트 120개와 웹 터치
  이벤트 검사 4개를 통과했다.
- Flutter 테스트에서 키보드 인셋을 반복 변경해도 검색창의 위쪽 위치, 포커스,
  한글 조합값이 유지되고 뒤쪽 필사 입력이 접근성 트리에서 가려지는 것을 확인했다.
- 사용자 사진의 iPhone 인앱 브라우저와 실기기 소프트웨어 키보드는 미검증이다.
- [GitHub Pages 실행 43394335546](https://github.com/namsoon00/writing-human/actions/runs/43394335546)의
  검사·빌드·게시가 성공했다. 공개 HTML의 본문 터치 범위 변경을 확인했다.

## 2026-11-13 · 더 보기의 연필 안내 제거

- 게시 작업본에서 Dart 포맷 92개, 정적 분석과 Flutter 테스트 119개를 통과했다.
  더 보기에서 설명 행을 제거했으며 본문의 연필 표시 메뉴는 기존 구현을 사용한다.
- [GitHub Pages 실행 43393434649](https://github.com/namsoon00/writing-human/actions/runs/43393434649)의
  검사·빌드·게시가 성공했다.
- 실제 iPhone 인앱 브라우저는 미검증이다.

## 2026-11-13 · 필사 본문의 펜촉 소리

- Dart 포맷, 분석, Flutter 테스트 120개와 서버 테스트 10개를 확인했다.
  한글 조합 중 무음, 확정 시 재생 조건, 다음 글자를 조합하며 앞 글자를 확정하는
  경우, 여러 글자 붙여넣기·삭제·선택 이동의 제외 조건을 검사했다.
  쓰기 도구에서 독립 설정을 바꾸고 실제 SQLite 파일 재열기와 설정 병합을 검사했다.
- 브라우저와 물리 기기의 실제 청음은 미검증이다.
- [GitHub Actions 43394051570](https://github.com/namsoon00/writing-human/actions/runs/43394051570)의
  검사와 게시가 완료됐다. 공개 앱 JS와 WAV가 로컬 빌드와 일치했다.
  `artifacts/writing-sound-settings.png`는 Flutter 테스트에서 렌더링한 설정 화면이다.

## 2026-11-13 · 내 글의 다시 만난 문장 제거

- 게시 작업본에서 Dart 포맷 92개, 정적 분석과 Flutter 테스트 118개를 통과했다.
  내 글에 추천 구절 대신 저장한 필사가 표시되고, 검색으로 연 쪽의 연필 표시와
  선택 범위가 보존되는 것을 확인했다.
- 실제 iPhone의 인앱 브라우저는 미검증이다.
- [GitHub Pages 실행 43392798974](https://github.com/namsoon00/writing-human/actions/runs/43392798974)의
  검사·빌드·게시가 성공했다. 공개 웹 번들에서 추천 레이블이 제거된 것을 확인했다.

## 2026-11-13 · 시트 상단의 배경색

- 게시 작업본에서 Dart 포맷 92개, 정적 분석과 Flutter 테스트 118개를 통과했다.
- 합성 책으로 책장, 내 글, 목차와 쓰기 도구를 렌더링해 손잡이 뒤로 이어지는 배경을 확인했다.
  목차의 손잡이를 아래로 끌어 닫는 동작도 확인했다. 실제 iPhone 인앱 브라우저는 미검증이다.
- [GitHub Pages 실행 43389829131](https://github.com/namsoon00/writing-human/actions/runs/43389829131)의
  검사·빌드·게시가 성공했다. 공개 주소의 앱 번들이 응답하는 것을 확인했다.

## 2026-11-13 · 책의 속표지와 목차

- 별도 게시 작업본에서 Dart 포맷 91개, 정적 분석, Flutter 테스트 115개를 통과했다.
  이어서 쓰기가 마지막 쪽을, 목차 항목이 기록의 첫 쪽을 여는 동작과 쪽수 표시를 확인했다.
- 합성 필사 한 편을 사용해 Flutter에서 390×844 화면과 320×640의 두 배 글자 크기를
  렌더링했다. 실제 iPhone의 인앱 브라우저는 미검증이다.
- [GitHub Pages 실행 43386497556](https://github.com/namsoon00/writing-human/actions/runs/43386497556)의
  검사와 배포가 성공했다. 공개 웹 번들에서 새 이어서 쓰기 레이블을 확인했다.

## 2026-11-13 · 책 상세의 종이와 잉크 색

- 게시 작업본의 Dart 포맷과 정적 분석을 확인했다. Flutter 렌더에서 책 상세의 종이 배경,
  장서표의 밝은 종이색, 검색 밑줄과 갈색 새 종이 버튼을 확인했다.
- [GitHub Pages 실행 43364492249](https://github.com/namsoon00/writing-human/actions/runs/43364492249)의
  포맷·분석·테스트·웹 빌드와 게시가 성공했다.
- [GitHub Pages 실행 43364836548](https://github.com/namsoon00/writing-human/actions/runs/43364836548)의
  책 목차 개편본도 포맷·분석·테스트·웹 빌드와 게시를 통과했다. 새 목차와 더 보기의 장서표를
  Flutter에서 각각 렌더링해 종이와 잉크 색을 확인했다.
- 물리 iPhone의 인앱 브라우저 화면은 미검증이다.

## 2026-11-13 · 린넨 표지와 책의 디테일

- Dart 포맷과 정적 분석을 확인했고 Flutter 테스트 109개가 통과했다. 320px 화면과
  2배 글자 크기에서 긴 제목과 압화가 겹치지 않고 압화를 따로 숨길 수 있는지 검사했다.
  기존 디테일 설정의 SQLite 재열기, 한글 조합과 선택 범위 보존도 통과했다.
- Flutter에서 디테일 10종과 책장·큰 표지의 압화 켜기 및 끄기, 장서표·필사·원문
  화면을 렌더링했다. 물리 모바일 기기와 배포 웹의 직접 조작은 미검증이다.
- [GitHub Actions 43362740494](https://github.com/namsoon00/writing-human/actions/runs/43362740494)의 검사와 게시가 완료됐다. 공개 앱 JS와 새 표지 세 가지가 로컬 빌드와 일치했다.

## 2026-11-13 · 종이 쪽지부터 시작하는 원문 등록

- 배포 작업본의 Dart 포맷 85개, 정적 분석 및 Flutter 테스트 108개를 통과했다.
  원문 등록·붙여넣기, 두 사진 인식 모드의 진입과 검수, 공유 수신, 사진 저장,
  한글 조합 중 저장 제한을 검사했다.
- `flutter test --no-pub tool/capture_source_intake_test.dart`의 합성 사진과 Flutter
  렌더로 원문 등록, 사진 메뉴, 검수와 필사 복귀를 확인했다. 실제 기기의 카메라,
  공유 확장, 한글 키보드는 이번 검증 범위에 포함하지 않았다.
- [GitHub Pages 실행 43360721589](https://github.com/namsoon00/writing-human/actions/runs/43360721589)에서
  `141772701be18cdc7f777820ddf77c596d48f3ea`를 게시했다. 제공 JS가 로컬 release와
  일치했다. 운영 주소의 iPhone 17 Pro 시뮬레이터 Safari에서 합성 책의 원문 등록을
  열어 책 표시와 두 사진 인식 메뉴 항목을 확인했다.

## 2026-11-13 · iPhone 본문 터치와 길게 누르기

- Dart 포맷 84개, 정적 분석과 Flutter 테스트 108개가 통과했다. iOS 위젯 검사에서
  단어 안의 삽입 위치, 길게 누르기, 누른 채 범위 늘리기, 빈 줄의 접힌 선택,
  한글 조합값 보존을 확인했다.
- iPhone 17 Pro 시뮬레이터 Safari에서 기존 웹의 첫 줄 탭이 다음 줄의 글자를
  선택하는 현상을 확인했다. 수정 웹에서 첫 단어의 글자 사이를 탭해 커서와 입력
  포커스를 확인했고, 길게 눌러 첫 단어와 종이 쪽지 메뉴를 확인했다.
- [GitHub Pages 실행 43348515929](https://github.com/namsoon00/writing-human/actions/runs/43348515929)에서
  `cca8e7ba8a690a6e0ac2701c29a7b2372ad61228`을 게시했다. 운영 JS가 로컬 웹 빌드와 일치했다.
  iOS 26.4.1 시뮬레이터 Safari에서 운영 주소의 탭·길게 누르기를 다시 확인했고, DOM
  입력 이벤트로 선택 위치의 글 삽입과 저장을 확인했다. 실제 iPhone의 키보드·한글
  조합·클립보드와 다른 앱의 내장 브라우저는 미검증이다.

## 2026-11-13 · 책장과 ‘내 글’ 전환

- Dart 포맷 84개를 확인했고 분석 문제 없이 Flutter 테스트 107개가 통과했다.
  보관함 안에서 책장과 ‘내 글’의 스크롤 위치를 독립적으로 복원하고, 책 없이 쓴
  종이와 문장 검색 결과를 열어 쪽·선택 영역·스크롤을 확인했다.
- 390×844의 Flutter 위젯 렌더를 `artifacts/collection-shelf.png`와
  `artifacts/collection-writing.png`에 보관했다. 모바일 실기기 조작은 미검증이다.
- [GitHub Actions 43339186920](https://github.com/namsoon00/writing-human/actions/runs/43339186920)에서
  `8cf7d81ddec0f3987d3a7bcdee22b02a1a0c140e`의 검사·빌드·게시가 완료됐다. 배포 소스에서 실행한 로컬 테스트
  107개도 통과했다. 공개 앱 JS와 번들 서체·잉크 이미지가 로컬 빌드와 일치했다.
  앱 JS SHA-256은 `b492356fada69d2a9e60e4bad923b29a341436cacaaa5d473ec07fa9d87d0f56`이다. 공개 웹의 직접 조작은 미검증이다.

## 2026-11-13 · 종이 위에 바로 쓰는 느낀 점

- 배포 작업본의 Dart 포맷 83개, 정적 분석과 Flutter 테스트 106개를 통과했다.
  본문 줄 아래와 선택 메뉴에서 같은 종이의 손글씨 입력을 열고, 원문 보기 없이 메모가
  자동 저장되는지 확인했다. 키보드 인셋을 바꾸고 한글 조합 값과 본문 위치·선택을 검사했다.
- 저장 실패 시 입력을 유지하고 같은 자리에서 재시도했다. 메모를 비우면 본문은 그대로
  남고 원문의 메모만 제거되는지, 원문 보기와 노트에서 같은 메모를 읽고 고치는지 확인했다.
- [GitHub Pages 실행 43338309717](https://github.com/namsoon00/writing-human/actions/runs/43338309717)에서
  소스 `dda1d9b560653208ce8cfb60fecc88d2f52d38ce`를 게시했다. 제공 JS가 로컬 release와
  일치했다. 운영 주소의 Chrome 390×844 터치 에뮬레이션에서 합성 기록으로 종이에
  메모를 쓰고 새로고침 뒤 본문과 메모 복원을 확인했다. iOS·Android 실기기와 비공개 Sites는 미검증이다.

## 2026-11-13 · 입력 위치의 잉크 아이콘

- 현재 펜 색의 14px 아이콘을 실제 커서 영역 중앙에 표시한다. 줄바꿈, 방향키,
  스크롤, 키보드 높이, 글자 확대, 한글 조합과 범위 선택을 위젯 검사로 확인했다.
- [GitHub Pages 실행 43334266858](https://github.com/namsoon00/writing-human/actions/runs/43334266858)에서
  소스 `2543db389efe206db4aaa1c0ccdd5df14cffb39e`를 게시했다. 제공되는 실행 JS가
  같은 소스의 로컬 웹 release와 바이트 단위로 일치했다.

## 2026-11-13 · 안정된 쓰기 화면과 종이 선택 쪽지

- Flutter 3.41.2의 배포 작업본에서 Dart 포맷 79개, 정적 분석, Flutter 테스트
  106개를 통과했다. 위젯 테스트에서 키보드 인셋 변화 시 제목과 본문 시작 위치,
  여백 탭 뒤 선택 위치, 큰 글씨와 좁은 화면, 원문 패널의 한글 조합·스크롤 복원을 확인했다.
- 선택 쪽지의 복사, 연필 표시 저장 실패와 재시도, 빈 줄의 붙여넣기 항목, 중복 원문에서
  느낀 점 숨김, 유일한 일치에서 메모와 밑줄 저장, 본문의 선택 상태에서 저장한 메모 표시를 확인했다.
  시각 검사용 Flutter 렌더 도구의 뒷표지에서 새 쪽을 만드는 동선도 확인했다.
- 운영 주소의 Chrome 390×844 터치 에뮬레이션에서 합성 기록으로 길게 누르기,
  쪽지의 느낀 점 열기·저장, 빈 줄에서 클립보드 붙여넣기·저장, 여백 탭 뒤 입력 해제,
  새로고침 뒤 본문과 메모 복원을 확인했다. 물리 iOS·Android
  기기의 키보드와 클립보드, 비공개 Sites의 조작은 이번 검증 범위 밖이다.

## 2026-11-13 · 책장에서 표지로 바로 열기

- Dart 포맷 78개를 확인했고, 분석과 Flutter 테스트 105개가 통과했다. 큰 표지와
  상단 최근 노트 영역에서 쓰던 쪽으로 이동했다. 현재 쪽을 다시 열 때 불필요한
  저장이 발생하지 않는지 확인했다.
- 390×844의 Flutter 위젯 렌더를 `artifacts/bookshelf-direct.png`에 보관했다.
  배포 웹과 모바일 실기기의 직접 조작은 미검증이다.
- [GitHub Actions 43333046498](https://github.com/namsoon00/writing-human/actions/runs/43333046498)에서
  `3bea66233a0806ac72eb9714c976376c2b815b71`의 검사·빌드·게시가 완료됐다. 공개 앱 JS와 번들 서체·잉크 이미지가
  로컬 빌드와 일치했다. 앱 JS SHA-256은 `4f4b05f61a38ebf4ca03427b314c338056df0b20302580dd7bbce8dee5e16cbc`이다.

## 2026-11-13 · 노트 책장

- Dart 포맷 78개를 확인했고, 분석과 Flutter 테스트 105개가 통과했다. 표지와
  ‘이어 쓰기’에서 같은 노트의 위치를 열고, 다른 노트로 갔다 돌아와도 사용 중의
  위치가 이어지는지 검사했다. 16권을 스크롤하고 제목을 검색했으며, 검색만으로
  저장이 발생하지 않는지 확인했다. 기존 책 상세와 실제 SQLite 파일 재열기 검사도 통과했다.
- 390×844 화면에서 노트 3권과 12권을 실제 Flutter 위젯으로 렌더링했다.
  작업 폴더의 `artifacts/bookshelf-few.png`, `artifacts/bookshelf-many.png`에 보관했다.
- 모바일 실기기의 터치와 키보드, 공개 웹에서의 브라우저 조작은 미검증이다.
- [GitHub Actions 43331995801](https://github.com/namsoon00/writing-human/actions/runs/43331995801)에서
  `1e7e330c2d36bc9addd48945789f5be646af27a9`의 검사·빌드·게시가 완료됐다. 공개 앱 JS와 번들 서체·잉크 이미지가
  로컬 빌드와 일치했다. 앱 JS SHA-256은 `a9aa8e765567cb9e48036b08f22d9669e11c82b1d83eb21e422fbc13bfde2f67`이다.

## 2026-11-13 · 마지막 장에서 겉뒷표지 닫기

- Dart 포맷 73개를 확인했고, 분석 문제 없이 Flutter 테스트 100개가 통과했다.
  마지막 장에서 오른쪽 책등이 고정되고 표지가 드래그한 거리만큼 종이를 덮는지
  확인했다. 1440px 화면에서는 뒷표지와 본문 폭이 맞았다. 취소와 다시 펼치기,
  편집 내용 보존, 동작 줄이기, 실제 SQLite 파일 재열기 검사도 통과했다.
- Flutter 위젯 테스트에서 닫기 중간, 닫힌 겉면, 다시 열기 중간을 렌더링했다.
  작업 폴더의 `artifacts/back-cover-closing.png`, `artifacts/back-cover-closed.png`,
  `artifacts/back-cover-reopening.png`에 보관했다.
- 배포 웹에서 직접 스와이프하거나 모바일 실기기에서 조작하는 검증은 하지 않았다.
- [GitHub Actions 43327094278](https://github.com/namsoon00/writing-human/actions/runs/43327094278)에서
  `d92ce19231c77c1221ea92414a42603c9c982f61`의 검사·빌드·게시가 완료됐다.
  공개 앱 JS와 번들 서체·브랜드 이미지가 캐시를 지운 뒤 만든 로컬 빌드와 일치했다.
  앱 JS SHA-256은 `fc30de776dfccbcbfef8bf74cb8a956d7364a095fbb0a1863dc8a70f7f664e09`다.

## 2026-11-13 · 마지막 장과 뒷표지 안쪽

- Dart 포맷 73개를 확인했고 분석 문제 없이 Flutter 테스트 100개가 통과했다.
  마지막 장을 넘길 때 면지가 제자리에 있고 되넘기면 같은 장으로 돌아오는지,
  드래그 거리와 종이의 경계가 일치하는지, 1440px에서도 면지가 종이 폭에
  맞는지 검사했다. 본문·선택 영역·스크롤 및 실제 SQLite 재열기 검사도 통과했다.
- Flutter 위젯 테스트에서 넘기는 중간, 면지가 드러난 상태, 되넘기는 중간을
  렌더링했다. 작업 폴더의 `artifacts/back-endpaper-turn.png`,
  `artifacts/back-endpaper-rest.png`, `artifacts/back-endpaper-return.png`에 보관했다.
- 배포 웹에서 직접 스와이프하거나 모바일 실기기에서 조작하는 검증은 하지 않았다.
- [GitHub Actions 43325687143](https://github.com/namsoon00/writing-human/actions/runs/43325687143)에서
  `7933a6ef977b73e2d83929b650881a00eb903ba4`의 검사·빌드·게시가 완료됐다.
  공개 앱 JS와 번들 서체·브랜드 이미지가 로컬 빌드와 일치했다.
  앱 JS SHA-256은 `b14f081e94579ddd66e521b81b7b17ca11f549b437b8d1fb8948e620d4750c35`다.

## 2026-11-11 · 앞뒤 표지의 책등과 손가락 움직임

- 포맷과 분석을 확인했고 Flutter 테스트 95개가 통과했다. 앞뒤 표지를 열고 닫을 때
  책등 위치, 바깥 가장자리의 방향·이동량, 독자 쪽으로 들리는 원근을 검사했다.
  1440px 화면에서도 뒷표지의 바깥 가장자리가 드래그 거리와 일치했다.
  중간 취소와 글·선택·스크롤 보존 검사도 통과했다.
- Flutter 위젯 테스트에서 열리는 앞표지와 닫히는 앞뒤 표지를 렌더링했다.
  작업 폴더의 `artifacts/cover-opening-spine.png`,
  `artifacts/cover-closing-spine.png`, `artifacts/back-cover-closing-spine.png`에 보관했다.
- 배포 웹에서 직접 조작하는 검증은 하지 않았다.
- [GitHub Actions 43009158211](https://github.com/namsoon00/writing-human/actions/runs/43009158211)에서
  `a240562da795a0df365a818687af7942559e4785`의 검사·빌드·게시가 완료됐다.
  공개 앱 JS와 번들 서체·브랜드 이미지가 검증한 로컬 산출물과 일치했다.
  앱 JS SHA-256은 `02d810c98cd46f540402b11b6aac49ff845bb858bd59958d8453184de267b054`다.

## 2026-11-11 · 책 이름 변경과 작성 화면 제목

- Dart 포맷과 분석을 확인했고 Flutter 테스트 94개가 통과했다.
- 실제 SQLite 파일에 저장하는 화면 테스트에서 보관함의 책 이름 변경을 실행했다.
  공백 이름은 저장할 수 없고, 새 이름은 작성 화면의 제목에 바로 반영됐다.
  같은 책 ID, 본문과 선택 영역이 유지됐으며, 파일을 닫고 다시 열어 새 이름과
  원문·본문·쪽 위치를 확인했다. 빈 편집기의 안내 문구가 사라진 것도 검사했다.
- 공개 웹에서 직접 조작하는 검증은 하지 않았다.
- [GitHub Actions 42989432484](https://github.com/namsoon00/writing-human/actions/runs/42989432484)에서
  `9c900593df179f6532934c4e123d1c86ded8f3d4`의 검사·빌드·게시가 완료됐다.
  공개 앱 JS와 번들 서체·브랜드 이미지가 검증한 로컬 산출물과 일치했다.
  앱 JS SHA-256은 `ffd3010cc38865096d2bd73544c9230213bb93c5e290a88b408852e197ccacb2`다.

## 2026-11-11 · 한 쪽에 이어지는 원문

- Dart 포맷 72개, 분석 문제 없음, Flutter 테스트 94개 통과.
- 첫 문단과 다음 문단이 함께 나타나고, Enter 한 번으로 이어 쓸 수 있는지 확인했다.
  긴 원문을 같은 쪽에서 터치로 스크롤해도 본문과 쪽이 그대로였으며, 밑글씨만
  스크롤한 위치는 저장하지 않았다. 기존 SQLite 파일 재열기 검사도 통과했다.
- Flutter 위젯 테스트에서 두 문단이 한 종이에 표시되는 화면을 렌더링했다.
  작업 폴더의 `artifacts/continuous-guide-page.png`에 보관했다.
  배포 웹에서 직접 조작하는 검증은 하지 않았다.
- [GitHub Actions 42960026122](https://github.com/namsoon00/writing-human/actions/runs/42960026122)에서
  `e0c239e51f36630d94e62f0adc843cbadcd7d9ff`의 검사·빌드·게시가 완료됐다. 공개 앱 JS와
  번들 서체·브랜드 이미지가 로컬 빌드와 일치했고 시작 스크립트와 앱 JS의 버전 해시를 확인했다.
  앱 JS SHA-256은 `085316263fe15948799e6b5ece08108cf0a23b238601645e90fdd57e42aaf45e`다.

## 2026-11-11 · 저장한 글의 따라 쓰기 복원

- Dart 포맷 70개, 분석 문제 없음, Flutter 테스트 93개 통과. 두 번째 원문 문단과
  일부 필사를 저장하고 앱을 다시 열어 남은 밑글씨와 본문을 확인했다.
  기본 화면에 원문 카드가 없고 `원문 보기`로 펼칠 수 있는지도 확인했다.
- 위젯 복원 검사는 메모리 저장소를 사용했다. 실제 SQLite 파일 재열기 검사도
  전체 테스트에서 통과했다. 브라우저에서의 직접 조작은 미검증이다.
- [GitHub Actions 42948864291](https://github.com/namsoon00/writing-human/actions/runs/42948864291)에서
  `aee9f6b9ac7343c3c02a9fd76341c1f7ea4cd1bb`의 검사·빌드·게시가 완료됐다. 공개 앱 JS와
  번들 서체·브랜드 이미지가 로컬 빌드와 일치했고 시작 스크립트와 앱 JS의 버전 해시를 확인했다.
  앱 JS SHA-256은 `67969b6beab50a0a6380c85b1d9a606a44523645b9ae6b193a554f8637fa8976`다.

## 2026-11-11 · 백업, 문장 검색, 원문 이어 쓰기

- 변경한 Dart 파일에 `dart format --output=none --set-exit-if-changed`를 실행했다.
  `flutter analyze --no-pub`, `flutter test --no-pub` 93개,
  `npm run test:server` 8개가 통과했다.
- 호스트 SQLite에 실제 JSON 백업을 가져온 뒤 데이터베이스를 닫고 다시 열었다.
  기존 본문과 다른 백업 사본, 연필 표시, 선택·스크롤, 원문 문단 번호, 마지막
  백업 시각이 저장됐다. 같은 파일을 다시 가져와도 동일 사본이 추가되지 않았다.
  위젯 테스트에서 키보드가 열린 동안 보관함 검색 초점을 유지하고, 두 번째 쪽의
  검색 위치로 이동하면서 해당 쪽의 선택 영역과 본문 입력값을 보존했다.
- 로컬 전용 웹 릴리스 빌드를 헤드리스 Chrome에서 열었다. 잘못된 버전의 파일 거부,
  백업 미리보기와 가져오기, 새로고침 후 원문 문단 복원, JSON·TXT·PDF 다운로드를
  합성 기록으로 확인했다.
- 번들 서체를 넣은 한글 PDF 샘플을 Poppler로 렌더링해 3쪽의 글자·여백·쪽수를
  확인했다. pypdf 추출 결과를 공백 기준으로 정규화해 72개 행과 두 원본 쪽의
  경계 문장을 확인했다. PDF의 공백 추출은 뷰어에 따라 달라질 수 있다.
- iOS 무서명 시뮬레이터 빌드와 Android 디버그 APK 빌드가 성공했다.
  iOS·Android 실기기의 파일 선택·저장과 한글 IME, 모바일 Safari, 운영 계정
  동기화는 이번에 확인하지 않았다.


## 2026-11-11 · 화면을 채우는 앞·뒷표지

- 배포 작업본의 Dart 포맷, 정적 분석과 Flutter 테스트 89개가 통과했다.
  1440×900에서 안전 영역을 적용해도 두 표지가 화면을 채우고, 펼친 종이의
  폭과 편집기가 복원되는 것을 확인했다.
- 로컬 웹 release를 390×844와 1440×900의 Chrome 터치 화면에서 열어
  표지 닫기·취소·다시 열기, 넘김 소리, 새로고침 후 저장한 쪽 복원을 확인했다.
- 실제 iOS·Android 기기와 Safari의 전환 성능은 미검증이다.

## 2026-11-11 · 따라 쓰기와 잉크 반응

- 원문 확인의 실행 버튼을 `따라 쓰기` 하나로 정리했다.
- Dart 포맷 64개, 분석 문제 없음, Flutter 테스트 86개 통과. 입력 위치에 고정된 잉크 점,
  확정 글자 효과의 종료, 한글 조합·emoji·선택·스크롤·화면 회전·글꼴/배율 변경,
  효과 끄기·OS 동작 줄이기 상태에서 컨트롤러와 본문 보존을 확인했다.
  기존 호스트 SQLite 재열기 검사도 통과했다.
- `flutter test --no-pub tool/capture_source_intake_test.dart`를 실행해 합성 문단으로
  390×844 Flutter 화면을 렌더링했다. 한 글자를 추가한 35ms 시점의 새 잉크 효과와
  종료된 화면, 버튼 하나인 원문 확인 화면을
  `artifacts/ink-follow-{start,writing,settled}.png`에 보관했다.
- [GitHub Actions 42940050834](https://github.com/namsoon00/writing-human/actions/runs/42940050834)의
  `ccaa2104bb08362c4a7d4ad9d58b4e9937437ce8`에서 검사·빌드·게시가 완료됐다.
  공개 주소의 앱 JS·번들 서체·브랜드 이미지가 검증한 로컬 산출물과 일치했다.
  공개 HTML에서 시작 스크립트, 앱 JS로 연결되는 주소의 버전 해시도 각각 확인했다.
  앱 JS SHA-256은 `4fb6e4da2e707b5d1aedd9e167b8d35080676b2e5f6c1f310471238c766ffc11`다.
  세부 결과는 `artifacts/ink-web-check.json`에 보관했다.
- 실제 휴대폰의 한글 키보드와 배포 웹의 직접 조작은 미검증이다.

## 2026-11-11 · 표지 회전과 뒷표지

- Dart 포맷과 정적 분석이 통과했고 Flutter 검사 88개가 통과했다. 표지 닫기와
  취소·버튼 재개·동작 줄이기, 마지막 장의 입력기와 선택 영역 보존을 확인했다.
- 실제 호스트 SQLite 파일에서 마지막 장을 넘겨 뒷표지를 연 뒤, 페이지 수·본문·
  선택 영역·스크롤을 확인했다. ‘한 쪽 더’로 실제 쪽을 추가한 뒤 파일 재열기로
  두 장의 내용과 마지막 위치 복원을 확인했다.
- 로컬 release 빌드의 Chrome 터치 화면에서 표지 닫기·취소·재개와 소리 재생을
  확인했다. 검사용 기록은 임시 브라우저 프로필에만 넣었다.
- iOS·Android 실기기의 표지 전환 성능과 실제 한글 키보드, 모바일 Safari는 미검증이다.

## 2026-11-11 · 원문 입력 화면에서 바로 따라 쓰기

- 원문이 없는 종이에 `따라 쓰기`가 표시된다. 원문 입력 화면에서 같은 이름의 버튼으로
  원문을 저장하고 바로 밑글씨를 펼친다. `이 원문으로 쓰기`는 읽기 화면을 연다.
- 포맷·분석과 Flutter 테스트 86개를 확인했다. 위젯 테스트에서 새 진입 경로와 원문 저장,
  편집기 포커스 및 한글 조합을 검사했다. 320px 화면과 글자 배율 2에서 필사 공간을
  확보하는 기존 회귀 검사도 통과했다. 실제 SQLite 재열기 검사 역시 통과했다.
- 390×844 Flutter 화면을 합성 문단으로 렌더링했다. 첫 화면과 원문 확인 화면을
  `artifacts/guide-entry-paper.png`와 `artifacts/guide-entry-review.png`로 보관했다.
- [GitHub Actions 42934498994](https://github.com/namsoon00/writing-human/actions/runs/42934498994)의
  `b630c729de6b81ddd24f3708e47724e60672f715`에서 검사·빌드·게시가 완료됐다. 공개 HTML이 가리키는 시작 스크립트와
  그 스크립트가 가리키는 앱 파일이 HTTP 200이며 주소의 버전 값이 각각 파일 해시와 일치했다.
  공개 앱 JS의 SHA-256은 `0199529d5af9ccdd7e0f23c9816cd51cb6dd0e4c17e28ed104565ab41d07268b`로
  로컬 빌드와 같다. HTML과 시작 스크립트는 Flutter가 빌드마다 생성하는 서비스 워커 버전과
  그에 따른 시작 스크립트 해시에서만 달랐다.
- 브라우저와 실제 휴대폰에서의 직접 조작은 미검증이다.

## 2026-11-11 · 밑글씨를 보며 따라 쓰기

- Dart 포맷·분석을 확인했고 로컬 작업 폴더와 웹 배포 작업본의 Flutter 테스트 86개가 각각 통과했다.
- 원문 가져오기부터 따라 쓰기까지 위젯 테스트를 실행했다. 한글 조합 값, 입력한 부분의
  남은 밑글씨, 자유 입력과 줄바꿈, 수동 문단 이동, 원문 보기에서 돌아올 때의 이어 쓰기를
  검사했다. 앱에 저장한 본문과 원문을 각각 비교했고 기존 호스트 SQLite 재열기 검사도 통과했다.
- `flutter test --no-pub tool/capture_source_intake_test.dart`가 합성 원문으로 Flutter 화면을
  렌더링했다. `artifacts/source-intake-guide.png`와 `artifacts/source-intake-guide-writing.png`에서
  옅은 원문과 진한 본문이 이어지는 줄, 옆줄로 이어지는 원문을 확인했다.
- [GitHub Actions 42931409566](https://github.com/namsoon00/writing-human/actions/runs/42931409566)의
  `2ea0aef4a1a5522e48ced33e82a4c7487cbf4861`에서 웹 검사·빌드·게시를 완료했다.
  공개 주소의 HTML, main.dart.js, 쓰는 인간체 TTF가 검증한 로컬 빌드와 일치했다.
  main.dart.js SHA-256은 `f4d6eaf38c36a381ede0d3576085f38440135136389ae3eed7bc0ccfcbaa41ea`다.
- 실제 휴대폰에서의 입력과 배포 웹의 직접 조작은 미검증이다.

## 2026-11-11 · 한 문단씩 읽고 옮겨 쓰기

- Dart 포맷과 분석을 확인했다. 작업 폴더의 Flutter 테스트 85개와 GitHub Pages용
  작업본의 82개가 통과했다.
- 키보드 높이 300px·글자 배율 1.4의 320×640 위젯 테스트에서 긴 원문 스크롤 영역,
  한글 조합 중 문단 넘김 대기, 문단을 넘긴 뒤 편집기 위치·포커스·텍스트·선택과
  저장 횟수를 확인했다. 기존 SQLite 재열기 검사도 통과했다.
- `flutter test --no-pub tool/capture_source_intake_test.dart`로 390×844 Flutter 화면을
  렌더링했다. 합성 문단을 사용한 읽기·작성·다음 문단 화면은
  `artifacts/source-reading-{first,writing,next}.png`에 있다.
- [GitHub Actions 42929373524](https://github.com/namsoon00/writing-human/actions/runs/42929373524)의
  `d2a9bfa7daf8a3b4f1b7b94aa565c1789113a011`에서 웹 검사·빌드·게시를 완료했다.
  공개 주소의 HTML, main.dart.js, 쓰는 인간체 TTF가 검증한 로컬 빌드와 일치했다.
  main.dart.js SHA-256은 `f2a824e0b490437d4d88c386cb356f54d06d05c5a9d510e52f3fd1f631d2e262`다.
- 물리 iOS·Android 기기의 입력 및 브라우저에서의 직접 조작은 미검증이다.

## 2026-11-11 · 원문 놓기 웹 게시 완료

[Actions 42915266930](https://github.com/namsoon00/writing-human/actions/runs/42915266930)의
`b50e8747b5451f2fb5e24f78ca59bc9f9e7956b1`에서 검사·빌드·게시가 성공했다.
[공개 웹](https://namsoon00.github.io/writing-human/)의 HTML, 앱 JS, 인식 작업자·엔진,
번들 서체가 HTTP 200이며 검증한 로컬 산출물과 바이트 단위로 일치했다.
앱 JS SHA-256은 `7cdbc71102d036b941d2add77159d0230a966e7a63cbf10600c9bf657dffe14c`이다. 한글 모델은 빌드 환경에 따라 gzip 결과가 다르지만
압축을 푼 모델 바이트는 일치했다. 세부 결과는
`artifacts/source-intake-deployment-check.json`에 있다.
로컬 작업 폴더에서도 분석 및 원문·디스크 관련 8개 테스트가 통과했다.
기존 비공개 Sites의 project_id와 접근 범위는 유지했다.

## 2026-11-11 · 원문 놓기

- 최신 책장 넘김과 통합한 코드에서 Dart 포맷 62개 변경 없음, `flutter analyze --no-pub`
  문제 없음, `flutter test --no-pub` 81개 통과. 붙여넣기, 문단 선택과 오탈자 수정,
  한글 조합 중 공유 대기, 저장 실패 후 수신함 유지·재시도, 작은 화면과 키보드를 검사했다.
  OCR·공유의 위젯 입력은 테스트 대역이다. 별도 호스트 테스트에서는 앱 화면에서 넣은
  원문과 필사 본문을 임시 SQLite 파일에 기록하고 연결 종료·재열기 후 쪽·선택·스크롤도
  확인했다.
- `node --test tool/source_ocr.test.mjs` 2개 통과. 같은 출처의 인식 리소스,
  문단 구분, 인식 취소를 검사했다. 고정 버전의 실제 WASM 엔진을 Node에서 실행해
  합성 한글 이미지의 두 문단을 읽었다. 일부 오인식이 있었고 결과는
  `artifacts/source-intake-ocr-check.json`에 기록했다.
- `swiftc ios/Runner/SourceInbox.swift tool/check_source_inbox.swift`로 빌드한
  파일 수신함 검사 통과. 재열기, 항목별 삭제, 과대 입력 및 손상 파일 보존을
  확인했다. 실제 기기의 App Group 접근 검사는 아니다.
- `flutter test --no-pub tool/capture_source_intake_test.dart`에서 390×844의
  앱 화면을 렌더링했다. `artifacts/source-intake-{paper,choose,paragraphs,review,writing}.png`의
  문단 선택·편집 화면은 검수용 인식 결과를 주입한 화면이다.
- iOS 시뮬레이터용 무서명 빌드에 `SourceShare.appex`, Android 디버그 APK에
  한국어 ML Kit 모델이 포함됨을 확인했다. 실제 카메라·공유 창·모바일 한글 입력,
  iOS App Group 서명 배포, 공개 웹 브라우저의 OCR·클립보드 조작은 미검증이다.

## 2026-11-11 · 페이지 넘김과 앞표지 웹 게시 완료

[Actions 42913862981](https://github.com/namsoon00/writing-human/actions/runs/42913862981)의
`9445cf49d0fbf91d2f9e1bdc2df25cc6506d4224`에서 검사·빌드·게시가 성공했다.
[공개 웹](https://namsoon00.github.io/writing-human/)의 HTML, main.dart.js, 번들 쓰는 인간체가
HTTP 200이며 검증한 로컬 빌드와 바이트 단위로 일치했다.
main.dart.js SHA-256: `3ccb2048417439a3cb6dedf1912fe0964e6b2e2b9d6459fc5b74459d6c13614b`.
공개 URL에서도 임시 Chrome 프로필의 터치 에뮬레이션으로 본문 드래그·취소·확정,
앞표지 왕복, 세로 스크롤과 한글 입력의 브라우저 저장을 확인했다.
`artifacts/book-turn-deployment-check.json`과 `artifacts/chrome-turn-*.png`는 검증 작업본에 있다.
기존 비공개 Sites의 project_id와 접근 범위는 유지했다.

## 2026-11-11 · 손가락을 따라 넘기는 페이지와 앞표지

- 작업본과 배포용 작업본에서 Dart 포맷 55개 변경 없음, `flutter analyze --no-pub` 문제 없음,
  `flutter test --no-pub` 74개 통과. 휴대폰·넓은 화면에서 누른 채 움직인 75/205/60px의
  노출 폭, 드래그 취소 시 편집기·선택 유지와 무저장, 회전, 한글 composing, 저장 오류,
  책 안의 기록 간 이동, 표지에서 첫 장 재개를 확인했다.
- 호스트 SQLite 임시 파일을 종료·재개해 두 장의 실제 본문과 선택·스크롤 복원을 검사했다.
  앞표지를 본 상태에서 파일을 읽어 페이지 수와 저장된 첫 장의 ID·본문도 비교했다.
- `flutter test --no-pub tool/capture_preview_test.dart` 통과. 번들 서체로 그린
  `artifacts/readability-{backward-middle,cover-middle,cover}.png`에서 옆 장 본문과 표지를 확인했다.
- `node tool/build_github_pages.mjs /writing-human/` 성공. 빌드 산출물을 로컬 HTTP로 열어
  Chrome 157의 390×844 터치 에뮬레이션으로 드래그 중의 두 노출 폭, 짧은 드래그 취소,
  확정, 표지 열기·닫기, 세로 스크롤, 한글 문자열 입력과 브라우저 localStorage 반영을 확인했다.
  검수용 데이터는 임시 Chrome 프로필에만 넣었다.
- 물리 iOS/Android 기기와 모바일 Safari, 실제 모바일 키보드의 IME, 비공개 동기화 배포는 검증하지 않았다.

## 2026-11-11 · 새 세 요소 웹 게시 완료

[Actions 42912500229](https://github.com/namsoon00/writing-human/actions/runs/42912500229)의
소스 `4f6b64b1d5648b06dfc37dcf291e4ecbbba69551`에서 포맷·분석·테스트·빌드·게시가 성공했다.
[일반 웹](https://namsoon00.github.io/writing-human/)에서 색인 탭·문장 구분표·압화를 제공한다.
HTML, main JS, FontManifest, 실제 쓰는 인간체 0.007 TTF, 종이 이미지 5개가 HTTP 200이며
검증한 로컬 빌드와 바이트·SHA-256이 모두 일치했다. main.dart.js는 2,706,732바이트,
SHA-256 `862e63368a86cf0ac4d678494b29f4130fa7e3bee41726fe54f0b705bf69b40e`다. 확인 시각은 2026-11-10 22:16 UTC다.
`artifacts/additional-details-release-state.json`과 `artifacts/additional-details-deployment-check.json`에 기록했다.

이 게시는 로컬 저장 전용이다. 기존 비공개 Sites의 project_id·접근 권한과 서버는 유지했다.
기기와 실제 브라우저 조작의 검증 범위는 아래 기록과 같다.

## 2026-11-11 · 색인 탭·문장 구분표·압화 장식

보관함의 실제 책 이동 탭과 책별 이름, 같은 책 기록 사이의 구분표, 표지와 장서표에
놓는 압화를 추가했다. `Aa → 책의 디테일`에서 모양·색·표시를 따로 바꾸고 압화의
위치를 고를 수 있다. 기존 일곱 요소의 설정과 본문·원문·선택·composing을 보존한다.

- `dart format --output=none --set-exit-if-changed lib test tool/capture_book_detail_design_test.dart tool/capture_preview_test.dart`: 54개 파일, 변경 없음.
- `flutter analyze --no-pub`: 문제 없음. `flutter test --no-pub`: 72개 통과.
  실제 SQLite v4 파일의 v5 이전과 재열기, 기존 기록·장서표·위치 보존, 책별 색인 이름과
  열 가지 독립 설정 저장, 한글 composing 유지, 320px·글씨 2배, 탭 48px, 오류 재시도를 포함한다.
  색인 이름과 소유자·압화의 모양/색/위치 병합과 저장 한도를 넘는 이름 거부도 확인했다.
- `node --test server/sync.test.mjs`: 6개 통과. 새 이름·스타일 검증, 기존 JSON 수용,
  계정 격리와 실제 임시 서버 테스트 DB 파일 재열기를 확인했다.
- `flutter test --no-pub tool/capture_book_detail_design_test.dart`: 2개 통과.
  `artifacts/book-detail-elements-{indexTab,recordDivider,pressedFlower}.png`와
  `artifacts/book-details-elements-{shelf,bookplate,records}.png`에서 실제 Flutter 위젯을 확인했다.
  이 이미지는 번들 서체와 합성 테스트 기록으로 렌더한 것이며 실제 브라우저나 실기기 캡처가 아니다.
- `node tool/build_github_pages.mjs /writing-human/`: 로컬 저장 전용 웹 빌드 성공.

실제 iOS/Android 빌드·IME 조작과 실제 브라우저 조작, 비공개 동기화 서버 배포/실서버 기록 저장은
검증하지 않았다. 비공개 Sites project_id·접근 권한과 쓰는 인간체 0.007을 유지했다.

## 2026-11-10 · 일곱 디테일 다듬기 웹 게시 완료

[Actions 42830964689](https://github.com/namsoon00/writing-human/actions/runs/42830964689)의
소스 `18321f76fc89700a27c67a4c9d1e38c4abac6a46`에서 포맷·분석·전체 테스트·빌드·게시가 성공했다.
[일반 웹](https://namsoon00.github.io/writing-human/)의 HTML, main JS, FontManifest,
쓰는 인간체 0.007 TTF, 종이 이미지 5개 요청은 모두 HTTP 200이고 검증한 로컬 release와
바이트/해시가 일치했다. main.dart.js는 2,693,748바이트, SHA-256
`8a10e86c3d394097c1c75537647bdcd37cb204949d92a47c421da392a5742623`이다.
실제 검사 시간은 2026-11-10 14:13 UTC이며 결과는
`artifacts/details-polish-release-state.json`, `artifacts/details-polish-deployment-check.json`에 기록했다.

일곱 기존 요소의 재질·비례·가독성이 반영됐고 새 요소 후보는 아직 구현하지 않았다.
실제 브라우저 조작과 iOS/Android 검증 범위는 아래 기록의 제한을 그대로 따른다.
기존 사용자 기록과 비공개 Sites project_id·권한은 변경하지 않았다.

## 2026-11-10 · 일곱 디테일의 재질·비례·가독성 다듬기

책갈피의 직조와 비례, 제본 실, 원문 쪽지의 종이 가장자리와 접힘, 장서표의 인쇄와
이름 편집, 구분 장식, 날짜인의 눌린 잉크를 정적인 Flutter 벡터로 다듬었다.
종이·펜·글꼴과 일곱 디테일의 기존 독립 설정/저장 형식은 유지했다.
색인 탭·문장 구분표·압화는 설계 문서의 추가 후보이며 이번에 새 기능으로 추가하지 않았다.

- `dart format --output=none --set-exit-if-changed lib test tool/capture_book_detail_design_test.dart`: 51개 파일, 변경 없음.
- `flutter analyze --no-pub`: 문제 없음.
- `flutter test --no-pub`: 68개 통과. 실제 임시 SQLite 파일 재열기, 개별 설정·이름·위치 보존,
  저장 실패와 한글 composing 회귀, 작은 화면/큰 글씨 검사와 작은 인쇄 글씨의 대비 4.5:1 검사를 포함한다.
- `flutter test tool/capture_book_detail_design_test.dart --no-pub`: 2개 통과.
  실제 번들 서체/아이콘을 사용한 일곱 디테일 판과 작성 화면·원문·보관함·설정의 Flutter 렌더를 확인했다.
  앱 렌더는 명시적으로 주입한 합성 테스트 기록이며 사용자 기록이나 실제 브라우저/실기기 캡처가 아니다.
- `node tool/build_github_pages.mjs /writing-human/`: 성공. 로컬 저장 전용 웹 빌드 생성.

Mac 잠금으로 실제 브라우저 UI를 열 수 없었고 잠금을 우회하지 않았다.
실제 iOS/Android IME·최종 서체 자형/실기기 가독성·모바일 빌드·실서버 저장은 이번 검증 범위가 아니다.
쓰는 인간체 0.007과 기존 확대 글씨/커서 정책은 유지했다. 기존 비공개 Sites project_id/권한은 바꾸지 않았다.

## 2026-11-10 · 크고 선명한 글씨 웹 게시 완료

[Actions 42827190338](https://github.com/namsoon00/writing-human/actions/runs/42827190338)의
소스 `750e9081310e9999b4e6d315bcedf48dfa7de551`에서 포맷·분석·테스트·빌드·게시가 성공했다.
[일반 웹](https://namsoon00.github.io/writing-human/)에 전체 표시 크기 20% 확대,
일반 안내/조작 문구 최소 14px, 본문 약 27.6px와 실제 획을 두껍게 한 0.007을 반영했다.
최신 일반 진입·커서 표시 정책을 유지했고 종이·펜·글꼴 설정과 본문/선택/composing을
다시 설정하지 않았다. 배포 대상 코드의 테스트 67개가 통과했다.

일반 HTML·main JS·FontManifest·실제 TTF·메타데이터의 HTTP 200을 확인했다.
실제 main JS SHA-256은
`6178eb5d727dae603e05cdf835e7d32d49bda9b2ba76ff933975b670b9289e02`,
TTF는 778,776바이트, SHA-256
`927e67acd9d116c3ca4a4fec66a0327ed6f0ca3a18fb1c4eb5c89a5f21cb398b`로
검사한 로컬 release와 일치했다. 메타데이터 revision=0.007·hangul_syllables=11172도 확인했다.
결과는 `artifacts/typeface/v007/web-deployment.json`, 기준 빌드는 `web-build.json`에 있다.

작은 화면/키보드/큰 시스템 글씨와 실제 번들 TTF의 Flutter 렌더를 검사했다.
실제 브라우저 타이핑·iPhone/Android의 새 서체 가독성·최종 광학 승인은 미검증이다.
이 결과를 실기기 화면·실서버 기록 저장 검증으로 보고하지 않는다. 기존 비공개 Sites의
project_id·접근 권한과 사용자 기록은 변경하지 않았다.

## 2026-11-10 · 본문 커서 숨김 웹 배포 완료

[Actions 42826786100](https://github.com/namsoon00/writing-human/actions/runs/42826786100)의
소스 `4c3f69de5c7eb3bae7cfa57528f06ff295e57261`에서 포맷·분석·67개 검사·웹 빌드·배포가
성공했다. [웹 앱](https://namsoon00.github.io/writing-human/) 본문의 점멸 세로 커서를
숨기고 기존 펜 추적·한글 조합·선택/이동·저장을 유지했다.

HTML, main JS, FontManifest, 개발 TTF, 펜 이미지, 종이 소재 6개 요청이 HTTP 200이고
해당 소스의 로컬 release와 바이트가 일치했다. main.dart.js는 2,683,915바이트,
SHA-256 `b6c30be76a8a7098ee99380157f74bb72c313112a151b63ed43202bf462fdf6d`다.
`artifacts/hidden-caret-{build-check,deployment-check}.json`에 기록했다.

실제 UI 접근은 Mac 잠금과 Work 브라우저 사용 비활성화로 진행하지 못했다.
설정을 바꾸거나 다른 UI 제어로 우회하지 않았다. 새 화면 PNG 12개는 Flutter
테스트 렌더이며 실제 브라우저/실기기 캡처가 아니다. 실제 모바일 IME·접근성
보조기기·펜만으로 입력 위치를 구분하는 사용성은 미검증이다. 모바일 빌드는
수행하지 않았다. 이번 결과는 위 소스 기준이며 이후 독립적인 서체 확대 변경의
실행 파일·서체 해시 검증으로 사용하지 않는다. 기존 hosting 설정·기록은 유지했다.

## 2026-11-10 · 글씨 크기와 실제 획 굵기 보강

일반 화면의 본문·제목·메뉴 표시 크기를 20% 키우고 조작/안내 문구는 최소 14px로
표시한다. 시스템 TextScaler에 확대된 기준 크기를 전달해 접근성 확대를 유지한다.
기본 본문은 23px에서 약 27.6px로 커진다. 작은 표지 썸네일만 비례 장식 글씨를
유지하며 실제 책 제목은 옆의 목록 텍스트로 제공한다. 날짜 안내는 Wrap으로 바꿔
320px·시스템 글씨 2배 및 가로 화면에서 넘치지 않게 했다.

쓰는 인간체 0.007은 원래 벡터 윤곽을 바깥으로 6/1000em 확장해 실제 TTF의 획을
두껍게 만든다. 가짜 bold나 이미지 문자가 아니다. 편집 프로필은
`design/typeface/source/reading-v007.json`이며 원래 자모/영문 중심선을 보존한다.
TTF는 778,776바이트, SHA-256은
`927e67acd9d116c3ca4a4fec66a0327ed6f0ca3a18fb1c4eb5c89a5f21cb398b`다.

- 전체 cmap 11,422개와 advance를 이전판과 비교해 유지됨을 확인했다. 현대 한글
  11,172자의 고유 윤곽·경계·NFC/NFD HarfBuzz 조판과 자모 합성 규칙 검사 통과.
  원형 자모가 들어간 16개 공통 부품의 속공간은 열려 있다. 획 교차부의 작은 ㅈ/ㅊ 틈은
  두꺼운 획이 합쳐지면서 줄어든다. 이 자동 검사를 최종 광학 승인으로 보고하지 않는다.
- 최신 일반 진입 흐름에 통합 후 dart format 변경 없음, flutter analyze 문제 없음,
  flutter test 67개 통과. 본문 약 27.6px, 기존 선택·composing·커서·스크롤/실제 SQLite
  재열기·저장 실패·작은 화면과 큰 시스템 글씨의 회귀 검사를 포함한다.
- `flutter test tool/capture_preview_test.dart --no-pub`: 실제 번들 0.007 TTF로 일반 앱의
  작성·도구·보관함·페이지·키보드·넓은 화면 렌더 1개 통과. `artifacts/readability-*.png`는
  합성 문장의 Flutter 테스트 렌더이며 실제 브라우저나 실기기 화면이 아니다. 작성·도구·
  보관함 및 이전/새 획 비교를 시각적으로 확인했다.
- 폰트 검사와 로그는 `artifacts/typeface/v007/`에 있다. 실제 웹 빌드·게시 결과는
  완료 후 후속 기록에 남긴다. iPhone/Android 키보드·실제 화면 가독성과 최종 자형
  승인은 미검증이며 이전 실기기나 디스크 검사로 새 결과를 대체하지 않는다.

## 2026-11-10 · 점멸 커서 없는 본문

`lib/ui/editor.dart`의 실제 TextField에 showCursor: false를 적용했다. 본문
커서만 숨기며 입력기와 저장·선택·조합 처리는 유지한다. 기존 WritingPen이
논리적 입력 위치를 읽어 따라간다. 보조 입력칸과 펜 반응/동작 줄이기 설정은 유지한다.
원문 밑글씨를 채우는 필사는 제안 단계이며 이번 변경의 구현 결과로 보고하지 않는다.

변경 파일: `lib/ui/editor.dart`, `test/pen_motion_test.dart`,
`tool/capture_preview_test.dart`, 제품·구조·검증 문서.
실행: `flutter run -d chrome --dart-define=WRITING_HUMAN_LOCAL_ONLY=true`.

이번 코드의 검사:

- `dart format lib test tool/capture_preview_test.dart`: 50개 파일, 변경 없음.
  `flutter analyze --no-pub`: 문제 없음. `flutter test --no-pub`: 67개 통과.
- 기존 펜 검사에서 실제 RenderEditable.showCursor 값이 false인 상태에서도
  펜촉과 논리적 입력 위치가 일치하는지 확인했다. 확정 입력·줄바꿈·탭 이동·한글
  조합·emoji·서체/스크롤 변경 검사에 적용했다. 방향키로 선택 위치를 옮긴 뒤
  펜이 새 위치를 따르고 650ms 뒤에도 커서가 보이지 않으며 입력 값이 유지됐다.
- 기존 저장 실패·페이지 스와이프·선택·복원 검사가 통과했다. 호스트 SQLite
  파일 재연결 후 본문·두 쪽·마지막 선택/스크롤 복원 검사도 새 소스에서 통과했다.
  실제 모바일 프로세스·키보드 검증으로 계산하지 않는다.

화면 렌더 `flutter test tool/capture_preview_test.dart --no-pub` 1개도 통과했다.
`artifacts/hidden-caret-*.png` 12개를 새 코드로 생성해 펜 반응 프레임에서 세로
커서가 보이지 않는 것을 직접 확인했다. 실제 제품 위젯·번들 서체의 Flutter 테스트
렌더이며 합성 문장과 test inset을 사용했다. 브라우저/실기기 실행 화면은 아니다.
웹 빌드·배포는 후속 기록에 남긴다. 실제 브라우저·모바일 IME와
키보드·접근성 보조기기·입력 위치 판독성은 미검증이다. 모바일 빌드를 수행했다고
보고하지 않는다. 기존 hosting 설정·사용자 기록과 진행 중인 다른 변경은 보존한다.

## 2026-11-10 · 예시 진입 제거와 일반 앱 직접 적용 검증

일곱 요소와 독립 설정은 일반 화면에 유지하고, 저장되지 않는 예시 앱으로 이동하는
사용자 진입을 제거했다. 이전 reference/typeface 데모 링크도 실제 저장소의 같은 앱을 연다.
웹에서는 해당 매개변수만 정리하고 다른 쿼리·fragment·origin을 보존한다. history 변경이
제한되어도 실제 저장소 열기를 막지 않는다. 합성 자료를 개인 기록에 자동으로 넣지 않는다.

- 배포 작업본에서 dart format lib test/entry_location_test.dart: 37개 파일, 변경 없음.
- flutter analyze --no-pub: 문제 없음. flutter test --no-pub: 67개 통과.
- 새 검사 3개는 이전 두 종류 링크와 반복 쿼리·fragment·인코딩된 경로의 정리, 빈 보관함의
  예시 진입/자동 샘플 생성 없음과 첫 실제 입력 저장·복원, 기존 기록에서 일곱 설정의
  실제 저장을 확인한다. 새 UI 검사의 메모리 저장소를 실제 디스크 검증으로 보고하지 않는다.
  기존 실제 SQLite 파일 재열기·이전, 한글 조합·선택·스크롤, 독립 설정 검사도 함께 통과했다.
- node tool/build_github_pages.mjs /writing-human/: release 빌드 성공. 실제 사용자 진입 코드에 비영구 데모 자료가 포함되지 않음을 검사했다.
- DemoStore는 테스트와 명시적으로 주입하는 개발용 자료로만 남고, main/Workspace/보관함과
  연결하지 않는다. 사용자에게 보이는 예시 배너·예시 상태·예시 둘러보기 메뉴를 제거했다.
- 실제 브라우저의 history 정리·한국어 키보드 및 iOS/Android 실기기 조작은 미검증이다.
  이번 배포의 결과와 실제 제공 JS 일치는 완료 후 기록으로 구분한다.

## 2026-11-10 · 일곱 스타일 요소와 독립 설정 웹 배포 완료

[Actions 42824161690](https://github.com/namsoon00/writing-human/actions/runs/42824161690)의
소스 `86122ea1743b5df81e004f89ac0125b73ed651a4`에서 포맷·분석·테스트·빌드·게시가 성공했다.
기존 서체·쪽수/스와이프를 보존한 별도 배포 작업본에서 Flutter 검사 64개와 서버 검사 5개도 통과했다.

[웹 앱](https://namsoon00.github.io/writing-human/)의 Aa → 책의 디테일에서
천 책갈피·장서표·원문 쪽지·연필 흔적·판면 장식·제본·날짜인을 각각 켜고 끄며
세 모양·네 색을 선택한다. 예시 진입은 필수 조건이 아니며, 이름·원문·구절 범위·날짜를
꾸밈 설정과 분리해 보존한다. [합성 예시](https://namsoon00.github.io/writing-human/?demo=reference)도 같은 배포다.

실제 index HTML·bootstrap·main JS·FontManifest·쓰는 인간체 TTF·잉크/종이 자산 7개 요청이
모두 HTTP 200이었다. main JS는 2,687,640바이트이며 SHA-256은
`339ca71884c9612c1c305c2ccb88d469e63cf8e45e1403c4136092cd6eeadfc6`으로 검증한 release와 같다.
이 중 bootstrap을 제외한 6개는 바이트가 동일했다. bootstrap은 생성된 serviceWorkerVersion
값만 다르고 나머지 로더·엔진·실행 경로가 동일했다. 추가로 서비스 워커도 HTTP 200 및
784바이트의 정확한 일치를 확인했다. 결과는 artifacts/book-details-deployment-check.json,
소스·빌드 기준은 artifacts/book-details-release-state.json에 보관한다.

현재 Mac이 잠겨 있고 활성 브라우저가 없어 실제 브라우저 조작·캡처는 수행하지 못했다.
테스트 렌더·HTTP·파일 일치를 실제 iOS/Android 키보드·터치·접근성 검증으로 보고하지 않는다.
이번 배포는 기존 공개 GitHub Pages를 갱신한 것이며, 비공개 Sites의 project_id·접근 범위·기록은 변경하지 않았다.

## 2026-11-10 · 독서와 쓰기의 일곱 요소 배포 전 검증

최신 공개 소스 9d7826efa7b69e9f4522b48b47e5c4cde91cc602를 기준으로 별도의 작업본을 만들고 일곱 요소·개별 설정·원문/소유자/날짜/연필 표시 보존을 합쳤다. 기존 전체 서체·종이 전체 넘김·스와이프 흐름을 유지했다. 사용자 기록·자격 증명·로컬 실행 산출물을 업로드하지 않는다.

- dart format lib test tool/capture_preview_test.dart tool/capture_book_detail_design_test.dart: 47개 파일, 변경 없음. flutter analyze --no-pub: 문제 없음.
- flutter test --no-pub: 이 배포 작업본에서 64개 통과. 실제 SQLite 파일 재열기·v3→v4 이전, 한글 composing·선택·스크롤 보존, 스타일 독립 저장/병합, 구절 표시/지우기, 실패 재시도, 기존 기본 서체·스와이프·페이지 넘김 회귀를 포함한다. 메모리 원격 어댑터 검사를 실제 다기기 동기화로 보고하지 않는다.
- npm run test:server: 5개 통과. Node SQLite 파일의 실제 재열기, optional 메타데이터·독립 선택의 검증 및 보존을 포함한다. 배포 서버 검증과 구분한다.
- node tool/build_github_pages.mjs /writing-human/: release 웹 빌드 성공. 출력은 build/github-pages이며 /writing-human/ base href, 로컬 저장 전용 설정, .nojekyll을 확인했다.
- 기존 .openai/hosting.json의 project_id와 서체 파일이 변경되지 않았음을 확인했다. 비공개 Sites 접근 설정은 변경하지 않는다.
- 현재 컴퓨터가 잠겨 있고 활성 브라우저가 없어 실제 브라우저 조작·캡처는 수행하지 못했다. 실제 모바일 한국어 키보드·접근성·실기기 성능은 미검증이다. 실제 게시 성공과 제공 파일 일치 결과는 배포 후 검증 기록으로 구분한다.


## 2026-11-10 · 쪽수·스와이프 웹 배포 완료

[Actions 42823317701](https://github.com/namsoon00/writing-human/actions/runs/42823317701)의
소스 `9d7826efa7b69e9f4522b48b47e5c4cde91cc602`에서 포맷·분석·49개 검사·웹 빌드·배포가
성공했다. [웹 앱](https://namsoon00.github.io/writing-human/)의 하단 화살표·추가 버튼을
제거하고 현재 쪽수·좌우 넘김·마지막 쪽에서 새 종이 추가를 반영했다.

기본/예시 HTML, 실행 JS, FontManifest, 개발 TTF, Material 아이콘 6개 요청이
HTTP 200이었고 검증한 로컬 release와 바이트가 일치했다. main.dart.js는
2,640,177바이트, SHA-256 `d7fb332a48adb834819742d446aaa4295d38096ced3a58dbf1597c914dc9d83f`다.
`artifacts/paper-swipe-{build-check,deployment-check}.json`에 기록했다.

실제 UI 확인은 Mac 잠금·Work의 브라우저 사용 비활성화로 진행하지 못했다.
설정을 바꾸거나 다른 UI 제어로 우회하지 않았다. 새 PNG 12개는 현재 제품 위젯의
Flutter 테스트 렌더이며 실기기/브라우저 실행 화면과 구분한다. 실제 한국어 IME,
트랙패드·모바일 전환 성능은 미검증이다. 기존 비공개 hosting 설정·기록을 유지했다.

## 2026-11-10 · 버튼 없이 쪽수와 스와이프로 넘기기

변경 파일: `lib/ui/paper_swipe.dart`, `writing_chrome.dart`, `workspace.dart`,
`test/page_navigation_test.dart`, `test/data/editor_disk_test.dart`,
`tool/capture_preview_test.dart`와 제품·구조 문서.

하단 이전/다음/추가 버튼과 분수형 쪽수를 없앴다. 현재 쪽수와 작은 저장 상태,
도구·더 보기/완료를 64px 기본 높이 한 줄에 놓아 본문 공간을 늘렸다.
읽는 상태에서는 종이 위를 좌우로 넘긴다. 마지막 쪽의 다음 넘김은 같은 필사에
새 빈 쪽을 실제 저장한다. 첫 쪽의 이전 넘김은 그대로 둔다. 글을 쓰는 동안은
본문 드래그를 기존 편집기에 맡기고, 쪽수 영역에서 넘긴다. 번호 탭은 미리보기를 연다.

실행: `flutter run -d chrome --dart-define=WRITING_HUMAN_LOCAL_ONLY=true`.
빌드: `node tool/build_github_pages.mjs /writing-human/`.

이번 코드의 검증:

- `dart format lib test tool/capture_preview_test.dart`: 37개 파일 포맷 완료.
  `flutter analyze --no-pub`: 문제 없음. `flutter test --no-pub`: 49개 통과.
- 페이지 검사 13개: 본문/쪽수 넘김, 첫 쪽 경계·마지막 쪽 추가, 느린 드래그,
  작은 이동·세로 스크롤 무시, 입력 중 본문 드래그 유지, 마우스 글 선택과 쪽수
  드래그, 길게 눌러 글 선택을 확인했다. 한글 조합 중 이동 차단·저장 실패 재시도,
  각 쪽 선택/스크롤 복원·전체 화면 전환·동작 줄이기 검사도 새 UI로 통과했다.
- 호스트 SQLite UI 검사에서 쪽수 스와이프로 둘째 쪽을 작성하고 DB를 종료/재연결했다.
  둘째 쪽과 마지막 위치 복원, 이전 쪽의 본문·선택 영역·스크롤 710 복원을 확인했다.
  호스트 파일/Flutter 검사이며 실제 모바일 프로세스·키보드 검증으로 계산하지 않는다.
- `flutter test tool/capture_preview_test.dart --no-pub`: 1개 통과. 실제 제품
  위젯과 번들 서체·종이로 `artifacts/paper-swipe-*.png` 12개를 새로 만들었다.
  합성 문장과 test inset이며 브라우저/실기기 실행 캡처가 아니다. 정지 화면에서
  하단 버튼 제거·작은 쪽수·늘어난 본문 공간을 직접 확인했다. 한 화면은 도구를
  두 번 렌더하므로 파일 개수는 12개다.
- `/writing-human/` base href의 로컬 저장용 웹 release 빌드 성공.

초기에는 본문의 pan recognizer가 먼저 잡아 종이 넘김이 빠지는 문제가 검사에서
발견됐다. 수평 의도를 먼저 구분하되 세로·탭·길게 누르기는 기존 입력기로 보내도록
수정한 뒤 전체 검사를 통과했다. 입력 리스너에서 본문·selection·composing을
되쓰거나 포인터 이벤트를 재생하지 않는다.

미검증: 실제 브라우저·모바일 IME/트랙패드·전환 프레임 성능, OS 강제 종료.
이번에는 iOS/Android 빌드를 실행하지 않았다. 공유 작업 공간의 진행 중 변경을
보존하고 배포 main의 기본 쓰는 인간체를 유지한 별도 체크아웃에서 검증했다.
배포 결과는 후속 항목에 기록한다. 기존 비공개 hosting 설정과 사용자 기록은 유지한다.

## 2026-11-10 · 일반 웹 전체 쓰는 인간체 기본 적용 게시 완료

[Actions 42804908393](https://github.com/namsoon00/writing-human/actions/runs/42804908393)에서
소스 `79a3c989606d2f89f1c5cde8dfe40961390dd576`의 검사·빌드·게시가 성공했다.
구현 소스는 `7894e4601ff66ccdca4cfdd28c9f3d7d08ba6e29`이며 재게시 버전의 앱 코드는 같다.
[일반 웹 주소](https://namsoon00.github.io/writing-human/)에 쓰는 인간체를 기본 적용했다.
예시나 최초 글꼴 선택 없이 기존 페이지·작성지·제목·메뉴·보관함·페이지 목록·도구·
입력 대화상자에 적용한다. 이후 사용자가 명시적으로 선택한 다른 본문 글꼴은 유지한다.

배포 소스의 포맷·분석·테스트 46개, 실제 폰트로 일반 화면을 렌더한 검사 1개,
release 웹 빌드가 통과했다. 구형 JSON/실제 SQLite의 1회 기본 글꼴 전환과 재열기,
본문·선택·스크롤·독립 도구 설정 보존을 확인했다. 상세 범위는 아래 구현 기록을 따른다.

첫 실행 42802990398은 GitHub Pages의 syncing_files 상태에서 10분 시간 초과였고,
실패 단계만 재실행하면 같은 SHA가 Deployment cancelled를 반환했다. 검증된 앱 코드를
바꾸지 않고 새 SHA로 게시해 성공했다. 시간 초과나 취소를 게시 성공으로 보고하지 않았다.

실제 일반 HTML·main JS·FontManifest·TTF·메타데이터 5개 요청이 HTTP 200이었다.
main JS SHA-256은
`f10f7c39f0d6d7a6cf3a34a6e47f5a0f2835e5327e3adda063c06589169de5bd`이며 로컬 release와 동일했다.
실제 JS의 typefaceDefaultsVersion 전환 필드도 확인했다. TTF는 기존 전체 한글 0.006과
동일한 742,856바이트이며 해시는
`1b7c824ece6e653e9e2d72751346b1b703fd3a6e695171a9a62f60e2e21044f0`이다.
결과는 `artifacts/typeface/v006/global-web-deployment.json`, 기준 빌드는 `global-web-build.json`이다.

이는 Flutter 실행 검사와 배포/HTTP 동일 파일 확인이다. 실제 브라우저 입력·iPhone/Android
키보드·최종 가독성/광학 검수는 미검증이며 예시 렌더를 실기기나 사용자 디스크 검증으로
보고하지 않는다. 기존 비공개 Sites의 project_id와 접근 범위는 변경하지 않았다.

## 2026-11-10 · 전체 화면 넘김 웹 배포 완료

[Actions 42802397738](https://github.com/namsoon00/writing-human/actions/runs/42802397738),
소스 `bcafc0ee6791138081e661252d4078ecf25c1949`의 포맷·분석·43개 검사·웹 빌드·배포가
성공했다. [웹 앱](https://namsoon00.github.io/writing-human/)에서 페이지 추가·이동 시
상단 브랜드부터 하단 도구까지 종이 한 장으로 넘어간다.

기본/예시 HTML, main JS, FontManifest, 개발 TTF, Material 아이콘 6개 요청이
HTTP 200이었다. 최초 로컬 캐시 빌드는 JS가 달라 `flutter clean` → pub get →
release 빌드를 새로 수행했다. 새 빌드와 공개 JS는 2,637,077바이트로 동일하며
SHA-256은 `3abeea53fddd9efad4b5c3514ea63ca6faefd3ef29b612bebd7ea8eb82f45064`다.
최종 6개 파일이 모두 로컬과 일치했다. 기존 0.006 개발 서체도 유지했다.
`artifacts/fullscreen-turn-{build-check,deployment-check}.json`에 결과를 기록했다.

실제 UI 접근을 시도했으나 Mac 잠금과 Work 브라우저 사용 비활성화로 진행하지
못했다. 설정을 바꾸거나 다른 UI 제어 수단으로 우회하지 않았다. 새로 만든 13개
PNG는 제품 위젯의 Flutter 테스트 렌더다. 실제 브라우저·기기 IME·전환 성능은
미검증이며 이번 변경에서 모바일 빌드/실행을 수행했다고 보고하지 않는다.

## 2026-11-10 · 일반 화면 전체에 쓰는 인간체 기본 적용

사용자의 전체 적용 요청에 따라 일반 주소의 작성지·기존 페이지·브랜드 제목·보관함·
페이지 목록·도구·대화상자의 기본 글꼴을 실제 WritingHumanDevelopment로 변경했다.
예시 진입이나 사용자의 최초 선택은 필요하지 않다. 글꼴 선택지에는 쓰는 인간체로
표시하며 TTF의 최종 광학/실기기 검수 상태를 출시 완료로 바꾸지 않는다.

기존 style JSON은 typefaceDefaultsVersion이 없으면 useDevelopmentTypeface=true로
한 번 읽고, 이후 저장에 typefaceDefaultsVersion: 1을 남긴다. 이후 명시적으로 선택한
나눔 글꼴은 다시 강제 전환하지 않는다. 본문·페이지 ID·선택·스크롤·종이·펜·줄 가이드를
보존한다. 새 DB 스키마나 입력 중 문자열/selection/composing 재설정은 추가하지 않았다.

배포 대상 최신 페이지 넘김 코드에 통합 후 dart format 변경 없음, flutter analyze 문제 없음,
flutter test 46개 통과. 새 회귀 검사 3개는 구형 웹 JSON의 1회 전환과 선택 보존,
실제 SQLite 파일의 구형 설정 재열기 및 대체 글꼴 재열기, 일반 앱의 본문·테마·보관함·
대화상자·도구 실제 스타일과 같은 편집 컨트롤러/선택 보존을 검사한다.

`tool/capture_preview_test.dart`는 일반 WritingHumanApp에 실제 번들 TTF를 로드하고
글꼴 선택 없이 작성 화면과 도구·보관함·페이지 이동·넓은 화면을 렌더한다.
`artifacts/global-typeface-*.png`는 Flutter 테스트 렌더/합성 데이터이며 실제 브라우저나
실기기 입력·사용자 디스크 기록의 검증 화면이 아니다. iPhone/Android 키보드와 최종
가독성·광학 승인은 미검증이다. 최신 통합 코드로 렌더 검사 1개와
GitHub Pages release 빌드도 성공했다. 실제 게시 결과는 후속 기록에 남긴다.

## 2026-11-10 · 화면 전체를 한 장으로 넘기기

사용자 피드백으로 본문 안쪽에 한정됐던 전환을 앱의 종이 화면 전체로 넓혔다.
상단 브랜드·본문·하단 도구가 함께 넘어간다. OS 상태 표시·키보드는 전환 대상이 아니다.

변경 파일은 `lib/ui/page_turn.dart`, `lib/ui/workspace.dart`,
`test/page_navigation_test.dart`, `tool/capture_preview_test.dart`와 제품·구조 문서다.
PageTurnView가 Scaffold 본문 전체를 감싸고 떠나는 화면의 마지막 paint layer를
임시 메모리 이미지로 쓴다. 실제 편집기·포커스·저장 리스너는 복제하지 않는다.
메모리 이미지는 전환 종료·중단·dispose 때 해제하며 파일로 저장하거나 업로드하지 않는다.
스냅샷 실패는 저장 오류와 분리해 장식만 생략하며 페이지 이동과 입력은 유지한다.

실행: `flutter run -d chrome --dart-define=WRITING_HUMAN_LOCAL_ONLY=true`.
페이지 추가·이전/다음·하단 넘김·미리보기에서 페이지를 선택하면 전체 전환을 볼 수 있다.

새 코드의 검사:

- `dart format lib test tool/capture_preview_test.dart`: 35개 파일 포맷 완료.
  `flutter analyze --no-pub`: 문제 없음. `flutter test --no-pub`: 43개 통과.
- 새 검사 3개는 390×844·1440×1000과 safe area에서도 장식 영역이 화면
  위부터 아래까지 이어지고 상단·하단을 포함하는지, 이미지 크기 제한, 빠른 역방향
  이동과 편집기 하나 유지, 화면 회전 시 이미지 제거·같은 입력 controller 보존을 확인한다.
- 기존 한글 조합 보호·저장 실패 후 재시도·각 페이지 선택/스크롤 복원 검사도
  새 코드에서 통과했다. 호스트 SQLite 파일 종료/재연결 후 두 쪽의 본문과 마지막
  위치를 복원하는 UI 검사도 포함한다. 이는 실제 폰 프로세스/IME 검증은 아니다.
- 첫 시도에서는 버튼 반응으로 repaint 대기 중인 화면을 제외해 넘김이 빠지는 문제가
  위젯 검사에서 드러났다. 마지막으로 그려진 layer를 읽도록 수정한 뒤 전체 검사를
  다시 통과했다. 분석기의 if 블록 경고도 수정 후 문제 없음으로 확인했다.

`flutter test tool/capture_preview_test.dart --no-pub` 1개와 웹 release 빌드도
성공했다. `artifacts/fullscreen-turn-*.png` 13개를 새 소스로 생성했고 양방향
중간 프레임에서 상단·하단을 가로지르는 종이 휨과 본문·도구를 직접 확인했다.
실제 제품 위젯과 번들 폰트의 테스트 렌더이며 합성 문장·키보드 inset을 썼다.
브라우저/실기기 실행 화면으로 보고하지 않는다. 배포 결과는 후속 항목에 기록한다.
실제 브라우저 조작·기기 IME,
모바일/CanvasKit의 실제 프레임 지연·메모리 사용량, 키보드 전환 성능은 미검증이다.
이 변경에서 iOS/Android 빌드를 실행했다고 보고하지 않는다. 이전 빌드 결과와 구분한다.
공유 작업 공간의 진행 중인 책 상세·장식 변경을 보존하고 배포된 main 기반 별도
체크아웃에서 이번 변경만 검증한다. 기존 hosting 설정·사용자 기록은 변경하지 않는다.

## 2026-11-10 · 페이지 넘김 웹 배포 완료

[Actions 42800541152](https://github.com/namsoon00/writing-human/actions/runs/42800541152)의
소스 `212458ed3618434b034eed34163fc258f90b0543`에서 포맷·분석·테스트·웹 빌드·배포가
모두 성공했다. [웹 앱](https://namsoon00.github.io/writing-human/) 하단의 페이지 추가,
이전/다음, 쪽수 → 미리보기에서 종이 넘김을 사용할 수 있다.
[두 쪽 예시](https://namsoon00.github.io/writing-human/?demo=typeface)는 비영구 합성 데이터다.

기본/예시 HTML, main JS, FontManifest, 실제 개발 TTF, Material 아이콘의
6개 요청이 HTTP 200이었고 로컬 release와 바이트가 일치했다. main.dart.js의
SHA-256은 `538ab05eb0ca4b0231a2c899e9466b0e0dfec6c77508edd4c79b3f2f053ef994`다.
이미 게시된 0.006 개발 서체도 그대로 보존했다. 결과는
`artifacts/page-turn-{build-check,deployment-check}.json`에 있다.

통합 소스의 iOS 시뮬레이터 빌드도 성공했다. 실제 UI 확인은 Mac 잠금과 Work의
브라우저 사용 비활성화로 진행하지 못했다. 설정을 바꾸거나 다른 제어 수단으로
우회하지 않았다. 13개 화면 PNG는 새 제품 위젯의 Flutter 테스트 렌더이며
브라우저/실기기 실행 화면으로 보고하지 않는다. 실제 기기 IME·전환 성능은 미검증이다.
기존 비공개 Sites의 project_id·접근 범위와 사용자 기록을 변경하지 않았다.

## 2026-11-10 · 종이를 넘기는 페이지 추가·이동

변경 파일:

- `lib/ui/page_turn.dart`, `pages_sheet.dart`: 곡선 종이 넘김과 본문 미리보기.
- `lib/ui/workspace.dart`, `writing_chrome.dart`: 쪽수·이전/다음·추가·하단 좌우
  넘김, 시트를 닫은 후 전환, 한글 조합·저장 실패·계정 변경 보호.
- `lib/ui/paper.dart`, `editor.dart`: 편집기와 전환 미리보기의 여백 공유.
- `lib/data/library_controller.dart`: 명시적인 빈 쪽 보관과 다음 쪽 번호 계산.
- `lib/data/demo_store.dart`: 비영구 예시의 첫 기록에 실제 두 쪽을 제공.
- `test/page_navigation_test.dart`, `test/data/editor_disk_test.dart`,
  `tool/capture_preview_test.dart` 및 제품·구조 문서.

실행: `flutter run -d chrome --dart-define=WRITING_HUMAN_LOCAL_ONLY=true`.
하단 페이지 추가를 누르면 종이가 휘어 넘어가며 새 쪽이 나타난다. 이전/다음
또는 하단 쪽수 영역의 좌우 넘김으로 이동한다. 쪽수 → 미리보기에서 쪽 선택과
‘한 쪽 더’를 사용할 수 있다. 본문은 기존 선택·스크롤 동작을 유지한다.

이번 소스의 검사:

- `dart format lib test tool/capture_preview_test.dart`: 35개 파일, 변경 없음.
  `flutter analyze --no-pub`: 문제 없음. `flutter test --no-pub`: 40개 통과.
- 새 위젯 검사 7개: 빈 쪽 추가·복원, 전환 중 실제 편집기 하나와 즉시 입력,
  각 쪽 선택 영역·스크롤 복원, 미리보기 종료 후 이동, 조합 입력 중 이동 금지,
  동작 줄이기, 저장 실패 후 재시도, 하단 넘김과 본문 드래그 분리를 확인했다.
- 호스트 실제 SQLite UI 검사를 확장했다. 첫 쪽 본문·선택 영역·스크롤 710을
  저장하고 둘째 쪽 작성 후 DB 연결을 종료/재연결했다. 둘째 쪽과 마지막 위치가
  복원되고 이전 쪽으로 이동하면 첫 쪽 본문·선택 영역·스크롤도 복원됐다.
  메모리 저장을 디스크 검증으로 계산하지 않았다.
- `flutter test tool/capture_preview_test.dart --no-pub`: 1개 통과. 실제 제품
  위젯·번들 글꼴·Material/Cupertino 아이콘·종이 소재로 13개 프레임을 렌더한다.
  `artifacts/page-turn-{forward-middle,backward-middle,overview,new-page,desktop}.png`
  등을 직접 확인했다. 합성 문장과 테스트 키보드 inset이며 실제 브라우저/폰
  실행 캡처가 아니다. 초기 캡처의 Material 아이콘 폰트 누락을 수정해 재생성했다.

페이지 변경은 별도 체크아웃에서 검증했다. 병행 작업에서 이미 원격 main에
게시된 서체 확장 커밋 `9150f6f`를 받아 보존한 뒤 포맷·분석·40개 검사를
다시 통과했다. 공유 작업 공간의 미게시 서체/기록 모델 변경을 섞거나 덮어쓰지 않았다.

미검증: 실제 브라우저·iOS/Android 한국어 IME와 키보드, 모바일 애니메이션
프레임 성능, OS 강제 종료, 실제 두 기기의 동기화. 넘김 소리·자동 쪽 나누기는
추가하지 않았다. 통합 소스의 웹 release 빌드와 iOS 시뮬레이터 빌드도 성공했다.
시뮬레이터 설치·실행 검증과는 구분한다. 배포 결과는 후속 항목에 기록한다.

## 2026-11-10 · 전체 한글 쓰는 인간체 웹 게시 완료

[Actions 42799991684](https://github.com/namsoon00/writing-human/actions/runs/42799991684)에서
소스 `9150f6f1d1a5db7832682e9d01450bb9fa4664a5`의 포맷·분석·테스트·웹 빌드·배포가 성공했다.
배포 대상만 분리한 로컬 검사에서도 포맷·분석·테스트 33개와 release 빌드가 통과했다.
다른 기능의 진행 중 변경은 이 배포에 포함하지 않았다.

[웹 앱](https://namsoon00.github.io/writing-human/)에서 Aa → 글꼴 → 쓰는 인간체 · 개발 중을
선택하면 현대 한글 11,172자·자모·영문·숫자를 지원하는 0.006을 사용한다.
[서체 예시](https://namsoon00.github.io/writing-human/?demo=typeface)는 합성 데이터다.
기존 글꼴 선택은 유지한다.

실제 기본/서체 예시 HTML, FontManifest, TTF, 메타데이터, main JS의 6개 요청이 HTTP 200이었다.
TTF는 742,856바이트, SHA-256
`1b7c824ece6e653e9e2d72751346b1b703fd3a6e695171a9a62f60e2e21044f0`으로 로컬과 동일했다.
메타데이터의 revision=0.006·hangul_syllables=11172를 확인했다. 실제 main JS 해시
`3313e3135065aeeab830da5a1a1b6f4e049ac2ad8be715b0e242faf9317aa881`도 로컬 release와 일치했다.
결과는 `artifacts/typeface/v006/web-deployment-check.json`, 빌드 기준은 `web-build-check.json`에 있다.

이는 배포·HTTP·동일 파일 확인이며 실제 브라우저 타이핑·iPhone/Android 키보드·가독성
검수는 이번 게시에서 수행하지 않았다. 최종 광학 검수 전까지 개발 중 표기를 유지한다.
기존 비공개 Sites의 project_id·접근 범위와 사용자 기록은 변경하지 않았다.

## 2026-11-10 · 전체 한글 서체 웹 반영 준비

기존 GitHub Pages의 main을 별도 체크아웃으로 열고 서체 관련 변경만 적용했다.
현대 한글 11,172자·자모·영문·숫자를 지원하는 0.006 TTF를 기존 Flutter family에
연결하며 기본/기존 글꼴 선택과 사용자 기록을 유지한다. 실제 적용은 Aa → 글꼴 →
쓰는 인간체 · 개발 중, 즉시 확인용 합성 예시는 `?demo=typeface`다.

앱 번들 TTF SHA-256: `1b7c824ece6e653e9e2d72751346b1b703fd3a6e695171a9a62f60e2e21044f0`.
`dart format lib test tool/capture_preview_test.dart tool/render_full_typeface_test.dart`: 변경 없음.
`flutter analyze --no-pub`: 문제 없음. `flutter test --no-pub`: 배포 대상 코드에서 33개 통과.
`node tool/build_github_pages.mjs /writing-human/`: release 빌드 성공.
FontManifest 등록·빌드 TTF 해시·새 지원 범위 안내 문자열을 확인했다.
실제 배포 결과는 완료 후 후속 기록에 남긴다. 기존 소유자 비공개 Sites의
project_id·접근 권한과 다른 기능의 진행 중 변경은 이 배포에서 변경하지 않는다.
실제 브라우저·모바일 키보드/가독성 검증과 HTTP·빌드 검증은 구분한다.

## 2026-11-10 · 개발 서체 포함 웹 배포 확인

[Actions 42795999490](https://github.com/namsoon00/writing-human/actions/runs/42795999490)에서
소스 `28884e22f860c815722c0b6a52712e6b8698a6bf`의 분석·테스트·빌드·배포가 성공했다.
즉시 확인용 합성 예시는 https://namsoon00.github.io/writing-human/?demo=typeface 이다.
실제 기록에는 Aa → 글꼴 → 쓰는 인간체 · 개발 중을 선택하면 저장·복원된다.

기본/서체 예시 HTML, main JS, FontManifest, 실제 TTF, 서체 메타데이터,
나눔명조 7개 요청이 HTTP 200이었다. 제공 JS의 SHA-256
`80d8cefcb784c30122d69b81dd558c0226c4e44f7ab763bc381ec2dee54e657e`가
로컬 release와 일치했다. FontManifest의 WritingHumanDevelopment 등록과
배포 TTF의 SHA-256 `eda1b102b1d09cf322fa625bc25f1826333486142b6098570188690a99d83a2e`가
원본과 동일함을 확인했다. `artifacts/typeface-deployment-check.json`에 기록했다.

이는 실제 서체 파일을 포함한 배포 확인이며 브라우저 조작·실기기 IME 검증은 아니다.
한글 111자 개발판이고 나머지는 나눔명조 등으로 표시한다. 기본/기존 선택을 자동
변경하지 않으며 데모를 사용자 영구 저장 검증으로 보고하지 않는다.

## 2026-11-10 · 실제 앱에 쓰는 인간체 개발판 연결

사용자가 실제 적용을 요청해 한글 111자 개발 TTF를 앱에 연결했다. 완성 서체로
표시하지 않으며 `쓰는 인간체 · 개발 중` 선택지와 대체 표시 범위를 명시했다.

변경 파일:

- `assets/fonts/WritingHumanDevelopment-Regular.ttf`, `-info.json`, `-README.md`,
  `pubspec.yaml`: 원래 제작한 0.005 TTF를 실제 앱 family로 등록했다.
  SHA-256은 `eda1b102b1d09cf322fa625bc25f1826333486142b6098570188690a99d83a2e`다.
  문자 114개 중 완성형 한글은 111개다. 편집 원본과 재생성기는 `design/typeface/`다.
- `lib/ui/paper.dart`, `editor.dart`, `tools_screen.dart`, `writing_chrome.dart`,
  `workspace.dart`: 선택 시 본문·브랜드 제목에 실제 서체를 사용하며 미지원
  글자는 NanumMyeongjo → NanumGothic → 플랫폼 글꼴로 보완한다.
  본문은 실제 TextField이며 문자열·selection·composing을 나눠 다시 쓰지 않는다.
- `lib/data/model.dart`, `demo_store.dart`, `lib/main.dart`, `lib/sync/merge.dart`:
  optional bool `useDevelopmentTypeface`를 저장하고 `?demo=typeface` 합성 예시를
  추가했다. 기존 fontIndex 0–2와 DB 버전 3을 유지하며 기존 선택은 자동 변경하지 않는다.
  병합 시 fontIndex와 개발 서체 선택 여부를 한 선택으로 처리한다.
- `server/index.mjs`, `server/sync.test.mjs`, 앱/폰트/영구 저장 검사와 문서.

실행 방법: 일반 주소에서 Aa → 글꼴 → 쓰는 인간체 · 개발 중을 선택한다.
별도의 `?demo=typeface`는 사용자 기록에 쓰지 않는 즉시 확인용 합성 예시다.
`flutter test tool/capture_preview_test.dart --no-pub`로 화면을 다시 렌더한다.

이번 변경 후 검사:

- `dart format --output=none --set-exit-if-changed lib test tool`: 34개 파일,
  변경 없음. `flutter analyze --no-pub`: 문제 없음.
- `flutter test --no-pub`: 33개 통과. 실제 앱 TTF 해시/로드, 지원 글자의 실제
  윤곽 차이, 미지원 `똠뷁힣ABC2026`의 나눔명조와 동일한 픽셀 렌더를 확인했다.
  이는 전체 자형의 미적 완성도를 보증하는 검사는 아니다.
- 실제 SQLite UI 검사는 도구에서 새 서체 선택 → 한글 composing 입력 →
  본문·선택 영역·스크롤 저장 → DB 종료/재열기 후 같은 본문과 새 서체 선택의
  복원을 확인했다. 호스트 SQLite이며 모바일 실제 키보드 테스트는 아니다.
- 한글 조합 중 서체를 바꿔도 같은 TextEditingController와 composing 값이
  유지됐다. 기존 펜 추적·저장 실패·계정 보호 검사도 통과했다.
- 두 SQLite 파일의 동기화 시뮬레이션에서 새 옵션의 수신·영구 저장, 병합 시
  글꼴 선택과 종이 선택의 독립성을 확인했다. 실제 PC/모바일 서비스 검증과 구분한다.
- `npm run test:server`: 3개 통과. optional bool의 구버전 호환·타입 검사 포함.
- 별도 화면 렌더 1개 통과. `artifacts/typeface-live-{blank,selected,writing,
  pen-stroke,keyboard,resting,tools,collection,desktop}.png`를 새 코드로 만들었다.
  실제 번들 TTF를 FontLoader로 읽은 Flutter 테스트 렌더이며 합성 데이터다.
  폰트를 이미지 생성기로 그린 결과나 실기기 캡처로 보고하지 않는다.
- 동일한 `/writing-human/` base href의 웹 release 빌드와 iOS 시뮬레이터 빌드
  성공. release FontManifest의 family 등록과 TTF 바이트가 원본과 일치함을 확인했다.

초기 메타데이터 생성에서 일반 Python 환경에 fontTools가 없어 중단됐으며,
서체용 venv에서 생성한 후 포맷·분석·전체 검사를 다시 실행한 통과 결과만 기록했다.

미검증: 실제 브라우저·iOS/Android IME, 실제 모바일 폰트 판독성, 전체 한글·
자모 조판·숫자·라틴 자형·힌팅·최종 광학 간격. 미지원 글자의 나눔명조 대체를
쓰는 인간체 자체 지원으로 계산하지 않는다. 웹 배포 결과는 후속 배포 항목을 따른다.

## 2026-11-10 · 종이 작성 화면 GitHub Pages 배포 확인

[GitHub Actions 42793174412](https://github.com/namsoon00/writing-human/actions/runs/42793174412)에서
소스 `e9ff3ec2e3499da5fb30091f26ff1f95c26795dc`의 포맷·분석·테스트·웹 빌드와
Pages 배포가 성공했다. 공개 주소는 https://namsoon00.github.io/writing-human/ 이다.

기본/예시 HTML, bootstrap, main JS, 새 잉크 소재, 면지와 나눔명조 7개 요청이
모두 HTTP 200이었다. 제공 main.dart.js의 SHA-256
`64ec5ca456940abbe238e691c472598434001d57518ee0cc495b11958d6232a3`가
로컬의 동일 base href release 빌드와 일치하고 새 잉크 이미지도 소스와 일치했다.
`artifacts/paper-deployment-check.json`에 결과를 보관했다.

이는 새 코드의 배포·파일 검증이며 실제 브라우저 타이핑이나 실기기 IME
검증이 아니다. GitHub Pages는 계속 기기 내 저장용 미리보기이며 기존 Sites의
비공개 project_id/접근 범위를 유지한다. 기록 저장 구조와 키는 변경하지 않았다.
아래의 로컬 구현 단위 기록 이후 이번 원격 배포를 완료했다.

## 2026-11-10 · 개발 계획 첫 구현 단위: 연속된 종이 작성 화면

최신 시안을 실제 Flutter 작성 화면에 반영했다. 이번 단위는 디자인 요소와
작성 화면의 구현이며 백업·복원·설치형 계정 동기화까지 완료한 단계는 아니다.

변경 파일:

- `lib/ui/paper.dart`: 종이 #F7F2E8, 브랜드 잉크 #70472F, 본문 #302C27,
  은은한 면지와 왼쪽 안쪽 음영을 한 장의 정적인 배경으로 통합했다.
- `lib/ui/writing_chrome.dart`: 보관함·브랜드·＋, Aa·저장 상태·더 보기/완료를
  실제 위젯으로 분리했다. 아이콘의 접근성 이름과 터치 영역을 유지한다.
- `lib/ui/workspace.dart`, `editor.dart`, `main.dart`: 본문의 별도 종이 카드와
  금박 식물 표식을 제거하고 브랜드/책 이름을 구분했다. 키보드·작은 화면에서는
  여백을 줄이며, 기존 TextEditingController와 저장·동기화 계층은 유지한다.
  입력 리스너에서 본문·selection·composing을 다시 설정하지 않는다.
- `assets/images/ink-mark.png`: 내장 imagegen으로 최신 시안의 작은 잉크
  자국을 참조해 만든 투명 소재. 원본·프롬프트는 `docs/visual-assets.md`에 기록.
- `test/data/editor_disk_test.dart`, `test/widget_test.dart`,
  `tool/capture_preview_test.dart` 및 제품·구조·소재 문서.

실행 방법:

```sh
# 현재 실행 중인 로컬 미리보기와 같은 빌드/서버
node tool/build_github_pages.mjs /
python3 -m http.server 4186 --bind 127.0.0.1 --directory build/github-pages
# 개발 실행이 필요한 경우
flutter run -d chrome --dart-define=WRITING_HUMAN_LOCAL_ONLY=true
```

`http://127.0.0.1:4186/`은 이 Mac의 로컬 저장용 미리보기다. root base href로
빌드했으며 원격 GitHub Pages나 비공개 Sites 배포를 갱신하지 않았다.
기존 hosting project_id/접근 범위와 사용자 저장 데이터는 수정하지 않았다.

이번 변경 후 실행한 검사:

- `dart format --output=none --set-exit-if-changed lib test tool`: 33개 파일,
  변경 없음. `flutter analyze --no-pub`: 문제 없음.
- `flutter test --no-pub`: 31개 통과. 새 SQLite UI 검사는 새 화면의
  보관함 → 책 만들기 → 한글 composing 값 입력 → 긴 본문 확정 → 선택 영역과
  스크롤 710 저장 → 실제 DB 연결 종료·재열기 → 화면 재생성 흐름을 수행했다.
  본문·책 연결·페이지 ID·선택 영역·스크롤·나눔명조 복원을 확인했다.
  이는 호스트 SQLite 파일과 Flutter 위젯의 결합 검사이며 iOS/Android
  실제 키보드나 프로세스 강제 종료 검사가 아니다.
- 기존 입력·저장 실패·펜 추적 검사와 함께 320×640, 시스템 글자 배율 2,
  280px 키보드 inset에서도 같은 본문 controller와 조작 가능한 영역이
  유지되고 overflow가 없음을 확인했다. 실제 OS 키보드 대신 test input을 사용했다.
- `flutter test tool/capture_preview_test.dart --no-pub`: 1개 통과.
  합성 데이터로 실제 제품 위젯과 번들 나눔 글꼴·종이·잉크 소재를 렌더했다.
- `node tool/build_github_pages.mjs /`: 로컬 저장용 웹 release 빌드 성공.
- `flutter build ios --simulator --no-codesign --no-pub`: 성공.
  `build/ios/iphonesimulator/Runner.app` 생성. 설치·실행·실기기 검증과 구별한다.
- 로컬 HTTP 검사에서 HTML·bootstrap·main JS·잉크/종이/나눔명조 자산 6개가
  모두 200이었다. 제공한 새 잉크 파일의 SHA-256이 소스와 일치했다.
  `artifacts/paper-v1-preview-check.json`에 기록했다. HTTP 검사는 타이핑 검사가 아니다.

화면 확인:

- `artifacts/paper-v1-{blank,writing,pen-stroke,keyboard,resting,tools,collection,desktop}.png`
  8개를 새 코드로 생성하고 직접 확인했다. 모바일 390×844와 데스크톱
  1440×1000 논리 픽셀, PNG는 2배 해상도다. keyboard 화면은
  키보드 높이만 모사한 상태이며 OS 키보드를 그린 캡처가 아니다.
- 실제 컴퓨터/브라우저 실행 확인을 시도했으나 Mac 잠금과 Work 설정의
  로컬 브라우저 비활성화로 접근하지 못했다. 설정 변경이나 다른 UI 제어 수단으로
  우회하지 않았다. 위 PNG는 Flutter 테스트 렌더이며 실제 브라우저·실기기
  실행 화면으로 보고하지 않는다. 이번 결과를 과거 시안 이미지로 대체하지 않았다.

미검증·후속 범위: 실제 iPhone/Android 한국어 IME와 키보드 전환·백그라운드·
강제 종료, Android 빌드, 실제 브라우저 타이핑·새로고침, 설치형 계정 인증과
실제 PC·모바일 양방향 동기화, 백업·복원과 소리. 장문·대량 기록의 저장 성능도
별도 점검이 필요하다. 개발 중인 쓰는 인간체는 제품에 연결하지 않았으며
현재 본문은 나눔명조다. 사용자 글꼴·종이·펜 선택 값과 DB 구조는 유지했다.

## 2026-11-10 · 단순한 UX와 기획 이미지의 룩앤필

- [GitHub Actions 42740934395](https://github.com/namsoon00/writing-human/actions/runs/42740934395)에서 소스 26fedeaabb6dcab65e84db42025a62d2703cd41f의 분석·테스트 30개·빌드·배포가 성공했다. 기본/예시 HTML, 면지/만년필 자산이 HTTP 200이었으며 제공 main.dart.js의 SHA-256 9716d882acb787d86ed3c930c19bea2a87fb9acd2c633df81c3cfa1d78d5441a가 로컬 검증 빌드와 일치했다. writing-surface 표식도 확인했다. artifacts/brand-deployment-check.json에 기록했다. 이는 HTTP/파일 검증이며 실제 브라우저 타이핑 검사로 보고하지 않는다.
- 원본 첨부 브랜드 보드와 새 Flutter 렌더를 비교했다. 종이빛·브라운·그린·포도빛·블루 팔레트, 면지의 결, 가는 종이 끝, 명조 제목과 작은 금박 식물 표식을 적용했다. 바로 쓰는 진입 흐름, 제어 순서, 저장 구조는 바꾸지 않았다.
- dart format lib tool/capture_preview_test.dart, flutter analyze --no-pub 통과. flutter test --no-pub: 이번 변경 후 30개 통과. 첫 한글 입력의 편집기 유지·저장 실패·복원·독립 도구·펜/조합 보호 검사를 포함했다.
- node tool/build_github_pages.mjs /writing-human/: 새 release 웹 빌드 성공.
- flutter test tool/capture_preview_test.dart --no-pub: 렌더 검사 1개 통과. 390×844 및 1440×1000의 새 brand-*.png에서 빈 종이, 작성/펜, 키보드 inset, 도구, 보관함과 넓은 화면을 확인했다. 실제 번들 글꼴/소재와 메모리 예시 데이터의 Flutter 렌더이며 실제 브라우저·실기기 캡처가 아니다.
- 실제 기기의 색 표현·한국어 키보드 및 실제 브라우저 조작은 이번 룩앤필 변경에서도 미검증이다. 완전한 픽셀 일치나 개발 중인 쓰는 인간체 제공을 주장하지 않는다. 웹 빌드/배포 결과는 게시 후 별도로 기록한다.

## 2026-11-10 · 바로 쓰는 종이 UX

- [GitHub Actions 42732777232](https://github.com/namsoon00/writing-human/actions/runs/42732777232)에서 소스 80ddcb5d75e93449a5824e1333c77ebe3dbebe3c의 분석·테스트 30개·release 빌드·Pages 배포가 성공했다. 공개 URL의 기본/예시 HTML, UI 나눔고딕 및 면지 자산이 HTTP 200이었다. 실제 제공 main.dart.js의 SHA-256 905485076443d1c821900ed124f294e6634f97da5f1b8558e0ba8e62f95b9bba가 로컬 검증 빌드와 일치했고 writing-surface 표식, 사진 배경/계정 API 경로 미포함을 확인했다. artifacts/calm-deployment-check.json에 기록했다. 이는 게시·파일 확인이며 실제 브라우저 실행 확인과 구분한다.
- dart format lib test tool/capture_preview_test.dart 및 flutter analyze --no-pub 통과. flutter test --no-pub: 이번 개편 후 30개 통과.
- node tool/build_github_pages.mjs /writing-human/: 새 정적 release 웹 빌드 성공. 실제 공개 URL 배포와 파일 일치는 게시 후 따로 확인한다.
- 첫 진입에서 바로 입력창이 보이고, 열기/포커스만으로는 저장·빈 기록 생성이 발생하지 않는 것을 확인했다. 첫 한글 composing 입력으로 기록을 만들 때 TextEditingController와 TextEditingValue가 그대로인 것을 검사했다. 실제 입력 후에는 자동 저장·다시 열기·마지막 페이지/선택 영역 복원을 확인했다. 위젯의 저장소는 메모리이며 아래 실제 파일 검사와 구분한다.
- 실제 임시 SQLite 파일에서 빈 초안 무생성 → 첫 한글/emoji 기록 저장 → 같은 기록을 새 책에 묶기 → 닫고 새 연결로 재열기 후 ID·본문·선택 영역 보존을 추가 확인했다.
- UI 검사에는 쓰고 나서 새 책으로 묶을 때 빈 기록이 추가되지 않음, 새 종이를 여러 번 열어도 빈 기록이 늘지 않음, 원문을 먼저 저장한 빈 본문 복원, 첫 저장 실패 시에도 같은 편집기와 조합 범위 유지, 한 시트의 독립 도구 설정, 계정 변경/로그인 만료 보호를 포함했다. 실제 PC·모바일 로그인 동기화 검증과 구분한다.
- flutter test tool/capture_preview_test.dart --no-pub: 별도 렌더 확인 1개 통과. 실제 번들 글꼴/소재로 390×844의 빈 종이·작성·펜 반응·가상 키보드 inset·도구 시트·보관함과 1440×1000 작성면을 확인했다. artifacts/calm-*.png는 Flutter 테스트 런타임/메모리 예시 데이터이며, 실제 브라우저나 실제 키보드 캡처가 아니다.
- 컴퓨터가 잠겨 있고 Work의 로컬 브라우저 제어가 비활성화되어 실제 브라우저/실기기 조작과 화면 캡처는 진행하지 못했다. 다른 제어 수단으로 우회하지 않았다. 실제 기기의 키보드·글자 크기·빠른 입력 성능과 사용성 관찰은 미검증이다.

기존 JSON/SQLite 구조와 저장 기록을 보존한다. 새 사용자의 본문은 Regular로 시작하지만, 기존 저장된 글꼴과 이전 JSON의 기본값은 유지한다. 웹 빌드/배포 결과는 아래 후속 기록 및 이번 최종 보고를 따른다.

## 2026-11-10 · 커서를 따라 쓰는 펜

- [GitHub Actions 42729878343](https://github.com/namsoon00/writing-human/actions/runs/42729878343)에서 소스 0ad93baf6e87833bb5893c364499fa79e8a72524의 분석·테스트 25개·웹 빌드·게시가 모두 성공했다. 공개 주소 https://namsoon00.github.io/writing-human/ 의 새 main.dart.js는 로컬 검증 빌드와 SHA-256이 fe9da4ec2b9405f956710505b7731206b00c44128fed9bbcb53cf34680c44cf6으로 일치했다. penMotion·writing-pen 표식, 정적 호스팅의 계정 API 미포함, 기본/예시 HTML 및 만년필 자산 HTTP 200을 확인했다. artifacts/pen-deployment-check.json에 기록했다. HTTP 확인을 실제 브라우저 타이핑 검사라고 보고하지 않는다.
- dart format lib test tool/capture_preview_test.dart 적용 및 변경 없는 형식 검사, flutter analyze --no-pub 통과. flutter test --no-pub: 25개 통과.
- 새 위젯 검사 3개: 실제 RenderEditable 커서와 펜촉 좌표 비교, 입력 직후 중간 프레임의 이동과 최종 정착, 자동 줄바꿈·개행·커서 탭·터치 통과, 한글 composing/emoji TextEditingValue 보존, 선택 영역 시 숨김, 스크롤로 커서가 가려질 때 숨김, 키보드 inset·가로 화면·글꼴/글자 배율 변경, 움직임 끄기와 OS 동작 줄이기를 확인했다. 실제 모바일 키보드 테스트가 아니다.
- 기존 검사에 펜 움직임 설정의 실제 SQLite 파일 닫기/재열기, 예전 JSON의 기본값, 두 SQLite 기기 + 메모리 원격의 설정 병합, 도구 스위치 변경 후 같은 편집 컨트롤러/본문/선택 영역 유지를 추가했다. 이 검사들을 실제 배포 서버·실기기 동기화 검증으로 보고하지 않는다.
- flutter test tool/capture_preview_test.dart --no-pub: 별도 렌더 검사 1개 통과. artifacts/material-pen-follow.png와 material-pen-stroke.png는 새 코드와 실제 번들 폰트/자산으로 만든 Flutter 테스트 런타임 렌더다. 예시 데이터이며 실제 브라우저 캡처가 아니다.
- node tool/build_github_pages.mjs /writing-human/: 새 release 웹 빌드 성공. 배포의 Actions 결과와 공개 주소 점검은 최종 보고 및 후속 기록을 따른다.
- 현재 컴퓨터가 잠겨 있고 로컬 브라우저 제어가 비활성화되어 실제 브라우저·실기기 조작/화면 캡처는 하지 못했다. 우회 수단을 사용하지 않았다. 실기기의 한글 키보드·빠른 입력 지연·긴 문서 프레임 성능은 미검증이다.

추적 펜은 기본 켜짐이며 쓰기 도구 → 펜 → 펜 움직임에서 끈다. 조합 중에는 위치만 표시하고 보간/흔들림을 멈춘다. 쓰기·종이 넘김 소리는 아직 준비 중이다. 본문·selection·composing을 입력 리스너에서 다시 설정하지 않았다.

## 2026-11-10 · GitHub Pages 게시 완료

- 사용자의 Pages 설정 완료 후 API에서 build_type=workflow 및 https://namsoon00.github.io/writing-human/ 주소를 확인했다. 실행 42727457916의 실패 작업을 재실행했고 Configure Pages, Deploy to GitHub Pages가 성공했다. 배포 소스는 bb82d230d576f452ec077189929c968aef512ca4다.
- 해당 소스의 GitHub Actions에서 포맷·flutter analyze·테스트 22개·release 웹 빌드·github-pages 산출물 업로드가 통과했다. 문서 링크 반영만 추가했으므로 앱 검사와 빌드를 불필요하게 반복하지 않았다.
- 실제 공개 URL의 기본/예시 HTML GET 200, base href=/writing-human/ 및 bootstrap 참조를 확인했다. flutter_bootstrap.js, main.dart.js, 나눔명조 Regular, 면지·아이보리 표지·햇빛 배경 HEAD도 모두 200이었다. artifacts/github-pages-deployment-check.json에 결과를 남겼다. 이 결과는 HTTP/배포 확인이며 브라우저 내 실행을 검증한 것은 아니다.
- 실행 주소는 https://namsoon00.github.io/writing-human/ 이며 예시는 ?demo=reference다. GitHub Pages 버전은 브라우저 로컬 저장만 제공한다. 계정 동기화 Sites와 사용자 기록을 공유하지 않는다.
- 미검증: 브라우저 제어가 비활성화되어 실제 브라우저·실기기 조작/화면 캡처는 이번 게시에서도 수행하지 못했다. 과거 캡처를 새 배포의 실행 결과로 재사용하지 않았다.

## 2026-11-10 · GitHub 저장소 업로드 및 원격 검사

- 두 번째 실행 [42727457916](https://github.com/namsoon00/writing-human/actions/runs/42727457916), 소스 bb82d230d576f452ec077189929c968aef512ca4에서 포맷·분석·테스트 22개, Flutter Pages release 웹 빌드와 github-pages 산출물 업로드가 통과했다. Pages 활성화가 되지 않아 실제 웹 게시 확인은 아직 남아 있다. Settings → Pages → Source를 GitHub Actions로 선택하도록 사용자에게 요청했다. 이 상태를 웹 게시 성공으로 안내하지 않는다.
- 사용자가 namsoon00/writing-human Public 저장소를 생성했다. 환경 PAT의 Git 푸시·Pages 설정 요청은 403이었으나 연결된 GitHub 도구의 파일 쓰기는 성공했다.
- 연결 도구로 37개 바이너리의 Git blob SHA와 99개 텍스트를 확인해 총 136개 소스 파일을 업로드했다. 원격 main의 파일 트리와 로컬 스냅샷은 git diff로 동일함을 확인했다. 토큰·사용자 기록·빌드 산출물은 업로드하지 않았다. GitHub 최초 소스 반영 커밋은 183ea5282a0cca9cd5db87bbf6d659214a3d9295다.
- GitHub Actions 실행 42727127765의 Ubuntu runner에서 포맷·flutter analyze·flutter test가 통과했다. 로그의 실제 결과는 No issues found, 22 tests passed였다. Pages API가 Not Found를 반환해 Configure Pages에서 실패했으며, 이 실행을 게시 성공으로 보고하지 않는다.
- 이후 build에서 먼저 웹 산출물을 준비하고 deploy에서 Pages 설정을 조회하도록 순서를 정리했다. Pages 최초 설정 후 실패한 deploy만 재시도할 수 있다. 최종 실행 결과는 이어지는 기록 및 이번 최종 보고를 따른다.
- 브라우저 제어는 계속 비활성화되어 이번에도 실제 브라우저 화면 캡처를 하지 않았다.

## 2026-11-10 · GitHub Pages 배포 준비

- dart format lib test tool/capture_preview_test.dart: 변경 없음. flutter analyze --no-pub: 문제 없음. flutter test --no-pub: 이번 변경 후 22개 통과.
- node tool/build_github_pages.mjs /writing-human/: Flutter release 웹 빌드 성공. 실제 산출물 build/github-pages의 base href, .nojekyll, bootstrap/main JS, CanvasKit, 나눔명조와 새 종이/표지/배경 자산 존재를 확인했다. 컴파일된 JS에 세션·기록 API 및 ChatGPT 로그인 경로 문자열이 없는 것도 검사했다. 정적 검사를 실제 브라우저 실행이라고 보고하지 않는다.
- GitHub Actions YAML은 로컬 파서에서 읽혔고 build/deploy 작업을 확인했다. Node 빌드 스크립트 구문 검사와 git diff --check도 통과했다. 실제 GitHub Actions 실행·업로드·Pages 게시 검증은 아직 하지 못했다.
- GitHub 연결 계정은 namsoon00, 저장소 조회는 404였다. 저장소 생성 요청은 HTTP 403 Resource not accessible by personal access token으로 거절됐다. 브라우저 제어는 비활성화되어 대체 조작도 할 수 없었다. 저장소 생성/접근 권한을 사용자에게 요청했다. 미게시 주소를 운영 링크로 안내하지 않는다.
- 이번 작업에서 실제 브라우저·실기기 화면 캡처는 수행하지 않았다. 과거 UI 캡처를 새 Pages 앱의 실행 결과로 재사용하지 않았다.

기존 Sites의 project_id, 비공개 범위, Worker/D1 배포 산출물은 변경하지 않았다. Pages는 별도의 정적 빌드이며 기기 간 계정 동기화는 제공하지 않는다. 절차는 docs/github-pages.md에 기록했다.

## 2026-11-09 · 종이 질감과 분위기 보강

이번 소재·화면 변경 후 새로 실행한 결과다.

- dart format lib test tool/capture_preview_test.dart 적용 및 변경 없는 형식 검사 통과. flutter analyze --no-pub: 문제 없음.
- flutter test --no-pub: 22개 통과. 한글 조합·선택 영역·스크롤 보존, 저장 오류, 실제 SQLite 파일 재열기와 이전, 독립 도구 설정, 동기화 병합·계정 보호 등의 회귀 검사다. 메모리 원격 어댑터 검사를 실제 서버 동기화로 보고하지 않는다.
- flutter test tool/capture_preview_test.dart --no-pub: 별도 렌더 확인 1개 통과. 실제 번들 글꼴과 이미지로 390×844의 책장·책 상세·필사·글꼴·종이·펜 및 1440×1000의 넓은 화면을 확인했다. Flutter 테스트 런타임이며 예시 데이터다. 사용자 저장소는 열지 않았다.
- artifacts/material-{shelf,book,writing,fonts,paper,pen,desktop}.png는 위 위젯 렌더 결과다. 실제 브라우저나 실기기 실행 화면으로 보고하지 않는다. 테스트 기본 설정에서 생기는 단색 그림자 대신 실제 그림자를 렌더하고, 확인 후 디버그 설정을 복원한다.
- npm run build: Flutter 웹 자산과 기존 동기화 Worker 빌드 성공. 새 면지·아이보리/블루 표지·햇빛 배경을 자산에 포함했다. 기존 project_id, D1 바인딩, 소유자 비공개 접근을 유지해 배포한다.
- 현재 컴퓨터는 잠겨 있고 Work 설정에서 로컬 브라우저 제어도 비활성화되어 실제 앱/브라우저 조작·캡처는 진행하지 못했다. 다른 제어 수단으로 우회하지 않았다.

미검증: 새 소재의 실제 iOS/Android·모바일 브라우저 성능과 한국어 키보드 조작, 실제 PC·모바일 로그인 동기화 전체 흐름. 첨부 이미지의 개발 중 서체를 복제하거나 제공하지 않았으며 실제 나눔명조를 사용한다. 완전한 픽셀 일치 검증은 수행하지 않았다. 배포 완료와 URL은 이번 작업의 Sites 결과 및 최종 보고를 따른다.

## 2026-11-09 · PC·모바일 웹 동기화

이번 변경에서 다시 실행한 결과다. 이전의 화면·테스트 결과로 새 동기화 검증을 대신하지 않았다.

- dart format 적용, flutter analyze --no-pub: 문제 없음.
- flutter test --no-pub: 22개 통과. 기존 기능 외에 두 개의 실제 SQLite 파일을 사용한 기기별 기록·기준 버전 보존, 오프라인 본문 충돌 사본과 수렴, 동시 새 페이지 번호 충돌, 전송 도중 추가 입력, IME와 포커스 보호, 마지막 위치의 반복 덮어쓰기 방지, 명시적 기존 기기 기록 가져오기와 원본 보존, SQLite v2→v3 이전, HTTP 계정 일치 헤더와 세션 변경, 로그인 만료·계정 변경 UI 보호를 확인했다. 이 중 원격 저장소가 메모리인 테스트는 실제 배포 서버 검증과 구분한다.
- Node 서버 테스트 2개 통과. 실제 SQLite 파일 재열기, 계정별 행 분리, 버전 조건부 갱신, 잘못된 구조·출처·계정 변경 요청 거절. Node SQLite 어댑터를 사용했으며 Cloudflare 실서버라고 보고하지 않는다.
- 실제 로컬 Wrangler Worker + D1 HTTP 통합 검사 1개 통과. 독립 HTTP 요청의 같은 합성 계정에서 본문·선택 영역 읽기, 오래된 쓰기 409, 다른 합성 계정의 자료 분리, 위조 사용자 헤더와 다른 출처 요청 거절을 확인했다. 프런트엔드 루트 HTML 응답도 HTTP 200이었다. 실제 브라우저 두 대의 조작은 아니다.
- npm run build: Flutter 웹 자산 + 동기화 Worker 빌드 성공. flutter build ios --simulator --no-codesign --no-pub 성공. iOS 빌드는 설치형 앱의 계정 동기화를 검증한 결과가 아니다.
- 실행 화면: 현재 Work 설정에서 로컬 브라우저 사용이 비활성화되어 이번 버전의 실제 브라우저 조작·캡처는 수행하지 못했다. 다른 브라우저 제어 수단으로 우회하거나 설정을 바꾸지 않았다. artifacts/sync-widget.png는 실제 Flutter 위젯을 테스트 런타임에서 렌더한 미리보기이며, 표시된 계정과 동기화 상태는 합성 데이터다. 실제 브라우저·실서버 화면이라고 보고하지 않는다.
- 배포는 동일한 기존 Sites ID와 비공개 접근을 유지한다. 배포 결과와 개인 기록을 읽지 않는 readiness/정적 자산/인증 거절 점검 결과는 최종 보고 및 artifacts/sync-deployment-check.json을 따른다. 검증용 합성 필사 문장은 로컬 서버에만 썼다.

미검증·미구현: 실제 PC·모바일 브라우저의 ChatGPT 로그인 후 양방향 조작, 실제 한국어 키보드 및 강제 종료, 큰 계정 기록의 장기 부하. 설치형 iOS·Android 앱의 계정 인증은 아직 연결하지 않았으며 로컬 저장을 유지한다. 백업 파일 내보내기와 펜 반응·소리도 후속 범위다. 서버 스냅샷 요청은 2 MiB까지이며 초과 시 로컬 원본을 보존하고 오류를 표시한다.

## 2026-11-09 · 첨부 이미지 UI 개편

이번 변경에서 다시 실행한 결과다. 이전 검증을 새 버전 결과로 대신하지 않았다.

- dart format: 적용. flutter analyze --no-pub: 문제 없음.
- flutter test --no-pub: 10개 통과. 초기 저장/복원·IME·오류 처리 7개와 함께 실제 SQLite v1→v2 이전 후 본문·커서·스크롤 보존, 종이/펜/글꼴/즐겨찾기/원문 재열기, 이전 웹 JSON 호환, 도구 선택 시 기존 편집 컨트롤러·본문·선택 영역 유지 항목을 검증했다. 기존 좁은 화면 테스트에는 844×390 가로 화면도 추가했다.
- 웹의 예시 책장은 사용자 저장소와 분리된 메모리 저장소다. 표지/문장/쪽수는 첨부 이미지 외관을 확인하는 예시이며 사용자의 실제 기록이라고 표시하지 않는다.
- 실제 브라우저에서 이전 버전 localStorage의 책 1권과 2개 페이지가 그대로 보이는 것을 확인했다. 새 검증 노트를 만든 뒤 한글 본문 작성 → 나눔고딕 선택 → 미색지 선택 → 블루 잉크 선택 → 새로고침을 수행했고 본문, 종이빛, 잉크빛, 글꼴, 마지막 페이지와 저장됨 표시가 복원됐다. 이 데이터는 localhost에만 존재한다.
- 390×844 실제 브라우저에서 책장·책 상세·필사·종이·글꼴 5개 화면을 확인했고 최종 5개 캡처를 나란히 합친 artifacts/reference-overview.jpg를 만들었다. 캡처를 새로 그리거나 앱 목업으로 대체하지 않았다.
- 실제 화면 캡처는 artifacts/reference-*.jpg, 저장 복원 확인은 artifacts/redesign-persistence.jpg에 보관한다. 예시 캡처와 실제 저장 검증 캡처를 구분한다.
- 새 버전 flutter build web --release --no-wasm-dry-run --no-web-resources-cdn --output dist --no-pub 및 flutter build ios --simulator --no-codesign --no-pub 성공. 실기기 실행과 구별한다. 비공개 Sites 배포 결과는 최종 보고를 따른다. 배포용 소스와 정적 출력은 같은 커밋으로 패키징한다.

미검증: 실제 iOS/Android 한글 키보드, 실제 모바일 브라우저, 모바일 프로세스 강제 종료·재시작, 스토리지 할당량과 대용량 성능. 펜 반응·소리와 백업·복원은 아직 구현하지 않았다. ‘쓰는 인간체’는 개발 중인 잠금 항목이며 실제 폰트로 제공하지 않는다.

---

## 초기 구현 때의 기록 (아래는 이전 결과)


2026-11-09. 이 저장소에서 새로 실행한 결과만 기록했다. 기존 프로토타입의 테스트 결과는 사용하지 않았다.

## 통과

- Flutter 3.41.2 / Dart 3.11.0, macOS 26.6.2.
- flutter analyze --no-pub: No issues found.
- flutter test --no-pub: 7개 통과.
  - 실제 임시 SQLite 파일에 책·기록·2개 페이지 저장 → 연결 종료 → 새 연결로 열기. 한글·emoji·빈 본문 덮어쓰기·마지막 페이지·선택 영역·스크롤 326.5 복원.
  - 책 없는 기록을 기존 책에 묶은 뒤 페이지 ID와 본문 유지.
  - 지원하지 않는 버전·손상 JSON·잘못된 활성 페이지 거부.
  - 위젯에서 책 만들기 → 한글 composing 값 전달 → 조합 영역 변형 없음 → 선택 영역과 본문 저장 → 위젯 재생성으로 복원. 이 테스트의 저장소는 메모리이며 실제 기기 키보드 테스트가 아니다.
  - 저장 실패 표시 → 재시도로 최신 본문 저장. 메모리 저장소의 오류 주입 테스트.
  - 390×844 화면에서 긴 본문 스크롤 340→710 저장 및 위젯 재생성 후 710 복원. 320 높이의 키보드 inset을 주어 overflow 없음.
  - 읽기 실패 시 복구 화면을 표시하고 저장을 시도하지 않음.
- flutter build web --release --no-wasm-dry-run --no-web-resources-cdn --output dist --no-pub: 성공.
- 정적 서버 http://127.0.0.1:4173 HTTP 200.
- 브라우저 실제 조작: 빈 책장 → 책 생성 → 한글 본문 입력 → 저장됨 → 새로고침 후 같은 본문 표시. 두 번째 페이지에 긴 한글 본문 입력 → 하단 스크롤 → 새로고침 후 2/2 페이지와 화면에 보이는 28~35행 위치 유지.
- 브라우저 390×844에서 필사 화면과 책장 전환 확인. 데스크톱에서는 1280×720으로 확인.
- 실제 실행 화면은 artifacts/editor-desktop.jpg, artifacts/editor-mobile.jpg, artifacts/scroll-before-reload.jpg, artifacts/scroll-after-reload.jpg에 보관한다. 사용자 기록과 함께 커밋하지 않는다. 캡처의 문장은 검증을 위해 직접 입력한 문장이다.

## 빌드/배포 진행 상태

- flutter build ios --simulator --no-codesign --no-pub: 성공. build/ios/iphonesimulator/Runner.app 생성. 실기기 실행 검증과 구별한다.
- 비공개 웹 배포의 완료 여부와 URL은 이번 작업 최종 보고 및 Sites 배포 결과를 따른다. 소스와 정적 빌드는 같은 Git 커밋으로 패키징한다.
- GitHub 새 저장소 생성: 토큰에 repository 생성 권한이 없어 HTTP 403 Resource not accessible by personal access token. 브라우저는 로그인 화면. 로컬 Git과 Sites 비공개 소스 저장소는 GitHub와 구별한다.

## 미검증 또는 후속 범위

- 실제 iPhone·Android의 한국어 IME, 받침 수정·빠른 연속 입력·선택 편집·백그라운드 전환·강제 종료.
- Android SDK 라이선스 일부 미동의 상태로 Android 빌드/실기기 테스트를 진행하지 않았다. 약관 자동 동의는 하지 않았다.
- Safari·Firefox, 실제 모바일 브라우저 및 시크릿 모드, 웹 저장 할당량 초과의 실제 재현, 여러 탭 충돌, 대용량 라이브러리 성능.
- 모바일 프로세스를 실제 종료·재실행한 전체 E2E 검증. SQLite 파일 재열기 테스트 및 브라우저 새로고침과 구분한다.
- 종이·펜·글꼴 선택, 백업·복원, 소리·펜 반응, 설치형 오프라인 웹 캐시는 아직 구현하지 않았다.

## 2026-11-11 · 한 쪽에 여러 구절 쓰기

- Flutter 3.41.2 격리 체크아웃에서 전체 Dart 포맷 검사(71개 파일), `flutter analyze --no-pub`, `flutter test --no-pub`(96개), `node --test server/sync.test.mjs`(8개)를 통과했다.
- Flutter 위젯 테스트에서 빈 줄 터치 → 여백의 추가 버튼 → 원문·출처 입력 → 같은 쪽 저장, 쓰는 위치에 따른 원문 열기, 원문을 닫은 뒤 입력기와 선택 영역 유지, 마지막 줄에서 다음 쪽을 열고 남은 원문 이어 쓰기를 확인했다. 한글 조합 중 원문 진입 차단과 기존 본문·스크롤 보존도 확인했다.
- 호스트의 실제 SQLite 파일로 v4 데이터를 v8로 이전하고 본문을 보존한 뒤 구절 원문·출처를 저장하고 파일을 다시 열었다.
- `node tool/build_github_pages.mjs /writing-human/`로 같은 Flutter 코드의 웹 release 빌드를 생성했다. 기존 비공개 Sites 설정은 그대로 유지했다.
- Chrome 390×844 터치 에뮬레이션의 release 빌드에서 짧은 글에 다음 쪽 버튼이 숨는 것, 같은 쪽에 둘째 구절 추가, 전체 화면 원문 문단 이동, 새로고침 뒤 브라우저 localStorage 복원을 확인했다. 확인에는 합성 기록을 사용했다.
- iOS·Android 실기기 키보드와 설치형 앱의 저장 동작, 비공개 Sites 환경의 D1 동기화는 이번 변경에서 검증하지 않았다.

## 2026-11-11 · 책에 원문을 등록하고 종이에서 바로 쓰기

- Flutter 3.41.2 격리 체크아웃에서 Dart 포맷 검사(72개 파일), 정적 분석, Flutter 테스트 95개, 원문 화면 캡처 테스트 1개, 서버 테스트 9개, 웹 release 빌드를 완료했다.
- 위젯 테스트에서 한 책에 원문 두 개를 등록하고 다른 필사에 이어서 사용했다. 다른 책의 원문 제외, 중복 일치 대기, 원문 중간 일치, 한글 조합 상태 유지, 패널 닫기 뒤 입력기·커서·스크롤 보존을 확인했다. 구절에 붙였던 원문과 출처만 적어 둔 항목도 원문 목록에서 확인했다.
- 호스트 실제 SQLite 파일로 v4 → v9 이전과 기존 본문·구절 메타데이터를 확인하고, 책과 책 없는 기록의 원문을 저장해 재열었다. Flutter 입력기와 호스트 SQLite를 결합한 테스트에서도 책 원문을 등록하고 파일을 다시 열었다. 동기화 단위 테스트는 두 기기에 등록한 원문을 모두 보존했다.
- Chrome 390×844 터치 에뮬레이션에서 배포용 release로 책 상세 원문 등록, 본문 입력, 일치한 원문 패널 열기, 닫은 뒤 커서 유지, 새로고침 뒤 원문과 본문 복원을 확인했다. 확인에는 합성 기록을 사용했다.
- iOS·Android 실기기 키보드와 설치형 앱, 비공개 Sites의 D1 동기화는 이번 변경에서 검증하지 않았다. 기존 비공개 호스팅 설정을 유지했다.
- 원문 버튼으로 포커스가 먼저 이동하는 경우를 위젯 테스트에 추가했다. 패널을 닫으면 쓰던 입력기가 키보드 입력을 다시 받고 같은 커서 위치에서 이어 쓴다.

## 2026-11-11 · 하단 원문 등록과 한 단어부터 밑글씨

- Flutter 3.41.2 격리 체크아웃에서 Dart 포맷 검사(72개 파일), 정적 분석, Flutter 테스트 96개, 원문 화면 캡처 테스트 1개를 통과했다.
- 책에 원문이 없을 때 하단 버튼으로 등록 화면에 바로 들어갔다. 원문이 있는 경우에는 일치한 대목을 읽는 패널에서 원문을 추가했다. 같은 책의 등록 목록과 쓰던 본문·커서가 보존됐고, 패널을 닫은 직후 입력을 이어 갔다.
- 단어 전체가 원문의 한 곳과 일치하면 이어지는 밑글씨를 계산했다. 단어 일부, 한 원문 안의 반복, 여러 원문의 중복, 한 글자로 된 온전한 단어를 각각 검사했다. 한글 조합·사진 등록·공유 수신의 기존 검사도 통과했다.
- iOS·Android 실기기와 비공개 Sites 배포는 이번 검증 범위에 포함하지 않았다.

## 2026-11-11 · 원문 여백의 연필 메모

- Flutter 3.41.2 격리 체크아웃에서 Dart 포맷 검사(71개 파일), 정적 분석, Flutter 테스트 98개, 서버 테스트 9개를 통과했다.
- 원문 패널에서 밑줄을 남기고 메모를 작성·수정했다. 한글 조합이 진행 중이면 저장을 쉬고, 저장 실패 뒤 입력을 유지해 재시도했다. 저장 뒤 원래 편집기·선택 위치·입력 연결을 복원했다. 작은 화면과 키보드 높이 조건도 Flutter 위젯으로 검사했다.
- 호스트 실제 SQLite 파일을 v4에서 v9로 이전한 뒤 원문의 메모와 밑줄을 저장하고 다시 열었다. 이전 필사 본문과 줄별 원문·출처도 보존했다. 동기화 단위 테스트는 한 메모의 양쪽 동시 수정 내용을 보존했다.
- iOS·Android 실기기 입력, 비공개 Sites의 실제 동기화는 검증하지 않았다. 기존 비공개 호스팅 설정을 유지했다.
- 웹 release 빌드를 만들고 Chrome 390×844 터치 에뮬레이션에서 메모 작성·저장, 필사 입력 재개, 새로고침 뒤 원문과 메모 복원을 합성 기록으로 확인했다. 작성 중과 저장 후 화면을 캡처했다.

## 2026-11-11 · 원문 쪽지 목록과 노트 여백의 느낀 점

- Flutter 3.41.2 격리 체크아웃에서 Dart 포맷 검사(71개 파일), 정적 분석과 Flutter 테스트 99개를 통과했다.
- 같은 책의 원문 두 개에서 각각 쪽지 모양과 색을 적용하고 사이의 구분표 한 개를 확인했다. 원문 읽기에는 책의 종이 색·결·제본과 글꼴, 연필 겹밑줄과 색을 확인했다. 원문 미리보기의 줄바꿈을 정리한 뒤에도 펼친 원문 본문은 보존했다.
- 노트에서 메모 편집을 바로 열고, 조합 중 저장 차단과 실패 후 재시도, 저장 뒤 본문 입력기와 커서 유지, 이전 줄의 메모 표시를 확인했다. 노트와 원문에서 같은 메모를 쓰고 고쳤다.
- iOS·Android 실기기 입력과 비공개 Sites 환경은 이번 검증 범위에 포함하지 않았다.

## 2026-11-11 · 필사 줄 아래에 붙는 손글씨 메모

- Flutter 3.41.2 격리 체크아웃에서 Dart 포맷 검사(73개 파일), 정적 분석과 Flutter 테스트 100개를 통과했다.
- 저장된 원문 밑줄을 필사 본문의 위치로 연결했다. 위젯 테스트에서 해당 줄 바로 아래에 메모가 나타나고, 스크롤을 따라 이동하며, 기준 줄이 화면을 벗어나면 숨는 것을 확인했다. 다음 줄의 본문과 겹칠 때는 같은 줄 옆의 연필 표시를 확인했다.
- 노트의 메모를 열어 한글을 조합하는 동안 저장을 차단했다. 저장 실패 후 입력을 보존해 재시도했고, 저장 뒤 원래 입력기와 선택 영역을 복원했다. 본문 및 편집기 크기와 이전 원문 메모를 보존했다.
- iOS·Android 실기기 입력과 비공개 Sites 환경은 이번 검증 범위에 포함하지 않았다.

## 2026-11-13 · 또렷한 입력 위치

- Flutter 3.41.2 격리 체크아웃에서 Dart 포맷 검사(73개 파일), 정적 분석과 Flutter 테스트 100개를 통과했다.
- 입력 위치를 읽어 펜 색의 불투명한 6px 점으로 표시한다. 위젯 테스트에서 입력을 멈춰도 크기와 색의 농도를 유지하고, 줄바꿈·커서 이동·스크롤·키보드 높이·글자 크기 변경을 따라가는 것을 확인했다. 잉크 반응 끄기와 동작 줄이기에서도 점을 유지하고 글자 효과를 쉬었다. 선택 영역과 한글 조합 값도 보존했다.
- 웹 release 빌드를 만들었다. iOS·Android 실기기 입력과 비공개 Sites 환경은 이번 검증 범위에 포함하지 않았다.
- Chrome 390×844 터치 에뮬레이션에서 합성 기록으로 같은 글·펜·종이를 사용해 이전 공개 버전과 새 release를 캡처했다. 1.3초 멈춘 뒤에도 일반·잉크 반응 끄기·동작 줄이기 세 경우 모두 같은 색의 점을 확인했다. 종이를 눌렀을 때 커서가 이동하고 본문은 보존됐다.
