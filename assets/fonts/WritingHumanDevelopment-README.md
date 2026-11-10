# 쓰는 인간체 0.007

화면 가독성을 높인 0.007은 원래 벡터 윤곽을 바깥으로 6/1000em 넓혀 실제 획을
두껍게 만든다. 글자 폭과 지원 문자·자모 조판은 유지한다. `source/reading-v007.json`이
확대 원본이며 이전 자모·영문 중심선은 보존한다. 앱은 시스템 글씨 확대를 유지하면서
기본 크기를 20% 키우고 일반 문구를 최소 14px로 표시한다. 기본 본문은 약 27.6px다.


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
```

기본 출력은 `design/typeface/release/`이며, `--install`은 빌드·경계 검사 성공 후
앱 자산과 메타데이터를 복사한다. 0.005의 제한된 견본과 빌더는 별도로 보존한다.
본문은 실제 TextField이며 문자열·선택 영역·한글 composing을 수정하지 않는다.
NFD 자모 조합은 글꼴의 조판으로 처리하고 사용자 본문을 정규화해서 덮어쓰지 않는다.
