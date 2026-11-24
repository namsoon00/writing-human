# 쓰는 인간체 0.009

0.009는 같은 크기로 쓴 한글이 받침·모음 구조에 따라 들쭉날쭉해 보이던 점을 다듬는다.
완성 음절의 획 외곽 높이는 712–728, 폭은 690–728 디자인 단위의 작은 범위에 맞추고
아래선을 100에 둔다(둥근 ㅇ 받침은 3단위 내려 광학적 여유를 둔다). 1em은 1000단위다.
범위 안의 차이는 유지하며 기존 자모의 획 구조와 부드러운 곡선은 재사용한다.

`source/reading-v009.json`이 보정 기준이다. 한글 11,172자와 기존 문자 지원, 한 글자의
차지 폭 920, 줄 높이, 완성형/분해형 조판, 영문·숫자·문장부호는 유지한다.
0.008에서 넓힌 겹받침과 안쪽 여백도 이어받는다. 한글 이외의 글자에는 이번 크기 보정을 적용하지 않는다.
실제 TTF의 작은 글씨와 문장 견본을 확인했으며 최종 광학 승인과 실기기 검수는 별도다.


직접 작성한 자모·영문 벡터 원본에서 빌드한 실제 TTF다. 현대 한글 11,172자,
호환 자모 51자, 현대 조합 자모 67자, 인쇄용 ASCII 95자와 문장부호를 지원한다.
문자 범위의 완성과 최종 광학·실기기 검수는 구분한다. 아직 출시 승인된 완성 서체는 아니다.

Flutter family는 기존 `WritingHumanDevelopment`다. 일반 작성 화면·기존 페이지·메뉴·
보관함·도구·대화상자에 기본 적용한다. 이전 설정은 한 번 전환하고 이후 선택한
다른 본문 글꼴은 저장·복원한다. 나눔명조는 대체 글꼴과 선택지로 유지한다. 한자·옛한글 조판·확장 라틴 등
지원 범위 밖은 나눔명조·나눔고딕·플랫폼 대체 글꼴을 사용한다.
나눔 글꼴의 기존 SIL OFL 문서는 그대로 유지하며, 자체 윤곽의 출처로 혼용하지 않는다.

## 원본과 재생성

- `design/typeface/source/jamo-v004.json`: 직접 설계한 한글 자모 중심선.
- `design/typeface/source/latin-v006.json`: 직접 설계한 영문·숫자·ASCII 중심선과 커닝.
- `design/typeface/build_vector_proof.py`: 공통 자모 윤곽 및 여섯 배치의 원본 구현.
- `design/typeface/build_typeface.py`: 전체 범위, 자모 공유, 추가 문장부호, OpenType 조판.
- `WritingHumanDevelopment-info.json`: 정확한 cmap, 원본·빌더·TTF 해시와 미검증 범위.

저장소 루트에서:

```sh
python3 -m venv artifacts/typeface-venv
artifacts/typeface-venv/bin/python -m pip install -r design/typeface/requirements-qa.txt
artifacts/typeface-venv/bin/python design/typeface/build_typeface.py
artifacts/typeface-venv/bin/python design/typeface/audit_typeface.py
artifacts/typeface-venv/bin/python design/typeface/build_typeface.py --install
flutter test tool/render_full_typeface_test.dart --no-pub
# 이전 TTF와 크기·배치 및 실제 읽기 견본을 비교할 때:
artifacts/typeface-venv/bin/python design/typeface/review_balance.py /path/to/previous.ttf design/typeface/release/WritingHumanDevelopment-Regular.ttf
```

기본 출력은 `design/typeface/release/`이며, `--install`은 빌드·경계 검사 성공 후
앱 자산과 메타데이터를 복사한다. 0.005의 제한된 견본과 빌더는 별도로 보존한다.
본문은 실제 TextField이며 문자열·선택 영역·한글 composing을 수정하지 않는다.
NFD 자모 조합은 글꼴의 조판으로 처리하고 사용자 본문을 정규화해서 덮어쓰지 않는다.
