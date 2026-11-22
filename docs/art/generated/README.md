# 수묵 살림·스토어 원본 (2026-11-22)

기준: 기존 홍란 `fox_ok.png`, 가게 `bg_2.png`, 물건 `teapot.png` 확인. 세계관·칸 배치·품목은 `docs/art/chatgpt_handoff_2.md`의 H1/H2/I1/I2를 따름.

- `belong_1.png`: 투명 3×3. backroom, alley, canal / garden, pavilion, skygarden / cart, bike, pass.
- `belong_2.png`: 투명 3×3. hover, limo, skiff / freighter, clipper, 빈칸 / 빈칸 3개.
- `icon.png`: 불투명 정사각형. 큰 목제 인장, 옥 엽전, 장부. 핵심 형태는 가운데 안전 영역.
- `feature.png`: 홍란과 배경을 참조한 가로 약 2:1 그림. 왼쪽 계산대·옥 유물·둥근 창·운경, 오른쪽은 운무 여백. 글자는 도구로 별도 합성.

공통 프롬프트: 사실적 비율의 수묵 담채 반실사, 먹선·맑은 수채·한지 결, 먹빛·자주·옥빛·바랜 금색. 특정 국가·국기·역사·네온·기존 작품 복제·글자 금지. 실제 투명 PNG, 사물은 칸의 78~80% 안, 넉넉한 여백. 이미지 생성 도구로 제작했으며 기존 캐릭터 원본은 수정하지 않음.

자르기와 규격 변환은 `tools/slice_sheets.py`, `tools/prepare_store_art.py`로 재현. 아트 원본을 APK에 포함하지 않음.
