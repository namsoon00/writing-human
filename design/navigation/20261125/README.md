# 전체 화면 이동 시안 · 2026-11-25

[동선 기준과 화면 표](../../../docs/navigation.md)를 대표 화면 네 개로 보여 주는
생성 이미지다. 기존 쓰는 쪽/도구의 실제 캡처를 스타일 참고로 사용한다.
코드 구현·실제 앱 캡처·제스처 작동 검증·배포 결과가 아니다.

- 시안: `navigation-concept-v2.png`
- 원문 프롬프트: `generation-prompt.txt`
- 생성 방식: built-in image_gen, ui-mockup
- 참고: `output/daily-review-20261125/01-writing-after-launch.png`,
  `output/tools-eraser-top-20261121/pen-390.png`

세부 동작과 접근성·저장/이탈 정책은 이미지보다 동선 문서를 기준으로 검토한다.
시안의 서체는 생성 표현이며 실제 번들 글꼴 렌더 검증이 아니다.

최종본은 `navigation-concept-v2.png`다. 첫 생성에서 종이 화면에 붙은 불필요한
뒤로 제스처 주석을 `edit-prompt.txt`로 제거했다. 네 화면과 복귀 목적지·도구 패널을
직접 확인했다. 제스처 작동과 터치 크기는 생성 이미지로 검증하지 않았다.

사용자의 후속 구현 지시 뒤 공통 이동을 앱 코드에 연결했다. 현재 구현과 실제 검증은
[전체 동선](../../../docs/navigation.md) 및 [검증 기록](../../../docs/verification.md)을 따른다.
이 이미지 자체는 계속 생성 시안이며 실제 앱 캡처로 바꾸어 소개하지 않는다.
