# 검증 기록

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
