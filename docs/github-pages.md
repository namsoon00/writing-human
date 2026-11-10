# GitHub Pages 배포

## 2026-11-10 · 쪽수와 종이 스와이프

[Actions 42823317701](https://github.com/namsoon00/writing-human/actions/runs/42823317701),
소스 `9d7826efa7b69e9f4522b48b47e5c4cde91cc602`의 검사·빌드·배포가 성공했다.
하단 이전/다음/추가 버튼을 제거하고 작은 쪽수와 좌우 넘김으로 바꿨다.
읽는 상태에서는 종이 위를, 입력 중에는 쪽수 영역을 넘긴다. 마지막 쪽의 다음
넘김은 새 빈 쪽을 보관한다. 공개 JS·서체·아이콘이 로컬 release와 일치했다.
실제 브라우저/기기 검증 범위는 docs/verification.md를 따른다.

## 2026-11-10 · 전체 화면 종이 넘김

[Actions 42802397738](https://github.com/namsoon00/writing-human/actions/runs/42802397738)의
소스 `bcafc0ee6791138081e661252d4078ecf25c1949`에서 검사·빌드·배포가 성공했다.
상단 브랜드·본문·하단 도구 전체에 종이 넘김을 적용했다. 공개 JS와 clean release
빌드의 바이트 일치도 확인했다. 실제 브라우저/기기 검증 범위는 docs/verification.md를 따른다.

## 2026-11-10 · 페이지 넘김 배포

[Actions 42800541152](https://github.com/namsoon00/writing-human/actions/runs/42800541152),
소스 `212458ed3618434b034eed34163fc258f90b0543`의 검사·빌드·배포가 성공했다.
하단의 페이지 추가·이전/다음과 쪽수 미리보기 선택에 종이 넘김이 적용됐다.
[두 쪽 예시](https://namsoon00.github.io/writing-human/?demo=typeface)는 비영구 데이터다.
실제 기록은 기본 주소에서 쓴다. 제공 JS·서체·아이콘이 로컬 release와 일치했다.
실제 브라우저/실기기 검증 범위는 docs/verification.md를 따른다.

## 준비된 구성

- `.github/workflows/github-pages.yml`: main push 또는 수동 실행 → Flutter 3.41.2 설정 → 포맷·분석·테스트 → 프로젝트 경로에 맞춘 웹 빌드 → Pages 배포.
- `tool/build_github_pages.mjs`: `build/github-pages`에 정적 자산과 `.nojekyll`을 만든다. `/writing-human/` 같은 base href를 검증한다. 기존 Sites용 `dist`와 `.openai/hosting.json`은 건드리지 않는다.
- `WRITING_HUMAN_LOCAL_ONLY=true`: 브라우저 localStorage를 사용하고 세션 조회·서버 동기화·ChatGPT 로그인 경로를 생성하지 않는다. 쓰기와 복원 동작은 같은 Flutter UI다.
- Pages는 정적 호스팅이다. 서버가 필요한 기존 D1·계정 동기화는 소유자 비공개 Sites에서 계속 제공한다. GitHub Pages와 Sites는 서로 다른 origin이므로 저장 기록이 자동으로 이동하지 않는다.

## 저장소 연결 후

1. GitHub에 빈 `writing-human` 저장소를 만든다. GitHub Free에서는 Pages에 Public 저장소가 필요하고, Pro 등 지원 요금제는 Private도 가능하다.
2. 이 체크아웃의 main을 해당 저장소에 푸시한다. 공개 저장소에 올리는 파일에 자격 증명·기록·실행 산출물은 포함하지 않는다.
3. 저장소 Settings → Pages → Build and deployment → Source를 **GitHub Actions**로 설정한다.
4. Actions에서 **Deploy Flutter to GitHub Pages**를 실행하고 성공한 deployment의 URL을 확인한다. 저장소가 `namsoon00/writing-human`이면 주소 형식은 `https://namsoon00.github.io/writing-human/`다. 실제 배포 성공 전에는 운영 주소로 안내하지 않는다.
5. 앱 외관 예시는 위 주소에 `?demo=reference`를 붙여 확인한다. 기본 주소는 실제 기기 저장용 빈 책장부터 시작한다.

## 2026-11-10의 저장소 연결

사용자가 Public 저장소 [namsoon00/writing-human](https://github.com/namsoon00/writing-human)을 생성했다. 원래 환경의 PAT를 이용한 일반 Git 푸시는 403으로 거절됐으나, 연결된 GitHub 도구로 파일 쓰기는 성공했다. 해당 도구를 통해 폰트·이미지의 Git blob SHA와 소스 트리를 확인해 업로드한다. 저장소에 자격 증명·사용자 기록·로컬 실행 산출물은 포함하지 않는다.

연결 도구에는 Pages 설정 변경 기능이 없고 환경 PAT의 Pages 생성 요청도 403이어서, 사용자가 Settings → Pages → Source를 GitHub Actions로 설정했다. Pages API에서 build_type=workflow를 확인한 뒤 실패 작업을 재실행했다. 실행 [42727457916](https://github.com/namsoon00/writing-human/actions/runs/42727457916)의 배포가 성공했다.

운영 주소: [웹 앱](https://namsoon00.github.io/writing-human/) · [예시 책장](https://namsoon00.github.io/writing-human/?demo=reference). 실제 URL에서 HTML, bootstrap/main JS, 나눔명조 및 질감 자산의 HTTP 200 응답을 확인했다. 실제 브라우저 화면·실기기 조작 검증과는 구별하며 세부 결과는 docs/verification.md를 따른다.

## 근거 문서

개발 서체 적용 버전은 `?demo=typeface`로 즉시 확인할 수 있는 합성 예시를
제공한다. 일반 주소의 실제 기록·제목·메뉴·보관함·도구에 쓰는 인간체를 기본 적용한다.
이전 설정은 한 번 전환하고 이후 선택한 본문 글꼴은 보존한다. 미지원 글자는 나눔명조 등으로 보완한다.
현재 0.006은 현대 한글 11,172자·자모·영문·숫자를 지원하는 개발판이다. 최종 광학·실기기 검수 전에는 완성 서체로 표시하지 않는다.

- [GitHub Pages 정적 호스팅과 사용 조건](https://docs.github.com/en/pages/getting-started-with-github-pages/what-is-github-pages)
- [GitHub Pages 사용자 지정 워크플로](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages)
- [Flutter 웹 빌드](https://docs.flutter.dev/deployment/web)
- [Flutter 하위 경로 base href](https://docs.flutter.dev/ui/navigation/url-strategies)

## 2026-11-10 · 연속된 종이 작성 화면 배포

[Actions 42793174412](https://github.com/namsoon00/writing-human/actions/runs/42793174412)의
소스 e9ff3ec2e3499da5fb30091f26ff1f95c26795dc에서 포맷·분석·테스트·빌드·배포가
모두 성공했다. 새 작성 화면, 번짐 잉크 표식, 최소 조작부가 같은 공개 주소에
반영됐다. 실행 JS가 로컬 release 빌드와 정확히 일치하고 잉크·종이·서체 자산의
HTTP 200을 확인했다. 검증 범위와 한계는 docs/verification.md를 따른다.

## 2026-11-10 · 개발 서체 포함 배포

[Actions 42795999490](https://github.com/namsoon00/writing-human/actions/runs/42795999490)에서
소스 28884e22f860c815722c0b6a52712e6b8698a6bf의 분석·테스트·빌드·배포가 성공했다.
[새 서체 예시](https://namsoon00.github.io/writing-human/?demo=typeface)는 합성 데이터다.
실제 기록에는 Aa → 글꼴 → 쓰는 인간체 · 개발 중을 선택한다. 한글 111자
개발 TTF가 제공되고 미지원 문자는 나눔명조로 보완된다. 원격 실행 JS와 TTF가
로컬 검증 파일과 정확히 일치함을 확인했으며 실기기 검증과 구분한다.

## 2026-11-10 · 전체 한글 개발판 0.006 게시

[Actions 42799991684](https://github.com/namsoon00/writing-human/actions/runs/42799991684)의
소스 `9150f6f1d1a5db7832682e9d01450bb9fa4664a5`에서 검사·빌드·게시가 성공했다.
현대 한글 11,172자·자모·영문·숫자를 지원하는 새 실제 TTF가 기존 주소에 반영됐다.
[즉시 확인용 합성 예시](https://namsoon00.github.io/writing-human/?demo=typeface) 또는
웹 앱의 Aa → 글꼴 → 쓰는 인간체 · 개발 중에서 확인한다.
실제 제공되는 TTF·메타데이터·main JS가 로컬 release와 일치했으며 상세 검증은
`docs/verification.md`에 있다. 실제 브라우저/실기기 타이핑 검증과는 구분한다.

## 2026-11-10 · 일반 화면 전체 기본 서체 게시

[Actions 42804908393](https://github.com/namsoon00/writing-human/actions/runs/42804908393),
소스 `79a3c989606d2f89f1c5cde8dfe40961390dd576`에서 검사·빌드·게시가 성공했다.
[일반 웹 주소](https://namsoon00.github.io/writing-human/)의 본문·기존 페이지·제목·메뉴·
보관함·도구·대화상자에 쓰는 인간체를 기본 적용한다. 예시 화면이나 최초 선택이 필요하지 않다.
기존 설정은 한 번 전환하고 이후 사용자가 고른 다른 본문 글꼴은 보존한다.
실제 실행 JS와 전체 한글 TTF가 검증한 로컬 release와 같음을 확인했다.
초기 Pages 동기화 시간 초과와 새 버전 재게시, 검증 범위는 docs/verification.md에 기록했다.
