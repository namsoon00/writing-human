# 쓰는 인간체 · 개발 중

한글 111자, 공백·마침표·쉼표의 실제 개발 TTF다. 전체 한글을 지원하는 완성 서체가 아니다.
Flutter family는 WritingHumanDevelopment이며 지원 범위 밖은 번들 나눔명조와 나눔고딕으로 표시한다.
나눔 글꼴의 SIL OFL 문서는 기존 파일을 유지한다.

이 파일은 직접 작성한 프로젝트 공통 자모 벡터에서 빌드했다.
기준 SHA-256·지원 문자와 한계는 WritingHumanDevelopment-info.json에 있다.
생성기는 design/typeface/build_vector_proof.py, 편집 원본은 source/jamo-v004.json과
source/review-text-v004.json, 개발 의존성은 requirements-vector.txt다.

재생성:

```sh
python3 -m venv artifacts/typeface-venv
artifacts/typeface-venv/bin/python -m pip install -r design/typeface/requirements-vector.txt
artifacts/typeface-venv/bin/python design/typeface/build_vector_proof.py
```

출력은 design/typeface/proof/에 생긴다. 앱 파일 교체는 검사 후 명시적으로 수행한다.
본문은 항상 실제 TextField이며 글꼴 선택은 문자열·선택 영역·한글 composing을 다시 설정하지 않는다.
새 옵션은 Aa → 글꼴 → 쓰는 인간체 · 개발 중에서 선택한다. 기존 선택은 자동 변경하지 않는다.
