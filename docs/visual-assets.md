# 첨부 이미지 기반 UI 소재

2026-11-09. 내장 ImageGen 도구로 생성했다. 첨부한 브랜드 이미지가 시각 참조이며, 화면 전체를 이미지로 대체하지 않았다. 텍스트·버튼·입력은 실제 Flutter 위젯이다.

- assets/images/linen-cover.png: 녹색 천 표지. 앱에서 책 이름을 별도 렌더링한다.
- assets/images/fountain-pen.png: 검정·금색 만년필 투명 이미지. 입력을 가리지 않게 포인터를 무시하고, 편집 중이거나 긴 글에서는 숨긴다.
- 프로젝트 복사본은 화면용 크기로 축소했다. 생성 원본은 Codex generated_images에 유지했다.
- 초기에는 종이의 미세한 결, 종이 끝, 아이보리·블루 표지를 Flutter CustomPainter로 표현했다. 아래 재료 보강에서 종이와 표지에 실제 래스터 소재를 추가했다.
- 본문과 UI에 실제 나눔명조 Regular/Bold, 선택 글꼴에 나눔고딕을 번들했다. assets/fonts/의 각 SIL OFL 문서를 함께 보관한다.

## 2026-11-09 · 종이 재료와 빛 보강

내장 image_gen 도구의 새 소재 4개를 사용했다. 원본은 Codex generated_images에 남기고, 프로젝트 안에 화면용 파일을 복사했다. 이미지 전체를 앱 화면으로 사용하지 않는다. 책장·입력·도구는 실제 Flutter 위젯이다.

- assets/images/cotton-paper.jpg: 1024px 정방형 면지. 종이·바탕·원문 메모에 사용한다. 종이색은 별도 값이며 재료 이미지와 혼합한다.
- assets/images/ivory-linen-cover.png: 1024px 높이의 투명 아이보리 린넨 표지. 책 이름은 코드로 표시한다.
- assets/images/blue-linen-cover.png: 1024px 높이의 투명 블루 린넨 표지. 기존 절차적 격자 패턴을 교체했다.
- assets/images/sunlit-desk.jpg: 1536×1024 햇빛과 잎 그림자 배경. 넓은 화면에서만 사용하고 모바일 입력 위에 얹지 않는다.
- 종이 소재는 IgnorePointer/ExcludeSemantics 및 RepaintBoundary로 편집과 분리한다. 타이핑에 따른 움직임은 추가하지 않았다.
- 작은 이미지와 배경의 전송량을 줄이기 위해 sips로 크기·JPEG 형식을 최적화했다. 기존 녹색 표지와 만년필 원본은 유지했다.
- tool/capture_preview_test.dart는 실제 위젯을 예시 데이터로 렌더하는 재실행 가능한 화면 확인 도구다. 브라우저·실기기 캡처와 구별한다.

### 면지

Use case: photorealistic-natural. Asset type: seamless paper material for a functional Korean reading/writing app, not a UI mockup. Make a full bleed square 1024x1024 macro photograph/scan of warm natural ivory handmade cotton rag stationery paper. Dense fine interlocking cotton fibers, tiny irregular pulp flecks, gently uneven soft pressed surface and very subtle cloudy warm variations. Exquisite tactile fine art paper like the cream paper in the supplied brand reference, refined and clean, no heavy dirt. Even diffuse lighting, no directional shadows, no edges or folds, no objects, no text, no vignette, no ruled lines. Close enough that the fibers remain discernible when displayed at 390px. Low contrast appropriate behind dark Korean prose. The material fills every pixel, seamless tileable edges. Warm ivory #F7F2E8 overall. Do not make a collage or any app screen.

### 햇빛 배경

Use case: photorealistic-natural. Asset type: wide atmospheric backdrop behind a live writing app UI. A quiet sunlit writing room evoked entirely by a warm creamy plaster wall meeting a pale oak desk near the very bottom. Photorealistic editorial stationery photography, warm afternoon sunlight from left, soft beautiful shadows of olive leaves across upper left and upper right corners, gentle architectural window shadow diagonally from top left. Center 75 percent is luminous warm ivory negative space so live UI will be readable. A small softly defocused stack of worn dark moss green and tan linen books at the extreme lower left edge, partially cropped; a little amber ink bottle near them. Restrained vintage Korean bookstore atmosphere, tender natural fibers and light. No people, no phone, no computer, no stationery in center, no writing, no text, no logos. Landscape 3:2 composition. Similar light and warm cream palette to the header photograph in the reference brand board, not the full collage. The desk is only bottom 18 percent of image.

### 아이보리 린넨 표지

Use case: product-mockup. Asset type: transparent book cover for a functional app; one isolated book. A straight-on flat front view of a closed slender ivory linen hardback notebook, accurately rectangular portrait 0.72 width/height, with a narrow subtly raised spine on left and tactile natural undyed cream woven cloth, tiny weave and occasional darker fibers. Delicate blind embossed single frame inset along edges, very fine subtle gold botanical olive sprig below center at 65 percent height. Upper 45 percent completely blank for separately rendered Korean title. Warm soft studio light from upper left and natural small contact shadow lower right. Edges slightly worn but premium, restrained quiet Japanese/Korean stationery craft. Front cover only, no perspective tilt, no visible readable text, no letters, no logos, no strap, no pen, no hands, no extra books. Fill canvas with object with just 3 percent clear margins. Genuine transparent background, no white backdrop, no checkerboard.

### 블루 린넨 표지

Use case: product-mockup. Asset type: one transparent front book cover for a live app. A perfectly straight-on orthographic full front view of a slender slate blue (#5B6F8E) linen hardback book, accurately rectangular portrait 0.72 width/height. A narrow raised darker spine on left, premium tightly woven natural linen cloth with realistic visible small irregular fiber weave, subtle worn edges and slight cloth grain. Delicate thin debossed frame near edges and a small restrained antique gold foil botanical twig at lower center, 70 percent down. Upper 45 percent completely blank so app can overlay its own title. Soft warm natural studio light from upper left, tiny soft contact shadow lower right. No perspective tilt, no other objects, no lettering, no text, no logos, no watermark, no pen or straps, no decorative corner pieces. Canvas just 3 percent transparent margin. Genuine alpha transparent background, no white background, no checkerboard. Match refined quiet vintage Korean literary stationery.

## 초기 소재에 사용한 생성 프롬프트

### 표지

Use case: product-mockup. Asset type: front-cover material for the actual '쓰는 인간' Flutter typing app, NOT a UI screenshot. The supplied image is a visual reference only: recreate just the green cloth hardcover seen in the second phone screen. A single perfectly straight-on orthographic front cover, portrait 2:3 proportions, forest/olive green (#4e5a42) fine-woven linen texture, subtle wear, narrow dark spine fold at left, discreet fine gold inner rectangular border and delicate small gold-foil botanical twig at the lower center. Keep upper 40% BLANK so the app overlays its own book title. No letters, no words, no lettering, no watermark, no phone, no UI, no environment. Frame entire cover almost filling canvas with small even transparent margin; alpha background. Soft natural light from upper left. This is a tangible refined vintage literary clothbound book, restrained and realistic, matching the reference.

### 펜

Use case: product-mockup. Asset type: small decorative fountain pen cutout for a working typing app UI. Single elegant black lacquer fountain pen with polished antique-gold nib and gold rings, seen directly from above, uncapped, full pen visible. Long slim body runs diagonally from bottom-left nib tip to top-right rounded black barrel end at a 45-degree angle, echo the pen entering the third mobile screen in the reference. Realistic fine materials, soft warm studio highlights. Transparent alpha background, isolated pen only, no cap, no hand, no paper, no lettering, no watermark. Do not render an app, page, or phone.
