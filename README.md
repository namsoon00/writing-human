# 쓰는 인간 · writing-human

내 취향으로 쓰고, 한 권으로 남기는 즐거움.

Flutter로 만든 타이핑 전용 필사 앱. iOS·Android 대상이며 같은 코드를 웹 미리보기로 제공한다. 책 만들기, 책 상세, 필사 작성, 원문 메모, 페이지 추가/이동, 로컬 자동 저장, 마지막 본문·페이지·선택 영역·스크롤 복원. 종이·펜·글꼴을 독립적으로 선택하고 줄 가이드와 즐겨찾기를 사용할 수 있다. 책 없이 쓰기와 기존 책에 묶기도 가능하다.

[웹 앱 열기](https://namsoon00.github.io/writing-human/) · [참조 이미지의 예시 책장](https://namsoon00.github.io/writing-human/?demo=reference)

GitHub Pages는 로그인 없이 열 수 있으며 이 브라우저에 기록을 저장한다. 예시 책장은 사용자 저장소와 분리된 비영구 미리보기다. ‘내 책장’을 누르면 실제 기록으로 돌아간다.

[계정 동기화 버전](https://writing-human.giving-box-8515.chatgpt.site)은 소유자 ChatGPT 로그인으로 접근하는 별도의 비공개 Sites다. 두 주소의 기록 저장 위치는 다르다.

## 실행

Flutter 3.41.2 / Dart 3.11.0에서 확인했다.

```sh
flutter pub get
flutter devices
flutter run -d chrome
# iOS Simulator를 실행한 상태에서:
flutter run -d <device-id>
# Android 환경과 SDK 라이선스 준비 후:
flutter run -d <android-device-id>
```

## PC·모바일 웹 동기화 개발 실행

```sh
npm ci
npm run db:local
npm run build
npm run dev
```

http://127.0.0.1:4173 에서 사용한다. 로컬 로그인은 개발용 합성 계정이며 실제 배포의 ChatGPT 로그인과 다르다. `flutter run -d chrome`만 실행하면 UI 전용 미리보기이며 동기화 서버는 포함하지 않는다.

## GitHub Pages 미리보기

```sh
flutter pub get
node tool/build_github_pages.mjs /writing-human/
```

출력은 `build/github-pages`다. `.github/workflows/github-pages.yml`은 main에 푸시하면 검사·빌드 후 Pages에 배포한다. 저장소의 Settings → Pages → Source를 GitHub Actions로 설정해야 한다. 다른 저장소 이름은 Actions의 GITHUB_REPOSITORY 값으로 자동 적용한다. Pages가 아직 활성화되지 않아도 build 작업은 산출물을 업로드하고, 설정을 마친 후 deploy 작업만 재시도할 수 있다.

GitHub Pages 버전은 실제 브라우저 로컬 저장만 제공하며 계정 로그인·기기 간 동기화를 요청하지 않는다. 기존 Sites의 동기화 버전과 기록 저장 위치가 다르다. 예시 화면은 배포 주소 뒤에 `?demo=reference`를 붙여 연다. 설정과 배포 상태는 [GitHub Pages 배포 문서](docs/github-pages.md)를 따른다.

## 검사

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
# 예시 데이터로 Flutter 위젯 화면 캡처 (브라우저·실기기 검증과 구별):
flutter test tool/capture_preview_test.dart --no-pub
npm run test:server
npm run build
# npm run dev 실행 후:
node --test server/http.integration.mjs
```

빌드는 dist/client의 Flutter 정적 리소스와 dist/server의 동기화 Worker를 만든다. 웹을 완전한 오프라인 PWA로 설치·캐시하는 기능은 아직 제공하지 않는다.

## 데이터

설치형 앱은 SQLite의 writing-human-v1.db 파일에 보관한다. 웹은 기기·계정별 localStorage에 먼저 보관하고 같은 ChatGPT 계정의 PC·모바일 브라우저와 동기화한다. 기존 익명 기기 기록은 구름 버튼의 ‘이 기기 기록 가져오기’로 합친다. 설치형 앱 계정 인증은 아직 연결하지 않았다. 배포 서버와 localhost는 서로 다른 데이터베이스다. 자동 저장 실패는 재시도하고, 기기 저장과 서버 동기화 상태를 구분해서 확인한다. 백업·복원은 후속 구현이다.

## 문서

- [제품 원칙과 후속 단계](docs/product.md)
- [구현 구조와 저장 한계](docs/architecture.md)
- [PC·모바일 동기화와 충돌 처리](docs/sync.md)
- [이번 앱의 검증 기록](docs/verification.md)
- [화면 소재와 생성 프롬프트](docs/visual-assets.md)
- [폰트 라이선스](assets/fonts/OFL.txt): Google Fonts가 배포하는 Nanum Myeongjo Regular. ‘쓰는 인간체’가 아니다.

Git 기본 브랜치는 main이다. 소스 저장소는 [namsoon00/writing-human](https://github.com/namsoon00/writing-human)이다. GitHub Pages 배포는 위 워크플로를 사용하며 진행 상태는 저장소의 Actions에서 확인한다. 기존 Sites 배포용 비공개 소스 Git도 유지한다.
