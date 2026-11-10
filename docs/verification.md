# 검증 기록

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
