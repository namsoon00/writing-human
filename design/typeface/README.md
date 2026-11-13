# 쓰는 인간체 · 전체 문자 개발판 0.008

0.008은 겹받침의 두 자음 사이를 벌리고 획이 많은 받침의 안쪽 여백을 넓힌다.
영문 대문자와 숫자의 윤곽 높이는 7%, 소문자는 3% 낮춰 한글과 섞인 줄을 다듬었다.
`source/reading-v008.json`에 조정값을 두며, 지원 문자와 자모 조판, 글꼴의 글자 폭은
유지한다. 앱의 필사 본문과 해당 미리보기는 쓰는 인간체의 자간을 조금 좁혀 표시한다.


현대 한글 11,172자·호환 자모 51자·현대 조합 자모 67자·ASCII 95자와
추가 문장부호를 직접 작성한 벡터 원본에서 생성한다. 앱의 기존 개발판 선택에
연결했으며 기본 나눔명조와 저장된 선택을 유지한다. 최종 광학·실기기 검수는 남아 있다.

- `build_typeface.py`: 전체 범위 TTF, 공유 자모, OpenType ccmp와 영문 커닝.
- `source/latin-v006.json`: 직접 작성한 영문·숫자·ASCII 원본 및 24쌍 커닝.
- `release/`: 현재 TTF와 지원 범위·원본 해시 매니페스트.
- `audit_typeface.py`: 전 글자 경계·중복 윤곽·완성형/분해형 조판 검사.
- `render_review.py`: 실제 TTF의 FreeType 견본과 한글 전체 19장 도판.
- `../../tool/render_full_typeface_test.dart`: Flutter 14·18·23·32·42px 렌더.

실행 방법과 지원 범위는 [앱 서체 설명](../../assets/fonts/WritingHumanDevelopment-README.md),
실행 결과는 [검증 기록](../../docs/verification.md)을 따른다.
