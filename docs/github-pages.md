# GitHub Pages 배포

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

- [GitHub Pages 정적 호스팅과 사용 조건](https://docs.github.com/en/pages/getting-started-with-github-pages/what-is-github-pages)
- [GitHub Pages 사용자 지정 워크플로](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages)
- [Flutter 웹 빌드](https://docs.flutter.dev/deployment/web)
- [Flutter 하위 경로 base href](https://docs.flutter.dev/ui/navigation/url-strategies)
